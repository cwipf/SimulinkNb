function saveFunctionCache(varargin)
    % saves functionCache variable to disk

    if numel(varargin) < 1
        fileName = 'functionCache.mat';
    else
        fileName = varargin{1};
        if ~ischar(fileName)
            error('cacheFunction:badArg','argument is not a valid filename');
        end
    end

    functionCache = getappdata(0, 'functionCache'); %#ok<NASGU>
    save(fileName, 'functionCache');

end