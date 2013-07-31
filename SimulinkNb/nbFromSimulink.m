function [noises, sys] = nbFromSimulink(mdl, freq)
%NBFROMSIMULINK  Generates noise budget terms from a Simulink model
%
%   [noises, sys] = nbFromSimulink(mdl, freq)

%% Locate all NbNoiseSource and NbNoiseSink blocks within the model

load_system(mdl);
nbNoiseSources = find_system(mdl, 'RegExp', 'on', 'Description', '^[Nn][Bb][Nn]oise[Ss]ource');
nbNoiseSinks = find_system(mdl, 'RegExp', 'on', 'Description', '^[Nn][Bb][Nn]oise[Ss]ink');
disp([num2str(numel(nbNoiseSources)) ' NbNoiseSource blocks and ' ...
    num2str(numel(nbNoiseSinks)) ' NbNoiseSink blocks found in model ' strtrim(evalc('disp(mdl)'))]);

if numel(nbNoiseSources) < 1
    close_system(mdl);
    error('The model must contain at least one NbNoiseSource block');
elseif numel(nbNoiseSinks) ~= 1
    close_system(mdl);
    error('The model must contain exactly one NbNoiseSink block');
end

%% Extract and evaluate each NbNoiseSource block's expression, and set up calibration TFs

% Set numerator for calibration TFs, and open the loop
io(1) = linio(nbNoiseSinks{1}, 1, 'out', 'on');

noises = num2cell(struct('name', nbNoiseSources, 'f', freq, 'asd', []))';
for n = 1:numel(nbNoiseSources)
    blk = nbNoiseSources{n};
    expr = get_param(blk, 'Description');
    expr = strtrim(expr(length('NbNoiseSource:')+1:end));
    disp(['    ' blk ' :: ' expr]);
    % Note: evaluation is done in the base workspace (any variables set in
    % the model workspace are ignored)
    noises{n}.asd = evalin('base', expr);
    % Set denominator for calibration TFs
    io(n+1) = linio(blk, 1, 'in'); %#ok<AGROW>
end
close_system(mdl);

%% Perform the linearization using FlexTf functions

[sys, flexTfs] = linFlexTf(mdl, io);
sys = prescale(sys, {2*pi*min(freq), 2*pi*max(freq)}); % attempt to improve numerical accuracy
sys = linFlexTfFold(sys, flexTfs);

%% Apply a calibration TF to each NbNoiseSource's spectrum

for n = 1:numel(nbNoiseSources)
    noises{n}.asd = noises{n}.asd .* abs(squeeze(freqresp(sys(n), freq, 'Hz')))';
end

end