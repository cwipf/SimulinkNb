function loadFunctionCache()
    % loads functionCache global variable from disk if it doesn't exist
    
    FILENAME = 'functionCache.mat';
    
    if ~exist(FILENAME,'file')
        warning('cacheFunction:diskCacheNotFound','Could not load functionCache from disk.')
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