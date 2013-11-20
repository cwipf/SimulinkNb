function frdOut = optickleFrd(opt,f,varargin)
    % creates a frd object from optickle object, for use in SimulinkNB
    % Syntax: optickleFrd(opt,f) 
    % or optickleFrd(opt,f,sigAC) if sigAC is precomputed
    %
    % If not called from a FlexTf block, you must add a cell array of drive
    % names and probe names. Example:
    % optickleFrd(opt,f,{'W PM'},{'W REFL I'});
    % or optickleFrd(opt,f,sigAC,{'W PM'},{'W REFL I'});

    parseBlock = 0;
    % see if we have a sigAC
    if nargin<3 || iscell(varargin{1})
        % compute from optickle
        [~,~,sigAC,~,~] = cacheTickle(opt,[],f);
        if ~isempty(varargin)
            drives = varargin{1};
            probes = varargin{2};
        else 
            parseBlock = 1;
        end
    else
        sigAC = varargin{1};
        if length(varargin)>1
            drives = varargin{2};
            probes = varargin{3};
        else
            parseBlock = 1;
        end
    end
    
    % get the drives and probes from the simulink block
    if parseBlock
        % from http://www.mathworks.com/matlabcentral/answers/12810
        h_Inports = find_system(gcbh,'FindAll','On','SearchDepth',1,'BlockType','Inport');
        drives = get(h_Inports,'Name');
        
        h_Outports = find_system(gcbh,'FindAll','On','SearchDepth',1,'BlockType','Outport');
        probes = get(h_Outports,'Name');
    end
    
    if isempty(drives) || isempty(probes)
        error('optickleFrd:missingdriveprobes','No probe or drive names provided, nor found in simulink block');
    end
    
    % if there is only one drive or probe, put in single element cell array
    if ischar(drives)
        drives = {drives};
    end
    
    if ischar(probes)
        probes = {probes};
    end
    
    % this part is to handle both optics with and without multiple drive
    % points
    driveSplit = cell(length(drives),1);
    for jj = 1:numel(drives);
        drive = drives(jj);
        
        driveSplit{jj} = split('.',drive{1});
        if numel(driveSplit{jj}) == 1
            driveSplit{jj} = [driveSplit{jj} {1}];
        end
    end
    
    driveIndex = cellfun(@(drive) getDriveNum(opt,drive{1},drive{2}),driveSplit);
    probeIndex = cellfun(@(probe) getProbeNum(opt,probe),probes);
    
    frdOut = frd(sigAC(probeIndex,driveIndex,:),f,'Units','Hz');
end

function l = split(d,s)
%L=SPLIT(S,D) splits a string S delimited by characters in D.  Meant to
%             work roughly like the PERL split function (but without any
%             regular expression support).  Internally uses STRTOK to do 
%             the splitting.  Returns a cell array of strings.
%
%Example:
%    >> split('_/', 'this_is___a_/_string/_//')
%    ans = 
%        'this'    'is'    'a'    'string'   []
%
%Written by Gerald Dalley (dalleyg@mit.edu), 2004

l = {};
while (~isempty(s))
    [t,s] = strtok(s,d);
    l = {l{:}, t};
end
end
