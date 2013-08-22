function [noises, sys] = nbFromSimulink(mdl, freq)
%NBFROMSIMULINK  Generates noise budget terms from a Simulink model
%
%   [noises, sys] = nbFromSimulink(mdl, freq)
%
%   NBFROMSIMULINK first searches the model for blocks tagged
%   "NbNoiseSource", "NbNoiseSink", or "NbNoiseCal".  The model is expected
%   to contain at least one source, exactly one sink, and exactly one cal
%   block.
%
%   Each source block has a user-defined parameter ASD, which should
%   evaluate to the amplitude spectral density of the noise at the point
%   where the source block is summed into the model.  The ASD can be either
%   a scalar value or an array.  (If an array is used, you need to make
%   sure it's interpolated to match the FREQ vector that's passed as an
%   argument to NBFROMSIMULINK.)
%
%   The sink block has a user-defined parameter DOF, which is currently
%   ignored.
%
%   NBFROMSIMULINK linearizes the model, using LINFLEXTF, to obtain
%   transfer functions from each source and the cal block, to the sink
%   (with the loop opened after the sink).  These TFs are used to calibrate
%   the source spectra.
%
%   Output arguments:
%
%   NOISES -- contains the calibrated spectra.  Each spectrum is stored in
%   a struct with fields 'f' (frequency vector), 'asd' (spectrum), and
%   'name' (path to the source block).  NOISES is a cell array of these
%   noise structs.
%
%   SYS -- the linearized Simulink model containing the calibration TFs.
%
%   See also: LINFLEXTF

%% Locate all NbNoiseSource, NbNoiseSink, and NbNoiseCal blocks within the model

load_system(mdl);
nbNoiseSources = find_system(mdl, 'Tag', 'NbNoiseSource');
nbNoiseSinks = find_system(mdl, 'Tag', 'NbNoiseSink');
nbNoiseCals = find_system(mdl, 'Tag', 'NbNoiseCal');

disp([num2str(numel(nbNoiseSinks)) ' NbNoiseSink blocks found in model ' strtrim(evalc('disp(mdl)'))]);

for n = 1:numel(nbNoiseSinks)
    blk = nbNoiseSinks{n};
    maskVars = containers.Map(get_param(blk, 'MaskNames'), get_param(blk, 'MaskValues'));
    disp(['    ' blk ' :: ' maskVars('dof')]);
end

if numel(nbNoiseSinks) ~= 1
    close_system(mdl);
    error('The model must contain exactly one NbNoiseSink block');
end

disp([num2str(numel(nbNoiseCals)) ' NbNoiseCal blocks found in model ' strtrim(evalc('disp(mdl)'))]);

for n = 1:numel(nbNoiseCals)
    blk = nbNoiseCals{n};
    maskVars = containers.Map(get_param(blk, 'MaskNames'), get_param(blk, 'MaskValues'));
    disp(['    ' blk ' :: ' maskVars('unit')]);
end

if numel(nbNoiseCals) ~= 1
    close_system(mdl);
    error('The model must contain exactly one NbNoiseCal block');
end

disp([num2str(numel(nbNoiseSources)) ' NbNoiseSource blocks found in model ' strtrim(evalc('disp(mdl)'))]);

if numel(nbNoiseSources) < 1
    close_system(mdl);
    error('The model must contain at least one NbNoiseSource block');
end

%% Evaluate each NbNoiseSource block's asd, and set up noise/calibration TFs

noises = num2cell(struct('name', nbNoiseSources, 'f', freq, 'asd', []))';
% Set numerator for noise/calibration TFs, and open the loop
ioSink = linio(nbNoiseSinks{1}, 1, 'out', 'on');
% Set denominator for calibration TF (cal to sink)
ioCal = linio(nbNoiseCals{1}, 1, 'in');
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
        close_system(mdl);
        error(['Length of spectrum ' maskVars('asd') ' doesn''t match frequency vector' char(10) ...
            'Spectrum''s length is ' num2str(numel(noises{n}.asd)) ...
            ' and frequency vector''s length is ' num2str(numel(freq))]);
    end
    if ~isreal(noises{n}.asd)
        close_system(mdl);
        error(['Spectrum ' maskVars('asd') ' is not real-valued']);
    end
end
close_system(mdl);
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