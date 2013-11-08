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
    elseif ~compareOpt(cachedVarargin{1}, varargin{1})
        continue;
    elseif ~all(cellfun(@compareVect, cachedVarargin(2:end), varargin(2:end)))
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

function out = compareOpt(opt1, opt2) %#ok<INUSD>

out = strcmp(evalc('display(opt1)'), evalc('display(opt2)'));

end

function out = compareVect(v1, v2)

if numel(v1) ~= numel(v2)
    out = false;
else
    out = all(v1 == v2);
end

end