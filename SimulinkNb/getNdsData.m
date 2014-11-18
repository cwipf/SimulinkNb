function data = getNdsData(chanList, start, duration)
%GETNDSDATA  Fetch data from NDS server
%   Detailed explanation goes here

%% Validate arguments

if ischar(chanList)
    chanList = {chanList};
elseif ~iscellstr(chanList)
    error('chanList must be a cell array of NDS channel names');
end

if ~isreal(start) || ~isreal(duration) || start <= 0 || duration <= 0
    error('start GPS time and duration must be integers > 0');
end

%% Get the data

conn = setupConnection();
cleanup = onCleanup(@() conn.close());
disp(['Fetching ' num2str(numel(chanList)) ' channels from ' conn.getHost]);
data = fetchBufs(conn, chanList, start, duration);
clear cleanup;
data = convertBufs(data);

end

function conn = setupConnection(varargin)

if ~exist('nds2.connection', 'class')
    [status, output] = system('nds-client-config --javaclasspath');
    if ~status
        error('Can''t find nds2-client: please ensure it''s installed and available on the PATH');
    end
    javaaddpath(deblank(output));
end

if nargin > 0
    ndsServer = varargin{1};
else
    ndsServer = getenv('NDSSERVER');
    if isempty(ndsServer)
        error('Can''t find an NDS server: please set the NDSSERVER environment variable');
    end
end
ndsServer = regexp(ndsServer, ',', 'split');
ndsServer = regexp(ndsServer{1}, ':', 'split');
host = ndsServer{1};
port = 31200;
if numel(ndsServer) > 1
    port = str2double(ndsServer{2});
end

conn = nds2.connection(host, port);

end

function bufs = fetchBufs(conn, chanList, start, duration)

maxChans = 100;
bufs = {};
if numel(chanList) < 1
    return;
end
if numel(chanList) > maxChans
    for n = 1:maxChans:numel(chanList)
        endN = min(numel(chanList), n+maxChans-1);
        bufsN = fetchBufs(conn, chanList(n:endN), start, duration);
        bufs = [bufs bufsN]; %#ok<AGROW>
    end
    return;
end
try
    bufs = conn.fetch(start, start+duration, chanList);
    return;
catch exc
    if numel(chanList) == 1
        disp(['Failed to fetch channel ' chanList{1}]);
        rethrow(exc);
    end
    chanList1 = chanList(1:floor(end/2));
    chanList2 = chanList(floor(end/2)+1:end);
    bufs = [fetchBufs(conn, chanList1, start, duration)...
        fetchBufs(conn, chanList2, start, duration)];
end

end

function bufs = convertBufs(bufs)

newBufs = struct('name', {}, 'data', {}, 'rate', {}, 'start', {}, 'duration', {});
for n = 1:numel(bufs)
    newBufs(n) = struct('name', bufs(n).getChannel.getName, ...
        'data', bufs(n).getData, ...
        'rate', bufs(n).getChannel.getSampleRate, ...
        'start', bufs(n).getGpsSeconds + bufs(n).getGpsNanoseconds/10^9, ...
        'duration', bufs(n).getLength/bufs(n).getChannel.getSampleRate);
end
bufs = newBufs;

end