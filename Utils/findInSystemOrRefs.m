function blks = findInSystemOrRefs(mdl, varargin)
%FINDINSYSTEMORREFS locates blocks in the specified model or any models it references

referencedMdls = find_system(mdl, 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'BlockType', 'ModelReference');
for n = 1:numel(referencedMdls)
    referencedMdls{n} = get_param(referencedMdls{n}, 'ModelName');
    load_system(referencedMdls{n});
end

blks = find_system(mdl, 'FollowLinks', 'on', 'LookUnderMasks', 'all', varargin{:});
for n = 1:numel(referencedMdls)
    blks = [blks; findInSystemOrRefs(referencedMdls{n}, varargin{:})]; %#ok<AGROW>
end

end