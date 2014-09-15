function [ nb ] = nbAcquireData(mdl, sys, nb, start, duration, varargin)
%NBACQUIREDATA  Updates a noise model with fresh data from NDS
%
%   Syntax:
%
%   [ nb ] = NBACQUIREDATA(mdl, sys, nb, start, duration)
%   [ nb ] = NBACQUIREDATA(..., 'PropertyName', PropertyValue, ...)
%
%   Description:
%
%   nbAcquireData(MDL, SYS, NB, START, DURATION) makes a list of DAQ
%   channels that are requested by NbNoiseSource and NbNoiseSink blocks in
%   MDL.  It uses mDV to retrieve data for those channels, according to the
%   specified START time (GPS) and DURATION (in seconds).  Then it computes
%   the ASDs, and calibrates them using transfer functions from the SYS
%   object (as returned by NBFROMSIMULINK).  Finally, the NOISEMODEL object
%   NB (as returned by NBGROUPNOISES) is rebuilt to incorporate the newly
%   acquired data.
%
%   nbAcquireData(..., 'PropertyName', PropertyValue, ...) allows the
%   following options to be defined:
%
%   'asdMethod' -- value should be a function name (string) or handle that
%   will be used to compute ASDs of the data.  It will be called as
%   asdMethod(dataVector, samplesPerSec, freqVector), and it should return
%   an ASD interpolated to the requested freqVector.
%
%   See also: NBFROMSIMULINK, NBGROUPNOISES, NOISEMODEL

%% Parse the arguments

% Validate required arguments
if ~ischar(mdl)
    error('The model name is not a string');
elseif ~isobject(sys)
    error('The sys object is not an object');
elseif ~isprop(nb, 'modelNoises')
    error('The nb object is not a NoiseModel');
elseif ~(isreal(start) && start > 0)
    error('The start time is not a GPS time');
elseif ~(isreal(duration) && duration > 0)
    error('The duration is not a positive real number');
end

% Parse parameter-value pairs in varargin
parser = inputParser();
parser.addParamValue('asdMethod', @defaultAsd, @(x) ischar(x) || isa(x, 'function_handle'));
parser.parse(varargin{:});
opt = parser.Results;

%% Fetch data as requested by the NbNoiseSource blocks

load_system(mdl);
% findChans() is a local function defined below
chanList = findChans(mdl, sys, nb);

if isempty(chanList)
    return; % no channels requested, nothing to do
end

chanList = sort(unique(chanList));

% conn = nds2.connection(server, port);
% buffers = conn.fetch(start, end, chanList);
% The java NDS2 library needs more development before we can adopt it
% and get live data support
% see e.g. bug 68: https://trac.ligo.caltech.edu/nds2/ticket/68
% Fall back on good old mDV instead
% Break the channel list into digestible pieces for the NDS server
maxChans = 100;
lastChanIdx = 0;
data = [];
while (numel(chanList) - lastChanIdx) > 0
    chansToFetch = min(numel(chanList) - lastChanIdx, maxChans);
    disp(['Requesting ' num2str(duration) ' sec of data for ' num2str(chansToFetch) ...
        ' channels, starting at GPS time ' num2str(start)]);

    firstChanIdx = lastChanIdx + 1;
    lastChanIdx = lastChanIdx + chansToFetch;
%     for n = 1:chansToFetch
%         disp(chanList(firstChanIdx+n-1));
%         get_data(chanList(firstChanIdx+n-1), 'raw', start, duration);
%     end
    data = [data cacheFunction(@get_data, chanList(firstChanIdx:lastChanIdx),...
            'raw', start, duration)]; %#ok<AGROW>
end

%% Compute ASDs 

noisesByChan = containers.Map();
for n = 1:numel(data)
    if any(isnan(data(n).data))
        error(['NaN value returned for channel ' data(n).name]);
    end
    asd = opt.asdMethod(double(data(n).data), data(n).rate, nb.f);
    noisesByChan(data(n).name) = asd;
end

% Validate the results
for n = 1:numel(chanList)
    if ~isKey(noisesByChan, chanList{n})
        error(['No data found for channel ' chanList{n}]);
    end
end

%% Plug the new ASDs into the NoiseModel

% updateNoises() is a local function defined below
nb = updateNoises(sys, nb, noisesByChan);

end

function [ asd ] = defaultAsd(data, Fs, freq)
%DEFAULTASD is meant to be a simple, DTT-esque ASD estimator

% Pick some reasonable resolution for the spectrum, in case the freq vector
% has nonuniform spacing
df = geomean(diff(freq));
df = min(df, min(freq(freq>0)));
NFFT = 2^ceil(log2(Fs/df));
if NFFT > numel(data)
    error(['Not enough data: at least ' num2str(NFFT/Fs) ' seconds of data '...
        'are needed to match the frequency vector''s resolution, but only '...
        num2str(numel(data)/Fs) ' seconds of data were requested']);
end
[psd, f] = pwelch(data, hann(NFFT), NFFT/2, NFFT, Fs);
asd = interp1(f, sqrt(psd), freq, 'nearest', 0);

end

function [ chanList ] = findChans(mdl, sys, nb, varargin)
%FINDCHANS recursively lists the DAQ channels that have been requested by a model

%% Initial setup

if isempty(varargin)
    % Check for sink's channel only the first time through this function
    chanList = {};
    nbNoiseSink = sys(2).OutputName{:};
    chan = getBlockChan(nbNoiseSink);
    if ~isempty(chan)
        disp(['NbNoiseSink ' nbNoiseSink ' requested DAQ channel ' chan]);
        chanList = {chan};
    end
else
    chanList = varargin{1};
end

%% Recursively check for noise sources that request a DAQ channel

for n = 1:numel(nb.modelNoises)
    noise = nb.modelNoises{n};
    if isprop(noise, 'modelNoises')
        chanList = findChans(mdl, sys, noise, chanList);
    else
        if isprop(noise, 'noiseData')
            nbNoiseSource = noise.noiseData.name;
        else
            nbNoiseSource = noise.name;
        end
        chan = getBlockChan(nbNoiseSource);
        if ~isempty(chan)
            disp(['NbNoiseSource ' nbNoiseSource ' requested DAQ channel ' chan]);
            if ~any(strcmp(chan, chanList))
                chanList = [chanList {chan}]; %#ok<AGROW>
            end
        end
    end
end

end

function [ nb ] = updateNoises(sys, nb, noisesByChan)
%UPDATENOISES calibrates the newly acquired noises and places them in the NoiseModel object

%% Initial setup (for noise sink)

nbNoiseSink = sys(2).OutputName{:};
chan = getBlockChan(nbNoiseSink);
if ~isempty(chan)
    disp(['Updating sink ' nbNoiseSink]);
    noiseTf = (1-sys(1))/sys(2);
    noiseAsd = noisesByChan(chan) .* abs(squeeze(freqresp(noiseTf, 2*pi*nb.f)))';
    foundSinkNoise = false;
    for n = 1:length(nb.referenceNoises)
        noise = nb.referenceNoises{n};
        if isprop(noise, 'noiseData') && strcmp(noise.noiseData.name, nbNoiseSink)
            foundSinkNoise = true;
            noise.noiseData.asd = noiseAsd;
            nb.referenceNoises{n} = noise;
            break;
        end
    end
    if ~foundSinkNoise
        noise.name = nbNoiseSink;
        noise.f = nb.f;
        noise.asd = noiseAsd;
        noise = renamed(noise, 'Measured');
        nb.referenceNoises = [nb.referenceNoises {noise}];
    end
end

%% Recursively update noise sources

nb = updateNoises_n(sys, nb, noisesByChan);

end

function [ nb ] = updateNoises_n(sys, nb, noisesByChan)
%UPDATENOISES_N is the recursive step for updateNoises()

cal = 1/sys(2);

for n = 1:numel(nb.modelNoises)
    noise = nb.modelNoises{n};
    if isprop(noise, 'modelNoises')
        noise = updateNoises_n(sys, noise, noisesByChan);
    else
        if isprop(noise, 'noiseData')
            nbNoiseSource = noise.noiseData.name;
        else
            nbNoiseSource = noise.name;
        end
        chan = getBlockChan(nbNoiseSource);
        if ~isempty(chan)
            disp(['Updating source ' nbNoiseSource]);
            noiseTf = sys(strcmp(nbNoiseSource, sys.InputName));
            noiseAsd = noisesByChan(chan) .* abs(squeeze(freqresp(noiseTf*cal, 2*pi*nb.f)))';
            if isprop(noise, 'noiseData')
                noise.noiseData.asd = noiseAsd;
            else
                noise.asd = noiseAsd;
            end
        end
    end
    nb.modelNoises{n} = noise;
end

end

function [ chan ] = getBlockChan(blk)

chan = '';
tag = get_param(blk, 'Tag');
blkVars = get_param(blk, 'MaskWSVariables');
blkVars = containers.Map({blkVars.Name}, {blkVars.Value});
if ~ischar(blkVars('chan'))
    error(['Invalid ' tag ' block ' blk char(10) ...
        'The DAQ channel (' get_param(blk, 'chan') ') must be a string']);
end
if ~isempty(blkVars('chan'))
    chan = blkVars('chan');
end

end