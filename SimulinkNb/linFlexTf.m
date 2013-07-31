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
    close_system(mdl);
    warning('No FlexTf blocks found: standard linearization will be performed');
    sys = linearize(varargin{:});
    return;
end

%% Extract and evaluate each FlexTf block's expression

for n = 1:numel(flexTfBlocks)
    blk = flexTfBlocks{n};
    expr = get_param(blk, 'Description');
    expr = strtrim(expr(length('FlexTf:')+1:end));
    disp(['    ' blk ' :: ' expr]);
    % Note: evaluation is done in the base workspace (any variables set in
    % the model workspace are ignored)
    flexTfs{n} = evalin('base', expr);
end
close_system(mdl);

%% Linearize the model with the FlexTf blocks factored out

flexTfs = append(flexTfs{:});
varargin{end+1} = flexTfBlocks;
sys = linlft(varargin{:});

end