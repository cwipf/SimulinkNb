function varargout = cacheTickle(varargin)

global tickleCache;

if isempty(tickleCache)
    tickleCache = {};
end

for n = 1:size(tickleCache, 1)
    cachedVarargin = tickleCache{n, 1};
    cachedVarargout = tickleCache{n, 2};
    if numel(cachedVarargin) ~= nargin || numel(cachedVarargout) ~= nargout
        continue;
    elseif ~all(cellfun(@isequaln, cachedVarargin, varargin))
        continue;
    end
    disp('Reusing Optickle results from a previous run (cached in the global variable ''tickleCache'')');
    varargout = cachedVarargout;
    return;
end

% this trick for wrapping a varargin/varargout function comes from:
% http://stackoverflow.com/questions/4895556/how-to-wrap-a-function-using-varargin-and-varargout
[varargout{1:nargout}] = tickle(varargin{:});

tickleCache{end+1, 1} = varargin;
tickleCache{end, 2} = varargout;
tickleCache = tickleCache(max(end-2, 1):end, :);

end
