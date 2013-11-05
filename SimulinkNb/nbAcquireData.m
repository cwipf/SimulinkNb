function nb = nbAcquireData(mdl, sys, nb, start, duration, varargin)
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
%   channels that are requested by NbNoiseSource blocks in MDL.  It uses
%   mDV to retrieve data for those channels, according to the specified
%   START time (GPS) and DURATION (in seconds).  Then it computes the ASDs,
%   and calibrates them using transfer functions from the SYS object (as
%   returned by NBFROMSIMULINK).  Finally, the NOISEMODEL object NB (as
%   returned by NBGROUPNOISES) is rebuilt to incorporate the freshly
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
chanList = findChan(mdl, nb);

if isempty(chanList)
    return; % no channels requested, nothing to do
end

% conn = nds2.connection(server, port);
% buffers = conn.fetch(start, end, chanList);
% The java NDS2 library needs more development before we can adopt it
% and get live data support
% see e.g. bug 68: https://trac.ligo.caltech.edu/nds2/ticket/68
% Fall back on good old mDV
data = get_data(chanList, 'raw', start, duration);

%% Compute ASDs 

noisesByChan = containers.Map();
for n = 1:numel(data)
    asd = opt.asdMethod(data(n).data, data(n).rate, nb.f);
    noisesByChan(data.name) = asd;
end

%% Plug the new ASDs into the model

nb = updateNoises(nb, sys, noisesByChan);

end

function asd = defaultAsd(data, Fs, freq)
%DEFAULTASD is meant to be a simple, DTT-esque ASD estimator

% Pick some reasonable resolution for the spectrum, in case the freq vector
% has nonuniform spacing
df = geomean(diff(freq));
NFFT = round(Fs/df);
if NFFT > numel(data)
    error(['Not enough data: at least ' num2str(NFFT/Fs) ' seconds of data '...
        'are needed to match the frequency vector''s resolution, but only '...
        num2str(numel(data)/Fs) ' seconds of data were requested']);
end
[psd, f] = pwelch(data, hann(NFFT), NFFT/2, NFFT, Fs);
asd = interp1(f, sqrt(psd), freq, 'cubic', 0);

end

function chanList = findChan(mdl, nb, varargin)

if numel(varargin) == 0
    chanList = {};
else
    chanList = varargin{1};
end

for n = 1:numel(nb.modelNoises)
    noise = nb.modelNoises{n};
    if isprop(noise, 'modelNoises')
        chanList = findChan(mdl, noise, chanList);
    else
        if isprop(noise, 'noiseData')
            noisePath = noise.noiseData.name;
        else
            noisePath = noise.name;
        end
        chan = get_param(noisePath, 'chan');
        chan = evalin('base', chan);
        if ~isempty(chan) && ~any(strcmp(chan, chanList))
            disp(['Found DAQ channel ' chan ' for source ' noisePath]);
            chanList = [chanList {chan}]; %#ok<AGROW>
        end
    end
end

end

function nb = updateNoises(nb, sys, noisesByChan)

cal = 1/sys(1);

for n = 1:numel(nb.modelNoises)
    noise = nb.modelNoises{n};
    if isprop(noise, 'modelNoises')
        noise = updateNoises(noise, sys, noisesByChan);
    else
        if isprop(noise, 'noiseData')
            noisePath = noise.noiseData.name;
        else
            noisePath = noise.name;
        end
        chan = get_param(noisePath, 'chan');
        chan = evalin('base', chan);
        if ~isempty(chan)
            disp(['Updating noise from source ' noisePath]);
            noiseTf = sys(strcmp(noisePath, sys.InputName));
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