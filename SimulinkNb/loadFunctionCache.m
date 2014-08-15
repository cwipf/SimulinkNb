function loadFunctionCache(varargin)
    % loads functionCache global variable from disk if it doesn't exist
    
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
    
    % declare global
    global functionCache
    % check if functionCache is empty
    if isempty(functionCache)
        % if so, load from disk
        loaded = load(FILENAME);
        functionCache = loaded.functionCache;
    end

end