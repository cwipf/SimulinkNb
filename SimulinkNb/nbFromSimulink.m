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

%% Find the NbNoiseSource blocks

nbNoiseSources = find_system(mdl, 'Tag', 'NbNoiseSource');
disp([num2str(numel(nbNoiseSources)) ' NbNoiseSource blocks found']);
if numel(nbNoiseSources) < 1
    error('The model must contain at least one NbNoiseSource block');
end

%% Evaluate each NbNoiseSource block's ASD, and set up noise/calibration TFs

noises = num2cell(struct('name', nbNoiseSources, 'f', freq, 'asd', []))';
% Set numerator for noise/calibration TFs, and open the loop
ioSink = linio(nbNoiseSink, 1, 'out', 'on');
% Set denominator for calibration TF (cal to sink)
ioCal = linio(nbNoiseCal, 1, 'in');
for n = 1:numel(nbNoiseSources)
    blk = nbNoiseSources{n};
    % Set denominator for noise TF (source to sink)
    ioSource(n) = linio(blk, 1, 'in'); %#ok<AGROW>
    disp(['    ' blk ' :: ' get_param(blk, 'asd')]);
    % Update the current block.  This is to allow clever ASD functions
    % to use gcb to figure out which block invoked them.
    scb(blk);
    % Evaluate the noise ASD
    % Note: evaluation is done in the base workspace (any variables set in
    % the model workspace are ignored).  The NbNoiseSource block mask is
    % set to NOT evaluate anything automatically.  This way, the noise
    % budget spectra don't have to be defined when the model is used for
    % purposes other than making a noise budget.
    noises{n}.asd = evalin('base', get_param(blk, 'asd'));
    % Sanity checks on the ASD
    if ~isreal(noises{n}.asd) || min(size(noises{n}.asd)) > 1
        error(['Invalid NbNoiseSource block ' blk char(10) ...
            'The ASD (' get_param(blk, 'asd') ') is not a real-valued 1D array']);
    elseif numel(noises{n}.asd) ~= 1 && numel(noises{n}.asd) ~= numel(freq)
        error(['Invalid NbNoiseSource block ' blk char(10) ...
            'The length of the ASD (' get_param(blk, 'asd') ') doesn''t match the frequency vector' char(10) ...
            '(ASD''s length is ' num2str(numel(noises{n}.asd)) ...
            ' and frequency vector''s length is ' num2str(numel(freq)) ')']);
    end
    if size(noises{n}.asd, 1) ~= 1
        noises{n}.asd = noises{n}.asd';
    end
end
io = [ioSink ioCal ioSource];

%% Perform the linearization using FlexTf functions

[sys, flexTfs] = linFlexTf(mdl, io);
% Attempt to improve numerical accuracy with prescale
minPosFreq = min(freq(freq>0));
maxPosFreq = max(freq(freq>0));
if ~isempty(minPosFreq) && ~isempty(maxPosFreq)
    sys = prescale(sys, {2*pi*minPosFreq, 2*pi*maxPosFreq});
end
sys = linFlexTfFold(sys, flexTfs);

% Set sys input/output names to meaningful values
sys.InputName = [{nbNoiseCal} nbNoiseSources'];
sys.OutputName = nbNoiseSink;

%% Apply noise/calibration TFs to each NbNoiseSource's spectrum

cal = 1/sys(1);
for n = 1:numel(nbNoiseSources)
    noises{n}.asd = noises{n}.asd .* abs(squeeze(freqresp(sys(n+1)*cal, 2*pi*freq)))';
end

end

function [ blockTable ] = getBlocksByDof(mdl, tag)
%% Locate the blocks with the requested tag

blks = find_system(mdl, 'Tag', tag);
disp([num2str(numel(blks)) ' ' tag ' blocks found']);

%% Organize them in a hashtable (containers.Map object), indexed by the DOF name

blockTable = containers.Map();
for n = 1:numel(blks)
    blk = blks{n};
    % Evaluate the DOF
    disp(['    ' blk ' :: ' get_param(blk, 'dof')]);
    val = evalin('base', get_param(blk, 'dof'));
    if ~ischar(val)
        error(['Invalid ' tag ' block ' blk char(10) ...
            'The DOF name (' get_param(blk, param) ') must be a string']);
    end
    if ~blockTable.isKey(val)
        blockTable(val) = blk;
    else
        error(['The DOF name cannot be shared by multiple ' tag ' blocks' char(10) ...
            'Blocks ' blk ' and ' blockTable(val) ' both have dof=' val]);
    end
end

end