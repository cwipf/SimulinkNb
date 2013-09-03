function [ nb ] = nbGroupNoises(mdl, noises, sys)
%NBGROUPNOISES  Organizes the noises array returned by NBFROMSIMULINK
%   [ nb ] = NBGROUPNOISES(mdl, noises, sys)
%
%   NBGROUPNOISES combines noises whose NbNoiseSource blocks share the same
%   grouping parameters ("Group", "Sub-group", etc.).  It returns a
%   hierarchical NOISEMODEL object, whose title is set based on the
%   NbNoiseCal block's "DOF name" parameter, and whose Y-label is set based
%   on the "unit" parameter.
%
%   See also: NBFROMSIMULINK, NOISEMODEL

%% Validate the arguments

if ~ischar(mdl)
    error('The model name is not a string');
elseif ~iscell(noises)
    error('The noises are not a cell array');
elseif ~isobject(sys)
    error('The sys object is not an object');
elseif size(sys, 2) ~= numel(noises) + 1
    error('The noises and the sys object have mismatched dimensions')
end

%% Get the DOF and unit settings from the NbNoiseCal block

load_system(mdl);
nbNoiseCal = sys(1).InputName{:};
disp(['NbNoiseCal block is ' nbNoiseCal ' (DOF ' ...
    get_param(nbNoiseCal, 'dof') ', unit ' get_param(nbNoiseCal, 'unit') ')']);
dof = evalin('base', get_param(nbNoiseCal, 'dof'));
unit = evalin('base', get_param(nbNoiseCal, 'unit'));
if ~ischar(dof) || ~ischar(unit)
    error(['Invalid NbNoiseCal block ' nbNoiseCal char(10) ...
        'The DOF name (' get_param(nbNoiseCal, 'dof') ') ' ...
        'and unit (' get_param(nbNoiseCal, 'unit') ' must be strings']);
end

%% Form groups and output a NoiseModel object

% groupAtLevel is a (recursive) local function defined below
group = groupAtLevel(noises, 1, unit);

nb = NoiseModel(group);
nb.title = [dof ' NoiseBudget'];
nb.unit = unit;

end

function [ groupedNoises ] = groupAtLevel(noises, level, unit)
%% Limit the recursion depth

groupVar = {'group', 'subgroup', 'subsubgroup', 'subsubsubgroup'};
if level > numel(groupVar)
    groupedNoises = noises;
    return;
end

%% Organize the noises in a hashtable (containers.Map object), indexed by group

noisesByGroup = containers.Map();
for n = 1:numel(noises)
    noise = noises{n};
    if str2double(get_param(noise.name, 'groupNest')) >= level
        groupName = evalin('base', get_param(noise.name, groupVar{level}));
        if ~ischar(groupName)
            error(['Invalid NbNoiseSource block ' noise.name char(10) ...
                'The ' groupVar{level} ' parameter (' ...
                get_param(noise.name, groupVar{level}) ') must be a string']);
        end
    else
        groupName = noise.name;
    end
    if isempty(groupName)
        groupName = noise.name;
    end
    if ~noisesByGroup.isKey(groupName)
        noisesByGroup(groupName) = {noise};
    else
        noisesByGroup(groupName) = [noisesByGroup(groupName) {noise}];
    end
end

%% Group the noises

groupNames = noisesByGroup.keys();
groupedNoises = cell(size(groupNames));
disp([repmat('    ', 1, level - 1) 'Found ' num2str(numel(groupNames)) ' noise ' groupVar{level} 's:']);
for n = 1:numel(groupNames)
    groupName = groupNames{n};
    group = noisesByGroup(groupName);
    disp([repmat('    ', 1, level - 1) '* ' groupName]);
    if numel(group) == 1
        group = group{1};
    else
        group = groupAtLevel(group, level + 1, unit);
        group = NoiseModel(group);
        group.title = [groupName ' NoiseBudget'];
        group.unit = unit;
    end
    group = renamed(group, groupName);
    groupedNoises{n} = group;
end

end