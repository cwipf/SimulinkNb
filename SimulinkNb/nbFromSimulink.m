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
%   'closeModelWindow' -- if false, the function will not attempt to close
%   the Simulink model's window.  The default is true, since the
%   linearization is slower with the window open.
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
end

if ~isreal(freq)
    error('The frequency vector is not real-valued');
end

% Parse parameter-value pairs in varargin
parser = inputParser();
parser.addParamValue('closeModelWindow', true, @islogical);
parser.addParamValue('dof', '', @ischar);
parser.parse(varargin{:});
opt = parser.Results;

if opt.closeModelWindow
    optionally_close_system = @(mdl) close_system(mdl);
else
    optionally_close_system = @(mdl) deal(); % no-op
end

%% Find all NbNoiseSource, NbNoiseSink, and NbNoiseCal blocks within the model

load_system(mdl);
nbNoiseSources = find_system(mdl, 'Tag', 'NbNoiseSource');
nbNoiseSinks = find_system(mdl, 'Tag', 'NbNoiseSink');
nbNoiseCals = find_system(mdl, 'Tag', 'NbNoiseCal');

%% Group the NbNoiseSink and NbNoiseCal blocks by DOF

% Gather all NbNoiseSink blocks into a hashtable, indexed by the DOF name 
nbNoiseSinksByDof = containers.Map();
disp([num2str(numel(nbNoiseSinks)) ' NbNoiseSink block(s) found in model ' mdl]);
if numel(nbNoiseSinks) < 1
    optionally_close_system(mdl);
    error('The model must contain at least one NbNoiseSink block');
end
for n = 1:numel(nbNoiseSinks)
    blk = nbNoiseSinks{n};
    maskVars = containers.Map(get_param(blk, 'MaskNames'), get_param(blk, 'MaskValues'));
    disp(['    ' blk ' :: ' maskVars('dof')]);
    dof = evalin('base', maskVars('dof'));
    if ~ischar(dof)
        optionally_close_system(mdl);
        error(['The block''s DOF name (' maskVars('dof') ') must be a string']);
    end
    if ~nbNoiseSinksByDof.isKey(dof)
        nbNoiseSinksByDof(dof) = blk;
    else
        optionally_close_system(mdl);
        error(['The block''s DOF name (' maskVars('dof') ') is already in use by another NbNoiseSink block: ' nbNoiseSinksByDof(dof)]);
    end
end

% Gather all NbNoiseCal blocks into a hashtable, indexed by the DOF name
nbNoiseCalsByDof = containers.Map();
disp([num2str(numel(nbNoiseCals)) ' NbNoiseCal block(s) found in model ' mdl]);
if numel(nbNoiseCals) < 1
    optionally_close_system(mdl);
    error('The model must contain at least one NbNoiseCal block');
end
for n = 1:numel(nbNoiseCals)
    blk = nbNoiseCals{n};
    maskVars = containers.Map(get_param(blk, 'MaskNames'), get_param(blk, 'MaskValues'));
    disp(['    ' blk ' :: ' maskVars('dof')]);
    dof = evalin('base', maskVars('dof'));
    if ~ischar(dof)
        optionally_close_system(mdl);
        error(['The block''s DOF name (' maskVars('dof') ') must be a string']);
    end
    if ~nbNoiseCalsByDof.isKey(dof)
        nbNoiseCalsByDof(dof) = blk;
    else
        optionally_close_system(mdl);
        error(['The block''s DOF name (' maskvars('dof') ') is already in use by another NbNoiseCal block: ' nbNoiseCalsByDof(dof)]);
    end
end

% Check for one-to-one correspondence between the NbNoiseSink and
% NbNoiseCal blocks
mismatchedDofs = setxor(nbNoiseSinksByDof.keys(), nbNoiseCalsByDof.keys());
if ~isempty(mismatchedDofs)
    if nbNoiseSinksByDof.isKey(mismatchedDofs{1})
        optionally_close_system(mdl);
        error(['Missing NbNoiseCal block for DOF name ' mismatchedDofs{1}]);
    else
        optionally_close_system(mdl);
        error(['Missing NbNoiseSink block for DOF name ' mismatchedDofs{1}]);
    end
end

%% Choose a NbNoiseSink/Cal pair according to the requested DOF

if isempty(opt.dof)
    % No DOF was requested in the input arguments.  If exactly one DOF was
    % defined, then go ahead and use it.
    if numel(nbNoiseSinks) == 1 && numel(nbNoiseCals) == 1
        nbNoiseSink = nbNoiseSinks{1};
        nbNoiseCal = nbNoiseCals{1};
    else
        optionally_close_system(mdl);
        error('The model defines multiple DOFs, so a DOF name must be passed as an argument to this function');
    end
else
    % A DOF was requested.
    if nbNoiseSinksByDof.isKey(opt.dof) && nbNoiseCalsByDof.isKey(opt.dof)
        nbNoiseSink = nbNoiseSinksByDof(opt.dof);
        nbNoiseCal = nbNoiseCalsByDof(opt.dof);
        disp(['Multiple DOFs defined -- using the requested DOF (' opt.dof ')']);
    else
        optionally_close_system(mdl);
        error(['The requested DOF name (' opt.dof ') is not defined in the model']);
    end
end

%% Evaluate each NbNoiseSource block's asd, and set up noise/calibration TFs

disp([num2str(numel(nbNoiseSources)) ' NbNoiseSource block(s) found in model ' mdl]);
if numel(nbNoiseSources) < 1
    optionally_close_system(mdl);
    error('The model must contain at least one NbNoiseSource block');
end

noises = num2cell(struct('name', nbNoiseSources, 'f', freq, 'asd', []))';
% Set numerator for noise/calibration TFs, and open the loop
ioSink = linio(nbNoiseSink, 1, 'out', 'on');
% Set denominator for calibration TF (cal to sink)
ioCal = linio(nbNoiseCal, 1, 'in');
for n = 1:numel(nbNoiseSources)
    blk = nbNoiseSources{n};
    % Set denominator for noise TF (source to sink)
    ioSource(n) = linio(blk, 1, 'in'); %#ok<AGROW>
    % Evaluate the noise ASD
    maskVars = containers.Map(get_param(blk, 'MaskNames'), get_param(blk, 'MaskValues'));
    disp(['    ' blk ' :: ' maskVars('asd')]);
    % Note: evaluation is done in the base workspace (any variables set in
    % the model workspace are ignored).  The NbNoiseSource block mask is
    % set to NOT evaluate anything automatically.  This way, the noise
    % budget spectra don't have to be defined when the model is used for
    % purposes other than making a noise budget.
    noises{n}.asd = evalin('base', maskVars('asd'));
    % Sanity checks on the ASD
    if numel(noises{n}.asd) ~= 1 && numel(noises{n}.asd) ~= numel(freq)
        optionally_close_system(mdl);
        error(['The length of the block''s ASD (' maskVars('asd') ') doesn''t match the frequency vector' char(10) ...
            'ASD''s length is ' num2str(numel(noises{n}.asd)) ...
            ' and frequency vector''s length is ' num2str(numel(freq))]);
    end
    if ~isreal(noises{n}.asd)
        optionally_close_system(mdl);
        error(['The block''s spectrum (' maskVars('asd') ') is not real-valued']);
    end
end
optionally_close_system(mdl);
io = [ioSink ioCal ioSource];

%% Perform the linearization using FlexTf functions

[sys, flexTfs] = linFlexTf(mdl, io);
sys = prescale(sys, {2*pi*min(freq), 2*pi*max(freq)}); % attempt to improve numerical accuracy
sys = linFlexTfFold(sys, flexTfs);

%% Apply noise/calibration TFs to each NbNoiseSource's spectrum

cal = 1/sys(1);
for n = 1:numel(nbNoiseSources)
    noises{n}.asd = noises{n}.asd .* abs(squeeze(freqresp(sys(n+1)*cal, 2*pi*freq)))';
end

end