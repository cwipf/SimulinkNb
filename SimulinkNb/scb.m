function scb(block)
%SCB  Set current block.
%   SCB(BLOCK) redefines the current block returned by GCB to be BLOCK.
%
%   See also GCB, GCS.
%   Downloaded from the Matlab File Exchange
%   http://www.mathworks.com/matlabcentral/fileexchange/13833-scb
try
    if ~strcmp('block',get_param(block,'Type'))
        error('SCB:arg','Argument is not of type ''block''')
    end
catch
    error('SCB:obj','Invalid Simulink object name: %s',block)
end

% Split Argument to System and Block-Name.
%[CurrentSystem,CurrentBlock] = fileparts(block);
% fix for block names containing '/' --ccw
CurrentSystem = get_param(block, 'Parent');
CurrentBlock = get_param(block, 'Name');

% Get the Stateflow Root object.
root = sfroot;

% Set the Current System to be the System of Block.
root.set('CurrentSystem',CurrentSystem); 

% Deselect Block that is Current Block in this System.
set_param(gcb,'Selected','off')

% Set Current Block in this System to be Block.
root.getCurrentSystem.set('CurrentBlock',CurrentBlock)

% Turn Selection on.
set_param(gcb,'Selected','on')
