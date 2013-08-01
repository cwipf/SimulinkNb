function [sys, flexTfs] = linFlexTf(varargin)
% LINFLEXTF  Linearizes a Simulink model while removing FlexTf blocks
%
%   [sys, flexTfs] = linFlexTf(...)
%
%   LINFLEXTF is analogous to LINLFT, and can be called in almost the same
%   way.  However, it's not necessary to specify the set of blocks to be
%   removed, since this is automatically determined by LINFLEXTF.
%
%   The blocks removed are those that are annotated with a "FlexTf: EXPR"
%   line at the top of their block description.  LINFLEXTF evaluates each
%   EXPR.  The result is expected to be a linear model (such as an FRD
%   object), which can be substituted in place of the block in question.
%   The resulting linear models are returned in the second output argument.
%
%   LINFLEXTFFOLD can be used to recombine the Simulink linearization and
%   the FlexTf models returned by LINFLEXTF (analogous to LINLFTFOLD).
%   Note that it can be advantageous to call PRESCALE to improve the
%   numerical accuracy before invoking LINFLEXTFFOLD.
%
%   See also LINFLEXTFFOLD, LINLFT, LINLFTFOLD, PRESCALE, FRD.

%% Locate all FlexTf blocks within the model

mdl = varargin{1};
load_system(mdl);

flexTfBlocks = find_system(mdl, 'RegExp', 'on', 'Description', '^[Ff]lex[Tt][Ff]:');
flexTfs = cell(size(flexTfBlocks));
disp([num2str(numel(flexTfBlocks)) ' FlexTf blocks found in model ' strtrim(evalc('disp(mdl)'))]);

if numel(flexTfBlocks) < 1
    warning('No FlexTf blocks found: standard linearization will be performed');
    close_system(mdl);
    sys = linearize(varargin{:});
    return;
end

%% Extract and evaluate each FlexTf block's expression

% Must compile in order to access the CompiledPortWidth property
feval(mdl, [], [], [], 'lincompile');
cleanup = onCleanup(@() feval(mdl, [], [], [], 'term'));

for n = 1:numel(flexTfBlocks)
    blk = flexTfBlocks{n};
    expr = get_param(blk, 'Description');
    % Check number of inputs/outputs to each block
    % (this is tricky because some ports carry vector signals)
    blkPorts = get_param(blk, 'PortHandles');
    [blkInputs, blkOutputs] = deal(0);
    for j = 1:numel(blkPorts.Inport)
        blkInputs = blkInputs + get_param(blkPorts.Inport(j), 'CompiledPortWidth');
        blkOutputs = blkOutputs + get_param(blkPorts.Outport(j), 'CompiledPortWidth');
    end
    blkSize = [blkOutputs, blkInputs];
    expr = strtrim(expr(length('FlexTf:')+1:end));
    disp(['    ' blk ' :: ' expr]);
    % Note: evaluation is done in the base workspace (any variables set in
    % the model workspace are ignored)
    flexTfs{n} = evalin('base', expr);
    flexTfSize = size(flexTfs{n});
    % Confirm that the block has the same number of inputs/outputs as the FlexTf
    if ~isequal(flexTfSize, blkSize)
        clear cleanup;
        close_system(mdl);
        error(['I/O ports do not match: block ' blk ' has (' ... 
            strtrim(evalc('disp(blkSize)')) ') but FlexTf ' expr ...
            ' has (' strtrim(evalc('disp(flexTfSize)')) ')']);
    end
end
clear cleanup;
close_system(mdl);

%% Linearize the model with the FlexTf blocks factored out

flexTfs = append(flexTfs{:});
varargin{end+1} = flexTfBlocks;
sys = linlft(varargin{:});

end