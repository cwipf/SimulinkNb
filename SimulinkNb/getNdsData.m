function data = getNdsData(chanList, start, duration)
%GETNDSDATA  Fetch data from NDS server
%
%   Syntax:
%
%   data = getNdsData(chanList, start, duration)
%
%   Description:
%
%   getNdsData(CHANLIST, START, DURATION) uses the GWData library to obtain
%   data from an NDS1 or NDS2 server.
%
%   See also: GWDATA

gwd = GWData();
data = gwd.fetch(start, duration, chanList, 'mDV');

end
