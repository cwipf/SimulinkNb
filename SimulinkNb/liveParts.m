function liveParts(mdl, start, duration, freq)

%% Form channel list
load_system(mdl);
liveParts = findInSystemOrRefs(mdl, 'RegExp', 'on', 'Tag', '(LiveConstant|LiveMatrix|LiveFilter)');
disp([num2str(numel(liveParts)) ' LiveParts found']);

for n = 1:numel(liveParts)
    % The set_param is a workaround for blocks that fail to initialize
    % their mask workspace
    % http://www.mathworks.com/matlabcentral/newsreader/view_thread/77043
    try
        set_param(liveParts{n}, 'Mask', 'on');
    catch err
        % Ignore set_param failures that occur for blocks inside libraries
        % that aren't designated as modifiable (they seem to initialize ok)
        if ~strcmp(err.identifier, 'Simulink:Libraries:RefViolation')
            rethrow(err);
        end
    end
    chans{n} = liveChans(liveParts{n}); %#ok<AGROW>
    disp(['    ' liveParts{n} ' :: ' num2str(numel(chans{n}(:))) ' channels']);
end

%% Get data and store it in a containers.Map

chanList = {};
for n = 1:numel(chans)
    chanList = [chanList chans{n}(:)']; %#ok<AGROW>
end

chanList = sort(unique(chanList));

%% Read data

data = cacheFunction(@getGWData, chanList, start, duration);

dataByChan = containers.Map();
for n = 1:numel(data)
    if any(diff(data(n).data) ~= 0)
        warning([data(n).name ' is not constant during the segment']);
    end
    dataByChan(data(n).name) = mode(double(data(n).data));
end

% Validate the results
for n = 1:numel(chanList)
    if ~isKey(dataByChan, chanList{n})
        error(['No data found for channel ' chanList{n}]);
    elseif isnan(dataByChan(chanList{n}))
        error(['NaN value returned for channel ' chanList{n}]);
    end
end

%% Apply params

filterCache = containers.Map();
for n = 1:numel(liveParts)
    filterCache = liveParams(liveParts{n}, chans{n}, dataByChan, start, duration, freq, filterCache);
end

end

function chans = liveChans(blk)

blkType = get_param(blk, 'Tag');
blkVars = get_param(blk, 'MaskWSVariables');

switch blkType
    case 'LiveConstant'
        chans = {blkVars(strcmp({blkVars.Name}, 'chan')).Value};
        if ~numel(chans{1})
            error(['Channel not set for blk ' blk]);
        end
        
    case 'LiveMatrix'
        prefix = blkVars(strcmp({blkVars.Name}, 'prefix')).Value;
        if ~numel(prefix)
            error(['Prefix not set for blk ' blk]);
        end
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

    case 'LiveFilter'
        prefix = blkVars(strcmp({blkVars.Name}, 'prefix')).Value;
        if ~numel(prefix)
            error(['Prefix not set for blk ' blk]);
        end
        % note: the liveParams function below depends on the ordering of these suffixes
        fmChanSuffixes = {'_SWSTAT', '_OFFSET', '_GAIN', '_LIMIT'};
        % sad workaround for 40m IFO which doesn't have SWSTAT channels
        if strncmp(prefix, 'C1:', 3)
            fmChanSuffixes = {'_SW1R', '_OFFSET', '_GAIN', '_LIMIT', '_SW2R'};
        end
        chans = cell(size(fmChanSuffixes));
        for n = 1:numel(fmChanSuffixes)
            chans{n} = [prefix fmChanSuffixes{n}];
        end
        
end
        
end

function filterCache = liveParams(blk, chans, dataByChan, start, duration, freq, filterCache)

blkType = get_param(blk, 'Tag');
blkVars = get_param(blk, 'MaskWSVariables');

switch blkType
    case 'LiveConstant'
        K = dataByChan(chans{1});
        kVar = resolveLibraryParam(get_param(blk, 'K'), blk);
        assignInBase(kVar, K);

    case 'LiveMatrix'
        [rows, cols] = size(chans);
        M = zeros(rows, cols);
        
        for row = 1:rows
            for col = 1:cols
                M(row, col) = dataByChan(chans{row, col});
            end
        end
        mVar = resolveLibraryParam(get_param(blk, 'M'), blk);
        assignInBase(mVar, M);

    case 'LiveFilter'
        site = blkVars(strcmp({blkVars.Name}, 'site')).Value;
        model = blkVars(strcmp({blkVars.Name}, 'feModel')).Value;
        fmName = blkVars(strcmp({blkVars.Name}, 'fmName')).Value;
        flexTf = blkVars(strcmp({blkVars.Name}, 'flexTf')).Value;
        par.swstat = dataByChan(chans{1});
        % sad workaround for 40m IFO which doesn't have SWSTAT channels
        if strncmp(model, 'C1', 2)
            sw1r = dataByChan(chans{1});
            sw2r = dataByChan(chans{5});
            par.swstat = 2^10*bitget(sw1r, 2+1) ... % input switch
                + 2^11*bitget(sw1r, 3+1) ... % offset switch
                ... % FM1-6 switches
                + 2^0*bitget(sw1r, 5+1) + 2^1*bitget(sw1r, 7+1) ...
                + 2^2*bitget(sw1r, 9+1) + 2^3*bitget(sw1r, 11+1) ...
                + 2^4*bitget(sw1r, 13+1) + bitget(sw1r, 15+1) ...
                ... % FM7-10 switches
                + 2^6*bitget(sw2r, 1+1) + 2^7*bitget(sw2r, 3+1) ...
                + 2^8*bitget(sw2r, 5+1) + 2^9*bitget(sw2r, 7+1) ...
                + 2^13*bitget(sw2r, 2^8+1) ... % limit switch
                + 2^12*bitget(sw2r, 10+1); % output switch
        end
        par.offset = dataByChan(chans{2});
        par.gain = dataByChan(chans{3});
        par.limit = dataByChan(chans{4});
        if ~isKey(filterCache, model)
            % Cache all filters from each file.  This speeds up subsequent
            % reads of other filters from the same file.
            if exist(['/opt/rtcds/' site '/' lower(model(1:2)) '/chans/filter_archive'], 'dir')
                % read filter archive on control room workstations
                ff = find_FilterFile(site, model(1:2), model, start);
                ff2 = find_FilterFile(site, model(1:2), model, start + duration);
                if ~strcmp(ff, ff2)
                    warning([model '.txt is not constant during the segment']);
                end
                filters = readFilterFile(ff);
            else
                % read DAQ SVN from offsite
                [filters, gpsWhenLoaded] = cacheFunction(@downloadFilterFile, model, start + duration);
                if gpsWhenLoaded > start
                    warning([model '.txt is not constant during the segment']);
                end
            end
            filterCache(model) = filters;
        else
            filters = filterCache(model);
        end
        par.fm = filters.(fmName);
        for n = 1:10
            [z, p, k] = sos2zp(par.fm(n).soscoef);
            par.(['fm' num2str(n)]) = d2c(zpk(z, p, k, 1/par.fm(n).fs), 'tustin');
            if flexTf
                par.(['fm' num2str(n) 'frd']) = frd(par.(['fm' num2str(n)]), freq, 'Units', 'Hz');
            end
        end
        parVar = resolveLibraryParam(get_param(blk, 'par'), blk);
        assignInBase(parVar, par);
end

end
