function [sys, flexTfs] = linFlexTf(varargin)
% LINFLEXTF  Linearizes a Simulink model while removing FlexTf blocks
%
%   [sys, flexTfs] = linFlexTf(...)
%
%   LINFLEXTF is a wrapper for Matlab's LINLFT, and can be called in almost
%   the same way.  The only difference is that it's not necessary to
%   specify the set of blocks to be removed, since this is automatically
%   determined by LINFLEXTF.  The blocks removed are those that are
%   annotated with a "FlexTf: EXPR" line at the top of their block
%   description.
%
%   For each FlexTf-tagged block, LINFLEXTF evaluates the EXPR.  The result
%   is expected to be a linear model (such as an FRD object containing
%   frequency response data), which can be substituted in place of the
%   block in question.
%
%   LINFLEXTFFOLD (analogous to LINLFTFOLD) can be used to recombine the
%   Simulink linearization and FlexTf models that are the output arguments
%   of LINFLEXTF.  It may be advantageous to call PRESCALE to improve the
%   numerical accuracy before invoking LINFLEXTFFOLD.
%
%   See also: LINFLEXTFFOLD, LINLFT, LINLFTFOLD, PRESCALE, FRD.

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

for n = 1:numel(flexTfBlocks)
    blk = flexTfBlocks{n};
    expr = get_param(blk, 'Description');
    expr = strtrim(expr(length('FlexTf:')+1:end));
    disp(['    ' blk ' :: ' expr]);
    % Note: evaluation is done in the base workspace
    % Variables from the model workspace (if any) are ignored
    flexTfs{n} = evalin('base', expr);
end

%% Check that each FlexTf has the same I/O count as its corresponding block
% Note: this code can be omitted if it's too slow or causes problems.
% It's a useful debugging aid, but not required for the linearization.

disp('Compiling model to check for I/O port mismatch');
% A compile is needed in order to use the CompiledPortWidth block property.
% But compiling puts the model in a weird state where it cannot be closed
% by the user!  The onCleanup routine is meant to ensure that the model
% is never left in that state.
feval(mdl, [], [], [], 'lincompile');
cleanup = onCleanup(@() feval(mdl, [], [], [], 'term'));
for n = 1:numel(flexTfBlocks)
    % Count the inputs and outputs to each block.  This is tricky!  If the
    % I/O consists of scalars and vectors, it should be fine, but if the
    % block uses buses/matrices/etc, watch out!
    blk = flexTfBlocks{n};
    blkPorts = get_param(blk, 'PortHandles');
    [blkInputs, blkOutputs] = deal(0);
    for j = 1:numel(blkPorts.Inport)
        blkInputs = blkInputs + get_param(blkPorts.Inport(j), 'CompiledPortWidth');
        blkOutputs = blkOutputs + get_param(blkPorts.Outport(j), 'CompiledPortWidth');
    end
    blkSize = [blkOutputs, blkInputs];

    % Counting the FlexTf's inputs and outputs is much easier
    flexTfSize = size(flexTfs{n});

    if ~isequal(flexTfSize, blkSize)
        clear cleanup;
        close_system(mdl);
        error(['I/O port mismatch between block "' blk '" and FlexTf "' expr '"' char(10) ...
            'Block''s dimensions are (' strtrim(evalc('disp(blkSize)')) ') ' ...
            'and FlexTf''s dimensions are (' strtrim(evalc('disp(flexTfSize)')) ')']);
    end
end
clear cleanup;
close_system(mdl);

%% Linearize the model with the FlexTf blocks factored out

disp('Linearizing model');
flexTfs = append(flexTfs{:});
varargin{end+1} = flexTfBlocks;
sys = linlft(varargin{:});

end
