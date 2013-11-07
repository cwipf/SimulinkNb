function liveParts(mdl, start, duration)

%% Form channel list

liveParts = [find_system(mdl, 'Tag', 'LiveConstant'), ...
    find_system(mdl, 'Tag', 'LiveMatrix'), ...
    find_system(mdl, 'Tag', 'LiveFilter')];
disp([num2str(numel(liveParts)) ' LiveParts found']);

chans = cell(size(liveParts));

for n = 1:numel(liveParts)
    chans{n} = liveChans(liveParts{n});
    disp(['    ' liveParts{n} ' :: ' num2str(numel(chans{n}(:))) ' channels']);
end

%% Get data and store it in a containers.Map

chanList = {};
for n = 1:numel(chans)
    chanList = [chanList chans{n}(:)']; %#ok<AGROW>
end
chanList = unique(chanList);
disp(['Requesting ' num2str(duration) ' seconds of data for ' num2str(numel(chanList)) ...
    ' channels, starting at GPS time ' num2str(start)]);
data = get_data(chanList, 'raw', start, duration);

dataByChan = containers.Map();
for n = 1:numel(data)
    if any(diff(data(n).data) ~= 0)
        warning([data(n).name ' is not constant during the segment']);
    end
    dataByChan(data(n).name) = mean(data(n).data);
end

%% Apply params

for n = 1:numel(liveParts)
    liveParams(liveParts{n}, chans{n}, dataByChan);
end

end

function chans = liveChans(blk)

blkType = get_param(blk, 'Tag');
blkVars = get_param(blk, 'MaskWSVariables');

switch blkType
    case 'LiveConstant'
        chans = {blkVars(strcmp({blkVars.Name}, 'chan')).Value};
        
    case 'LiveMatrix'
        prefix = blkVars(strcmp({blkVars.Name}, 'prefix')).Value;
        firstRow = blkVars(strcmp({blkVars.Name}, 'firstRow')).Value;
        firstCol = blkVars(strcmp({blkVars.Name}, 'firstCol')).Value;
        lastRow = blkVars(strcmp({blkVars.Name}, 'lastRow')).Value;
        lastCol = blkVars(strcmp({blkVars.Name}, 'lastCol')).Value;
        
        rows = firstRow:lastRow;
        cols = firstCol:lastCol;
        chans = cell(numel(rows), numel(cols));
        for row = 1:numel(rows)
            for col = 1:numel(cols)
                chans{row, col} = [prefix '_' num2str(rows(row)) '_' num2str(cols(col))];
            end
        end
end
        
end

function liveParams(blk, chans, dataByChan)

blkType = get_param(blk, 'Tag');

switch blkType
    case 'LiveConstant'
        K = dataByChan(chans{1});
        Kvar = get_param(blk, 'K');
        assignin('base', Kvar, K);

    case 'LiveMatrix'
        [rows, cols] = size(chans);
        M = zeros(rows, cols);
        
        for row = 1:rows
            for col = 1:cols
                M(row, col) = dataByChan(chans{row, col});
            end
        end
        Mvar = get_param(blk, 'M');
        assignin('base', Mvar, M);
end
        
end