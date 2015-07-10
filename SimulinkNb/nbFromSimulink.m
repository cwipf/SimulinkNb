function [noises, sys] = nbFromSimulink(mdl, freq, varargin)
%NBFROMSIMULINK  Generates noise budget terms from a Simulink model
%
%   Syntax:
%
%   [noises, sys] = nbFromSimulink(mdl, freq)
%   [noises, sys] = nbFromSimulink(..., 'PropertyName', PropertyValue, ...)
%
%   Description:
%
%   nbFromSimulink(MDL, FREQ) generates noise budget terms from the
%   Simulink model MDL, with frequency vector FREQ.  It uses special
%   "dummy" blocks in the model (which are tagged as "NbNoiseSource",
%   "NbNoiseSink", or "NbNoiseCal") to generate noise budget terms.
%
%   Each NbNoiseSource block has a user-defined parameter ASD, which should
%   evaluate to the amplitude spectral density of the noise at the point
%   where the source block is summed into the model.  The ASD can be either
%   a scalar value or an array.  (If an array is used, you need to make
%   sure it's interpolated to match the FREQ vector that's passed as an
%   argument to NBFROMSIMULINK.)
%
%   The NbNoiseSink and NbNoiseCal blocks have a user-defined parameter
%   DOF.  For each defined DOF, there should be exactly one sink and
%   exactly one cal block.  Connect the cal block to the signal in the
%   model that you "want" to measure (for example, test mass displacement
%   calibrated in meters).  Connect the sink block in series with the
%   signal that you actually measure (for example, digitized photodetector
%   output).
%
%   NBFROMSIMULINK linearizes the model (using LINFLEXTF) to obtain
%   transfer functions from each source, and the cal block, to the sink
%   (with the loop opened after the sink).  These TFs are used to determine
%   each source's contribution to the total calibrated noise.
%
%   nbFromSimulink(..., 'PropertyName', PropertyValue, ...) allows the
%   following options to be defined:
%
%   'dof' -- value should be a string containing the DOF name to use, in
%   case more than one DOF has been defined in the model.  (Any other DOFs
%   that may be present are simply ignored.)
%
%   Output arguments:
%
%   NOISES -- contains the calibrated noise terms.  Each is stored in a
%   struct with fields 'f' (frequency vector), 'asd' (spectral density),
%   and 'name' (path to the source block).  NOISES is a cell array of these
%   noise structs.
%
%   SYS -- the linearized Simulink model containing the calibration TFs.
%
%   See also: LINFLEXTF

%% Parse the arguments

% Validate required arguments
if ~ischar(mdl)
    error('The model name is not a string');
elseif ~isreal(freq)
    error('The frequency vector is not real-valued');
end

% Parse parameter-value pairs in varargin
parser = inputParser();
parser.addParamValue('dof', '', @ischar);
parser.parse(varargin{:});
opt = parser.Results;

%% Gather all NbNoiseSink and NbNoiseCal blocks

load_system(mdl);
% getBlocksByDof() is a local function defined below
nbNoiseSinksByDof = getBlocksByDof(mdl, 'NbNoiseSink');
nbNoiseCalsByDof = getBlocksByDof(mdl, 'NbNoiseCal');

% Check for one-to-one correspondence between the NbNoiseSink and NbNoiseCal blocks
mismatchedDofs = setxor(nbNoiseSinksByDof.keys(), nbNoiseCalsByDof.keys());
if ~isempty(mismatchedDofs)
    if ~nbNoiseSinksByDof.isKey(mismatchedDofs{1})
        error(['Missing NbNoiseSink block for DOF name ' mismatchedDofs{1}]);
    else
        error(['Missing NbNoiseCal block for DOF name ' mismatchedDofs{1}]);
    end
end

% Make sure at least one DOF is defined
availableDofs = nbNoiseSinksByDof.keys();
if numel(availableDofs) < 1
    error('The model must contain at least one NbNoiseSink block and at least one NbNoiseCal block');
end

%% Choose a NbNoiseSink/Cal pair according to the requested DOF

if isempty(opt.dof)
    % No DOF name was given.  If exactly one DOF was defined in the model,
    % then use it.  Otherwise, give up.
    if numel(availableDofs) == 1
        opt.dof = availableDofs{1};
    else
        error(['Since the model defines multiple DOFs, you must pick one' ...
            ' and specify it in the input arguments of this function']);
    end
end

if nbNoiseSinksByDof.isKey(opt.dof) && nbNoiseCalsByDof.isKey(opt.dof)
    nbNoiseSink = nbNoiseSinksByDof(opt.dof);
    nbNoiseCal = nbNoiseCalsByDof(opt.dof);
    disp([num2str(numel(availableDofs)) ' DOFs found; DOF ' opt.dof ' is selected']);
else
    error(['The requested DOF name (' opt.dof ') is not defined in the model']);
end

%% Evaluate the NbNoiseSink's measured ASD (if present)

% getBlockNoise() is a local function defined below
sinkNoise = getBlockNoises(nbNoiseSink, freq);
sinkNoise = sinkNoise{1};

%% Find the NbNoiseSource blocks

nbNoiseSources = findInSystemOrRefs(mdl, 'Tag', 'NbNoiseSource');
disp([num2str(numel(nbNoiseSources)) ' NbNoiseSource blocks found']);
if numel(nbNoiseSources) < 1
    error('The model must contain at least one NbNoiseSource block');
end

%% Evaluate each NbNoiseSource block's ASD, and set up noise/calibration TFs

noises = {};
% Set numerator for noise/calibration TFs, and open the loop
% (also sets denominator for open loop gain around the sink)
ioSink = linio(nbNoiseSink, 1, 'outin', 'on');
% Set denominator for calibration TF (cal to sink)
ioCal = linio(nbNoiseCal, 1, 'in');
for n = 1:numel(nbNoiseSources)
    blk = nbNoiseSources{n};
    % Set denominator for noise TF (source to sink)
    ioSource(n) = linio(blk, 1, 'in'); %#ok<AGROW>
    % getBlockNoise() is a local function defined below
    noises = [noises getBlockNoises(blk, freq)]; %#ok<AGROW>
end
io = [ioSink ioCal ioSource];

%% Perform the linearization using FlexTf functions

% Don't abbreviate I/O block names (it's faster that way)
linOpt = linoptions('UseFullBlockNameLabels', 'on');
[sys, flexTfs] = linFlexTf(mdl, io, linOpt);
% Attempt to improve numerical accuracy with prescale
minPosFreq = min(freq(freq>0));
maxPosFreq = max(freq(freq>0));
if ~isempty(minPosFreq) && ~isempty(maxPosFreq)
    sys = prescale(sys, {2*pi*minPosFreq, 2*pi*maxPosFreq});
end
sys = linFlexTfFold(sys, flexTfs);
% Ensure sys gets converted to frequency response data
sys = frd(sys, freq, 'Units', 'Hz');

% Set sys input/output names to meaningful values
% (UseFullBlockNameLabels appends signal names to the block names)
sys.InputName = [{nbNoiseSink nbNoiseCal} nbNoiseSources'];
sys.OutputName = nbNoiseSink;

%% Apply noise/calibration TFs to each NbNoiseSource's spectrum

cal = 1/sys(2);
% Ensure the calibration TF is finite
if ~all(isfinite(freqresp(cal, 2*pi*freq)))
    error('Can''t calibrate noises in the model because the TF from the NbNoiseCal block to the NbNoiseSink block can''t be inverted (is it zero?)');
end

for n = 1:numel(noises)
    nameParts = regexp(noises{n}.name, '(.*)\{\d+\}', 'tokens');
    blk = nameParts{1};
    tfIdx = strcmp(blk, sys.InputName);
    tf = abs(squeeze(freqresp(sys(tfIdx)*cal, 2*pi*freq)))';
    noises{n}.asd = noises{n}.asd .* tf; %#ok<AGROW>
end

%% Prepend the NbNoiseSink's measured spectrum

if ~isempty(sinkNoise.asd)
    sinkNoise.asd = sinkNoise.asd .* abs(squeeze(freqresp((1-sys(1))*cal, 2*pi*freq)))';
end
noises = [{sinkNoise} noises];

end

function [ blockTable ] = getBlocksByDof(mdl, tag)
%% Locate the blocks with the requested tag

blks = findInSystemOrRefs(mdl, 'Tag', tag);
disp([num2str(numel(blks)) ' ' tag ' blocks found']);

%% Organize them in a hashtable (containers.Map object), indexed by the DOF name

blockTable = containers.Map();
for n = 1:numel(blks)
    blk = blks{n};
    blkVars = get_param(blk, 'MaskWSVariables');
    blkVars = containers.Map({blkVars.Name}, {blkVars.Value});
    dofs = blkVars('dof');
    if ischar(dofs)
        dofs = {dofs};
    end
    if ~iscellstr(dofs)
        error(['Invalid ' tag ' block ' blk char(10) ...
            'The DOF name (' get_param(blk, 'dof') ') must be a string or cell array']);
    end
    for nn = 1:numel(dofs)
        disp(['    ' blk ' :: ' dofs{nn}]);
        if ~blockTable.isKey(dofs{nn})
            blockTable(dofs{nn}) = blk;
        else
            error(['The DOF name cannot be shared by multiple ' tag ' blocks' char(10) ...
                'Blocks ' blk ' and ' blockTable(dofs{nn}) ' both have dof=' dofs{nn}]);
        end
    end    
end

end

function [ noises ] = getBlockNoises(blk, freq)

tag = get_param(blk, 'Tag');
expr = get_param(blk, 'asd');
% If expr is inside a library block, then its name probably refers to a
% library parameter (mask variable), which has to be resolved before
% evaluating
expr = resolveLibraryParam(expr, blk);
% Permit NbNoiseSink block to have an empty ASD
if strcmp(tag, 'NbNoiseSink')
    if isempty(expr) || strcmp(expr, '''''') || strcmp(expr, '[]')
        noises = {struct('name', [blk '{1}'], 'f', freq, 'asd', [])};
        return;
    end
end
disp(['    ' blk ' :: ' expr]);
% Update the current block.  This is to allow clever ASD functions
% to use gcb to figure out which block invoked them.
scb(blk);
% Evaluate the noise ASD
% Note: evaluation is done in the base workspace (any variables set in
% the model workspace are ignored).  The NbNoiseSource block mask is
% set to NOT evaluate anything automatically.  This way, the noise
% budget spectra don't have to be defined when the model is used for
% purposes other than making a noise budget.
asds = evalin('base', expr);

if ~iscell(asds)
    asds = {asds};
end

noises = cell(1, numel(asds));
for n = 1:numel(asds)
    noises{n} = struct('name', [blk '{' num2str(n) '}'], 'f', freq, 'asd', []);
    asd = asds{n};
    % Sanity checks on the ASD
    if ~isreal(asd) || min(size(asd)) > 1
        error(['Invalid ' tag ' block ' blk char(10) ...
            'ASD #' num2str(n) ' (from ' expr ') is not a real-valued 1D array']);
    elseif numel(asd) ~= 1 && numel(asd) ~= numel(freq)
    error(['Invalid ' tag ' block ' blk char(10) ...
        'Length of ASD #' num2str(n) ' (from ' expr ') doesn''t match the frequency vector' char(10) ...
        '(ASD''s length is ' num2str(numel(asd)) ...
        ' and frequency vector''s length is ' num2str(numel(freq)) ')']);
    end
    if size(asd, 1) ~= 1
        asd = asd';
    end
    noises{n}.asd = asd;
end

end
