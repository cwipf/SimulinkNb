function saveFunctionCache()
    % saves functionCache global variable to disk
    
    FILENAME = 'functionCache.mat';
    
    global functionCache;
    
    save(FILENAME,'functionCache')

end