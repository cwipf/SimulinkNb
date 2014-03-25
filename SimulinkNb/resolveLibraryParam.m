function expr = resolveLibraryParam(expr, blk)
%RESOLVELIBRARYPARAM  Resolve the names of parameter structs inside masked library blocks
%   This is a rather unsavory hack that handles the most common case: where
%   inside the library there are variables like 'libraryPar.something', and
%   in the library's mask 'libraryPar' is defined as 'par.somethingElse'.

%% Input checks

% If expr isn't simply accessing a struct, do nothing
structSplit = regexp(expr, '\.', 'split');
if ~all(cellfun(@isvarname, structSplit))
    return;
end

% If blk or parentBlk is empty, do nothing
if isempty(blk)
    return;
end
parentBlk = get_param(blk, 'Parent');
if isempty(parentBlk)
    return;
end

% If grandparent is empty (recursion stop condition), do nothing
blk = parentBlk;
if isempty(get_param(blk, 'Parent'));
    return;
end

%% Try to resolve the name of the struct referred to by expr

structName = structSplit{1};
maskVars = get_param(blk, 'MaskNames');
if any(strcmp(structName, maskVars))
    newStructName = get_param(blk, structName);
    if ~all(cellfun(@isvarname, regexp(newStructName, '\.', 'split')))
        error(['Block ' blk ' has invalid library parameter ' structName]);
    end
    expr = [newStructName expr(length(structName)+1:end)];
end

%% Recursive step

expr = resolveLibraryParam(expr, blk);

end
