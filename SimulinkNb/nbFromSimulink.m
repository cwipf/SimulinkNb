function [noises, sys] = nbFromSimulink(mdl, freq)
%NBFROMSIMULINK  Generates noise budget terms from a Simulink model
%
%   [noises, sys] = nbFromSimulink(mdl, freq)
%
%   NBFROMSIMULINK first searches the model for blocks whose descriptions
%   are annotated with "NbNoiseSource: EXPR" or "NbNoiseSink: EXPR".  The
%   model is expected to contain at least one source, and exactly one sink.
%
%   Each source block's EXPR is evaluated, and should evaluate to the ASD
%   of the noise at the point where the source block is summed into the
%   model.  The EXPR can be either a scalar value or an array.  (If an
%   array is used, you need to make sure it's interpolated to match the
%   FREQ vector that's passed as an argument to NBFROMSIMULINK.)
%
%   The sink block's EXPR is currently ignored.
%
%   NBFROMSIMULINK linearizes the model, using LINFLEXTF, to obtain
%   transfer functions from each source to the sink (with the loop opened
%   after the sink).  These TFs are used to calibrate the source spectra.
%
%   Output arguments:
%   NOISES -- contains the calibrated spectra.  Each spectrum is stored in
%   a struct with fields 'f' (frequency vector), 'asd', and 'name' (path to
%   the source block).  NOISES is a cell array of these noise structs.
%
%   SYS -- the linearized Simulink model containing the calibration TFs.
%
%   See also: LINFLEXTF

%% Locate all NbNoiseSource and NbNoiseSink blocks within the model

load_system(mdl);
nbNoiseSources = find_system(mdl, 'RegExp', 'on', 'Description', '^[Nn][Bb][Nn]oise[Ss]ource');
nbNoiseSinks = find_system(mdl, 'RegExp', 'on', 'Description', '^[Nn][Bb][Nn]oise[Ss]ink');

disp([num2str(numel(nbNoiseSinks)) ' NbNoiseSink blocks found in model ' strtrim(evalc('disp(mdl)'))]);

for n = 1:numel(nbNoiseSinks)
    blk = nbNoiseSinks{n};
    expr = get_param(blk, 'Description');
    expr = strtrim(expr(length('NbNoiseSink:')+1:end));
    disp(['    ' blk ' :: ' expr]);
end

if numel(nbNoiseSinks) ~= 1
    close_system(mdl);
    error('The model must contain exactly one NbNoiseSink block');
end

disp([num2str(numel(nbNoiseSources)) ' NbNoiseSource blocks found in model ' strtrim(evalc('disp(mdl)'))]);

if numel(nbNoiseSources) < 1
    close_system(mdl);
    error('The model must contain at least one NbNoiseSource block');
end

%% Extract and evaluate each NbNoiseSource block's expression, and set up calibration TFs

noises = num2cell(struct('name', nbNoiseSources, 'f', freq, 'asd', []))';
% Set numerator for calibration TFs, and open the loop
io(1) = linio(nbNoiseSinks{1}, 1, 'out', 'on');
for n = 1:numel(nbNoiseSources)
    blk = nbNoiseSources{n};
    expr = get_param(blk, 'Description');
    expr = strtrim(expr(length('NbNoiseSource:')+1:end));
    disp(['    ' blk ' :: ' expr]);
    % Note: evaluation is done in the base workspace (any variables set in
    % the model workspace are ignored)
    noises{n}.asd = evalin('base', expr);
    % Sanity check on the expr
    if numel(noises{n}.asd) ~= 1 && numel(noises{n}.asd) ~= numel(freq)
        close_system(mdl);
        error(['Length of spectrum ' expr ' doesn''t match frequency vector' char(10) ...
            'Spectrum''s length is ' num2str(numel(noises{n}.asd)) ...
            ' and frequency vector''s length is ' num2str(numel(freq))]);
    end
    % Set denominator for calibration TFs
    io(n+1) = linio(blk, 1, 'in'); %#ok<AGROW>
end
close_system(mdl);

%% Perform the linearization using FlexTf functions

[sys, flexTfs] = linFlexTf(mdl, io);
sys = prescale(sys, {2*pi*min(freq), 2*pi*max(freq)}); % attempt to improve numerical accuracy
sys = linFlexTfFold(sys, flexTfs);

%% Apply calibration TF to each NbNoiseSource's spectrum

for n = 1:numel(nbNoiseSources)
    noises{n}.asd = noises{n}.asd .* abs(squeeze(freqresp(sys(n), 2*pi*freq)))';
end

end