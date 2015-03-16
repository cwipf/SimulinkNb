function filters = downloadFilterFile(model, gps)

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

gwd.make_kerberos_ready();
system(['svn export -r' rev ' ' daqsvn model '.txt ' tmpName]);
if ~exist(tmpName, 'file')
    error(['Unable to download filter file ' model '.txt from the DAQ SVN for GPS time ' num2str(gps)]);
end
cleanupFile = onCleanup(@() delete(tmpName));
filters = readFilterFile(tmpName);
filters.fileName = [model '.txt'];

%% Cleanup

clear cleanupFile;

end
