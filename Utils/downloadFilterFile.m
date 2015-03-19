function [filters, gpsWhenLoaded] = downloadFilterFile(model, gps)

%% Define location of DAQ SVN and temporary file to hold filters

ifo = lower(model(1:2));
daqsvn = ['https://daqsvn.ligo-la.caltech.edu/svn/' ifo '_filter_files/' ifo '_archive/'];
tmpName = [tempname '_' model '.txt'];

%% Convert GPS to UTC to obtain SVN revision date

gwd = GWData();
gps = gwd.gps_convert(gps, gwd.gps_time(), false);
javaDate = java.util.Date(1000*gwd.gps_to_unix(gps));
dateFormatter = java.text.SimpleDateFormat('yyyyMMdd');
timeFormatter = java.text.SimpleDateFormat('HHmmss');
dateFormatter.setTimeZone(java.util.TimeZone.getTimeZone('UTC'));
timeFormatter.setTimeZone(java.util.TimeZone.getTimeZone('UTC'));
rev = ['{' char(dateFormatter.format(javaDate)) 'T' char(timeFormatter.format(javaDate)) 'Z}'];

%% Set up Kerberos, fetch the filter file, and parse it

disp(['Downloading filter file ' model '.txt for GPS ' num2str(gps)]);
gwd.make_kerberos_ready();
statusBad = system(['svn export -q -r' rev ' ' daqsvn model '.txt ' tmpName]);
if statusBad || ~exist(tmpName, 'file')
    error(['Unable to download filter file ' model '.txt from the DAQ SVN for GPS time ' num2str(gps)]);
end
cleanupFile = onCleanup(@() delete(tmpName));
filters = readFilterFile(tmpName);
filters.fileName = [model '.txt'];
clear cleanupFile;

%% Find out when the file was loaded

[statusBad, cmdOut] = system(['svn info --xml -r' rev ' ' daqsvn model '.txt']);
if statusBad
    error(['Unable to get svn info on filter file ' model '.txt from the DAQ SVN for GPS time ' num2str(gps)]);
end

fid = fopen(tmpName, 'w');
cleanupFile = onCleanup(@() delete(tmpName));
fprintf(fid, cmdOut);
fclose(fid);
dom = xmlread(tmpName);
clear cleanupFile;

dateWhenLoaded = char(dom.getElementsByTagName('commit').item(0).getElementsByTagName('date').item(0).getFirstChild().getData());
gpsWhenLoaded = GWData.gps_time([dateWhenLoaded(1:10) ' ' dateWhenLoaded(12:19) ' UTC']);

end
