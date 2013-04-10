% Readout Filter Bank
% Takes as arguments a particular IFO, subsystem, model, and multiple
% filter banks and returns all of the information needed to recreate those
% filter banks in a model.
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
%
% The inputs are converted to strings to access the foton file and the
% filter bank switches as such
% Foton file = ['/opt/rtcds/llo/l1/chans/' model '.txt']
% Foton bank = ^^^.(filters{i})
% Switches   = [ifo ':' chan '_SW1R']
% 
% As requested by Anamaria, an example which gets all of the damping
% filters for MC2
% data = read_FilterBank('L1','L1SUSMC2','...
%       {MC2_M1_DAMP_L,MC2_M1_DAMP_T,MC2_M1_DAMP_V,...
%        MC2_M1_DAMP_P,MC2_M1_DAMP_R,MC2_M1_DAMP_Y},...
%       {SUS-MC2_M1_DAMP_L,SUS-MC2_M1_DAMP_T,SUS-MC2_M1_DAMP_V,...
%        SUS-MC2_M1_DAMP_P,SUS-MC2_M1_DAMP_R,SUS-MC2_M1_DAMP_Y});

function data = read_FilterBank(ifo,model,filters,chans)

addpath('/cvs/cds/project/mDV/extra/')

if ~iscell(filters)
    filters ={ filters};
end

if ~iscell(chans)
    chans = {chans};
end

if ~ length(chans) == length(filters)
    warning('Length of filters and length of chans should be the same')
    return
end
    

for ii = 1:length(filters)
    
    filter = filters{ii};
    chan = chans{ii};

    %% Get Filter File and Store SOS Coefficients
    data.(filter).file.name = ['/opt/rtcds/llo/l1/chans/' model '.txt'];
    temp.susfilt = readFilterFile(data.(filter).file.name);
    
    data.(filter).file.time = clock;
    data.(filter).file.gps = gps('now');
    
    for j = 1:length(temp.susfilt.(filter))
        data.(filter).filts(j).soscoef = temp.susfilt.(filter)(j).soscoef;
        data.(filter).filts(j).rate = temp.susfilt.RATE.fs;
    end


    %% Get Switches and Gains

    temp.flnm = [ifo ':' chan '_'];

    data.(filter).file.chans = {...
        [temp.flnm 'SW1R'],...
        [temp.flnm 'SW2R'],...
        [temp.flnm 'GAIN'],...
        [temp.flnm 'OFFSET']};

    %Get Data from Server
    temp.data = get_data(data.(filter).file.chans,'raw',gps('now')-10*60,0.1);
    
    %Store Gain and Offset
    data.(filter).gain = temp.data(3).data(1);
    data.(filter).offset.value = temp.data(4).data(1);




    %% Parse Filter Switches

    loop.sbit = temp.data(1).data(1);

    data.(filter).inon = ~0 & bitand(2^2,loop.sbit);
    data.(filter).offset.on =  ~0 & bitand(2^3,loop.sbit);
    for j=1:6
        loop.bit = 2^(2*(j-1)+5);
        data.(filter).filts(j).on = ~0 & bitand(loop.bit,loop.sbit);
    end

    loop.sbit = temp.data(2).data(1);
    %Output Switch
    data.(filter).outon = ~0 & bitand(2^10,loop.sbit);
    for j=7:10
        loop.bit = 2^(2*(j-7))+1;
        data.(filter).filts(j).on = ~0 & bitand(loop.bit,loop.sbit);
    end

end



    




