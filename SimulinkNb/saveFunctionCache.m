function saveFunctionCache(varargin)
    % saves functionCache global variable to disk
    
    if numel(varargin) < 1
        FILENAME = 'functionCache.mat';
    else
        FILENAME = varargin{1};
        if ~ischar(FILENAME)
            error('cacheFunction:badArg','argument is not a valid filename');
        end
    end
    
    global functionCache; %#ok<NUSED>
    
    save(FILENAME,'functionCache')

end