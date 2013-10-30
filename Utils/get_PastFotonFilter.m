% Readout Filter Bank at any time in the past 
% Takes as arguments a particular IFO, subsystem, model, and multiple
% filter banks and returns all of the information needed to recreate those
% filter banks in a model, at a given gps time. 
% If gps time is empty then it takes data live.
%
% Inputs:
% ifo = 'L1', 'H1', or 'I1'
% model = the name of the particular model such as 'L1SUSMC2'
%       This is used to call the Foton file
% filters = the name of the requested filter banks in that model
%       such as 'MC2_M2_LOCK_L'
%       This is used to call the filter bank in the Foton file
% chans = the prefix of the epics channels associated with the filter bank
%       such as 'IMC-L'
%       This is used to call the epics channels that store the gains,
%       offsets, switch states, etc.
% gpsT = gps time at which to get the filters
%
% The inputs are converted to strings to access the foton file and the
% filter bank switches as such
% Foton file = ['/opt/rtcds/llo/l1/chans/' model '.txt']
% Foton bank = ^^^.(filters{i})
% Switches   = [ifo ':' chan '_SW1R']
% 
% Example which gets all of the damping filters for MC2:
% data = read_FilterBank('L1','L1SUSMC2',...
%       {'MC2_M1_DAMP_L','MC2_M1_DAMP_T','MC2_M1_DAMP_V',...
%        'MC2_M1_DAMP_P','MC2_M1_DAMP_R','MC2_M1_DAMP_Y'},...
%       {'SUS-MC2_M1_DAMP_L','SUS-MC2_M1_DAMP_T','SUS-MC2_M1_DAMP_V',...
%        'SUS-MC2_M1_DAMP_P','SUS-MC2_M1_DAMP_R','SUS-MC2_M1_DAMP_Y'},1067124880);



function FBstate = get_PastFotonFilter(ifo,model,filters,chans,gpsT)

if ~iscell(filters)
    filters ={ filters};
else warning('Your filter names are not cells')
    return
end

if ~iscell(chans)
    chans = {chans};
else warning('Your chan names are not cells')  
    return
end

if ~ length(chans) == length(filters)
    warning('Length of filters and length of chans should be the same')
    return
end

if gpsT < 1058799629
        warning('Too far in the past, the filter files were saved in a different format. Cannot parse.')
        return
end
for ii = 1:length(filters)
    
    filter = filters{ii};
    chan = chans{ii};

    %% Get Filter File and Store SOS Coefficients
    if ifo == 'L1'
        site = 'llo';
    elseif ifo == 'H1'
        site = 'lho';
    end
    FBstate.(filter).file.name = find_FilterFile(site,ifo,model,gpsT);
    temp.susfilt = readFilterFile(FBstate.(filter).file.name);
    
    FBstate.(filter).file.gps = gpsT;
    
    for j = 1:length(temp.susfilt.(filter))
        FBstate.(filter).filts(j).soscoef = temp.susfilt.(filter)(j).soscoef;
        FBstate.(filter).filts(j).rate = temp.susfilt.RATE.fs;
    end


    %% Get Switches and Gains

    temp.flnm = [ifo ':' chan '_'];
    % use get_data to get 0.1 sec of epics data (would be better with
    % conlog) and then pick first data point as the state
    epicschans = {[temp.flnm 'GAIN'];[temp.flnm 'OFFSET'];[temp.flnm 'SWSTAT'];[temp.flnm 'LIMIT']};
    epicschansdata = get_data(epicschans,'raw',gpsT,0.1);
    
    FBstate.(filter).gain = epicschansdata(1).data(1); % gain
    FBstate.(filter).offset.value = epicschansdata(2).data(1); % offset value
    loop.sbit = epicschansdata(3).data(1); % switches states - now in one channel in the past
    FBstate.(filter).limit.value = epicschansdata(4).data(1); % limit value

%     %% Parse Filter Switches
%     [~, b] = system(['caget -t ' temp.flnm 'SW1R']);
%     loop.sbit = str2double(b);

    FBstate.(filter).inon = ~0 & bitand(2^10,loop.sbit); % input switch = 1024
    FBstate.(filter).offset.on =  ~0 & bitand(2^11,loop.sbit); % offset switch = 2048
    FBstate.(filter).limit.on =  ~0 & bitand(2^13,loop.sbit); % limit switch = 8192
    FBstate.(filter).outon = ~0 & bitand(2^12,loop.sbit); % output switch = 4096
    for j=1:10
        loop.bit = 2^(j-1);
        FBstate.(filter).filts(j).on = ~0 & bitand(loop.bit,loop.sbit);
    end

end


end