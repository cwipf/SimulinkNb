function varargout = cacheFunction(varargin)
% cacheFunction(functionHandle,arg1,arg2,...)
% cacheFunction will evaluate the functionHandle with the arguments that
% follow it, and will store the output in a global appdata property.
% (Use getappdata(0, 'functionCache') to see it.)
% The output will be reused if the same function is called again with the
% same input arguments.

functionCache = getappdata(0, 'functionCache');
cacheSize = getappdata(0, 'functionCacheSize');

if isempty(functionCache)
    functionCache = {};
end
if isempty(cacheSize)
    cacheSize = 100;
end

funchandle = varargin{1};

for n = 1:size(functionCache, 1)
    cachedVarargin = functionCache{n, 1};
    cachedVarargout = functionCache{n, 2};
    if numel(cachedVarargin) ~= nargin || numel(cachedVarargout) ~= max(nargout,1)
        continue;
    elseif ~all(cellfun(@isequaln, cachedVarargin, varargin))
        continue;
    end
    
    disp(['Reusing results of ' func2str(funchandle) ' from a previous run (see "help cacheFunction" for details)']);
    varargout = cachedVarargout;
    % reorder cache to reflect the recent use of this item
    idx = [1:n-1 n+1:size(functionCache, 1) n];
    functionCache = functionCache(idx, :);
    setappdata(0, 'functionCache', functionCache);
    return;
end

% this trick for wrapping a varargin/varargout function comes from:
% http://stackoverflow.com/questions/4895556/how-to-wrap-a-function-using-varargin-and-varargout
[varargout{1:nargout}] = funchandle(varargin{2:end});

functionCache{end+1, 1} = varargin;
functionCache{end, 2} = varargout;
functionCache = functionCache(max(end-cacheSize+1, 1):end, :);
setappdata(0, 'functionCache', functionCache);

end
