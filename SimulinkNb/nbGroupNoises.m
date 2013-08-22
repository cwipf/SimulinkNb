function [ nb ] = nbGroupNoises(mdl, noises)
%NBGROUPNOISES  Organizes the noise array returned by NBFROMSIMULINK
%   [ nb ] = NBGROUPNOISES(mdl, noises)
%
%   NBGROUPNOISES combines noises whose NbNoiseSource blocks share the same
%   "Group" parameter.  It returns a hierarchical NOISEMODEL object, whose
%   title is set based on the NbNoiseSink's "DOF name" parameter, and whose
%   Y-label is set based on the NbNoiseCal's "unit" parameter.
%
%   See also: NBFROMSIMULINK, NOISEMODEL

%% Look up NB DOF name and unit

load_system(mdl);

nbNoiseSink = find_system(mdl, 'Tag', 'NbNoiseSink');
maskVars = containers.Map(get_param(nbNoiseSink{1}, 'MaskNames'), get_param(nbNoiseSink{1}, 'MaskValues'));
dof = evalin('base', maskVars('dof'));

nbNoiseCal = find_system(mdl, 'Tag', 'NbNoiseCal');
maskVars = containers.Map(get_param(nbNoiseCal{1}, 'MaskNames'), get_param(nbNoiseCal{1}, 'MaskValues'));
unit = evalin('base', maskVars('unit'));

%% Gather grouped noises into a hashtable (containers.Map object)

groupMap = containers.Map();
for n = 1:numel(noises)
    blk = noises{n}.name;
    maskVars = containers.Map(get_param(blk, 'MaskNames'), get_param(blk, 'MaskValues'));
    groupName = evalin('base', maskVars('group'));
    if strcmp(groupName, '')
        groupName = blk;
    end
    if ~groupMap.isKey(groupName)
        groupMap(groupName) = noises(n);
    else
        groupMap(groupName) = [groupMap(groupName) noises{n}];
    end
end

close_system(mdl);

groupNames = keys(groupMap);
disp([num2str(numel(groupNames)) ' noise groups found in model ' strtrim(evalc('disp(mdl)'))]);

%% Form a hierarchy of NoiseModel objects
% Currently this goes only one level deep, so we can have sub-budgets but
% not sub-sub-budgets etc.  We could allow for more hierarchy by using cell
% arrays in the source block's group field.

groupedNoises = cell(size(groupNames));
for n = 1:numel(groupNames)
    groupedNoises{n} = groupMap(groupNames{n});
    disp(['    ' groupNames{n} ' :: block count ' num2str(numel(groupedNoises{n}))]);
    if numel(groupedNoises{n}) > 1
        groupedNoises{n} = NoiseModel(groupedNoises{n});
        groupedNoises{n}.title = [groupNames{n} ' NoiseBudget'];
        groupedNoises{n}.unit = unit;
    else
        groupedNoises{n} = groupedNoises{n}{:};
    end
    groupedNoises{n} = renamed(groupedNoises{n}, groupNames{n});
end

nb = NoiseModel(groupedNoises);
nb.title = [dof ' NoiseBudget'];
nb.unit = unit;

end