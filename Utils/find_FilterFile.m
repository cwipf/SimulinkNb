% Find filter file
% Takes as arguments a particular IFO, model, and gps time
% and returns the filter file that was in effect at that time.
%
% Inputs:
% ifo = 'L1', 'H1', or 'I1'
% model = the name of the particular model such as 'L1SUSMC2'
%       This is used to locate the Foton file
% gpstime = The GPS time to use when searching for filter files
%
% The output is the name of a single filter file that matches the GPS
% time, or an empty string if a match could not be found.

function filename = find_FilterFile(site, ifo, model, gpstime)

chansDir = fullfile(filesep, 'opt', 'rtcds', lower(site), lower(ifo), 'chans');
filterArchiveDir = fullfile(chansDir, 'filter_archive', lower(model));
pattern=strcat('^', upper(model), '_(\d+)(_install)?.txt$');

files = dir(fullfile(filterArchiveDir, '*.txt'));
for file=files'
    % disp(sprintf('Checking %s', file.name))
    regexResult = regexp (file.name, pattern, 'tokens');
    if ~isempty(regexResult)
        file.gpstimestamp = str2num(regexResult{1}{1});
        if (file.gpstimestamp > gpstime)
            if (exist('bestFileMatch'))
                if (file.gpstimestamp <= bestFileMatch.gpstimestamp)
%                    disp(sprintf('Timestamp on %s is %d\n', file.name, file.gpstimestamp));
%                    filename = [filename; file.name];
                    bestFileMatch = file;
                end
            else
%                disp(sprintf('First possible match found at %d\n', file.gpstimestamp));
                bestFileMatch = file;
            end
        end
    end
end

if ~exist('bestFileMatch')
    filename=fullfile(chansDir, strcat(upper(model), '.txt'));
else
%filename = cellstr(filename);
    filename = fullfile(filterArchiveDir, bestFileMatch.name);
end