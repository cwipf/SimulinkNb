function data = getNdsData(chanList, start, duration)
%GETNDSDATA  Fetch data from NDS server
%
%   Syntax:
%
%   data = getNdsData(chanList, start, duration)
%
%   Description:
%
%   getNdsData(CHANLIST, START, DURATION) uses the java nds2-client library
%   to obtain data from an NDS1 or NDS2 server.  The server's address (in
%   HOST:PORT format) is obtained from the environment variable NDSSERVER.
%   CHANLIST is a cell array of channel names, START is a GPS time, and the
%   DURATION is given in seconds.  The returned DATA struct array has one
%   entry for each channel, with fields for the channel name ('name'), the
%   data points ('data'), the sample rate ('rate'), the start time
%   ('start') and the duration ('duration').

%% Validate arguments

if ischar(chanList)
    chanList = {chanList};
elseif ~iscellstr(chanList)
    error('chanList must be a cell array of NDS channel names');
end

if ~isreal(start) || ~isreal(duration) || start <= 0 || duration <= 0
    error('start GPS time and duration must be integers > 0');
end

%% Open the connection

conn = setupConnection();
cleanupConn = onCleanup(@() conn.close());

%% Request data

maxChans = 100;

s = '';
if numel(chanList) > 1
    s = 's';
end
disp(['Fetching ' num2str(numel(chanList)) ' channel' s ...
    ', start GPS ' num2str(start), ', duration ' num2str(duration) ' sec']);

% Provide a status bar when many channels are requested
h = 0;
if numel(chanList) > maxChans
    h = waitbar(0, ['Fetching ' num2str(numel(chanList)) ' channels...'], ...
        'CreateCancelBtn', 'setappdata(gcbf, ''canceling'', 1)', 'Name', 'getNdsData');
    setappdata(h, 'myX', 0);
    setappdata(h, 'canceling', 0);
    cleanupWindow = onCleanup(@() delete(h));
end

% Define a callback to update the status bar
    function cb(inc)
        if h
            if getappdata(h, 'canceling')
                error('getNdsData:userCancelled', 'NDS data request cancelled')
            end
            x = getappdata(h, 'myX') + inc/numel(chanList);
            setappdata(h, 'myX', x);
            waitbar(x, h);
        end
    end

data = fetchBufs(conn, chanList, start, duration, maxChans, @cb);

%% Close connection, return data in mDV format

clear cleanupConn;
if h
    clear cleanupWindow;
end
data = convertBufs(data);

end

function conn = setupConnection(varargin)

if ~exist('nds2.connection', 'class')
    % check hardcoded MacPorts path /opt/local/bin, which may not otherwise
    % be picked up by the matlab app's PATH environment variable
    pathsToCheck = {'', '/opt/local/bin/'};
    for n = 1:numel(pathsToCheck)
        [status, output] = system([pathsToCheck{n} 'nds-client-config --javaclasspath']);
        if ~status
            javaaddpath(deblank(output));
            break;
        end
    end
    if status
        error('Can''t find nds2-client: please ensure it''s installed and available on the PATH');
    end
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

disp(['Connecting to NDS server ' host]);
conn = nds2.connection(host, port);

end

function bufs = fetchBufs(conn, chanList, start, duration, maxChans, cb)

bufs = {};
if numel(chanList) < 1
    return;
end
if numel(chanList) > maxChans
    for n = 1:maxChans:numel(chanList)
        endN = min(numel(chanList), n+maxChans-1);
        bufsN = fetchBufs(conn, chanList(n:endN), start, duration, maxChans, cb);
        bufs = [bufs bufsN]; %#ok<AGROW>
    end
    return;
end
try
    bufs = conn.fetch(start, start+duration, chanList);
    cb(numel(chanList));
    return;
catch exc
    if strcmp(exc.identifier, 'getNdsData:userCancelled')
        rethrow(exc);
    end
    if numel(chanList) == 1
        disp(['Failed to fetch channel ' chanList{1}]);
        cb(numel(chanList));
        rethrow(exc);
    end
    chanList1 = chanList(1:floor(end/2));
    chanList2 = chanList(floor(end/2)+1:end);
    bufs = [fetchBufs(conn, chanList1, start, duration, maxChans, cb)...
        fetchBufs(conn, chanList2, start, duration, maxChans, cb)];
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