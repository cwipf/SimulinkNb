function loadFunctionCache(varargin)
    % loads functionCache variable from disk if it doesn't exist
    
    if numel(varargin) < 1
        FILENAME = 'functionCache.mat';
    else
        FILENAME = varargin{1};
        if ~ischar(FILENAME)
            error('cacheFunction:badArg','argument is not a valid filename');
        end
    end
    
    if ~exist(FILENAME,'file')
        warning('cacheFunction:diskCacheNotFound',...
            ['Could not load functionCache from ' FILENAME]);
        return
    end
    
    % check if functionCache is empty
    if isempty(getappdata(0, 'functionCache'))
        % if so, load from disk
        loaded = load(FILENAME);
        setappdata(0, 'functionCache', loaded.functionCache);
    end

end