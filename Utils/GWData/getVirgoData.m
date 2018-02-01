function out = getVirgoData(channels,dtype,start_time,duration)
%GETVIRGODATA  Read Virgo data from ffl file index
%
% data = getVirgoData(channels,dtype,start_time,duration)
%
% Input:
% channels - string or cell array of strings with channel names
% dtype - data type (raw, trend, ...), data will be read from dtype.ffl file
% start_time - GPS start time of data to read
% duration - duration in seconds of data stretch to read
%
% Output:
% data - object array containing data for each requested channel
%   data(ii).name - channel name
%   data(ii).data - data time series
%   data(ii).rate - sampling rate of data
%   data(ii).start - GPS start time of time series
%   data(ii).duration - duration in seconds of time series

if isstr(channels)
  channels = {channels};
end

for ii=1:length(channels)
  
  [data time] = frgetvectN(['/virgoData/ffl/' dtype '.ffl'], ...
                      channels{ii}, start_time, duration);

  out(ii).name = channels{ii}
  out(ii).data = data;
  out(ii).rate = 1/(time(2)-time(1));
  out(ii).start = time(1);
  out(ii).duration = duration;

end

