function driveIndex = makeOptickleDriveIndex(opt,drives)
    driveSplit = cell(length(drives),1);
    for jj = 1:numel(drives);
        drive = drives(jj);
        
        driveSplit{jj} = split('.',drive{1});
        if numel(driveSplit{jj}) == 1
            driveSplit{jj} = [driveSplit{jj} {1}];
        end
    end
    
    driveIndex = cellfun(@(drive) getDriveNum(opt,drive{1},drive{2}),driveSplit);

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