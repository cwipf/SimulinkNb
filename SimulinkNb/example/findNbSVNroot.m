function findNbSVNroot
%FINDNBSVNROOT tries to find NbSVNroot.m in any of its parent directories, and updates the path if found.

if exist('NbSVNroot.m', 'file') == 2
    % path is already OK
    return;
else
    parent = fileparts(mfilename('fullpath'));
    while true
        if exist([parent filesep 'Common' filesep 'Utils' filesep 'NbSVNroot.m'], 'file') == 2
            addpath([parent filesep 'Common' filesep 'Utils']);
            return;
        else
            oldParent = parent;
            parent = fileparts(parent);
            if strcmp(parent, oldParent)
                error('Couldn''t find NbSVNroot.m: please add the NbSVN''s Common/Utils folder to your MATLAB path');
            end
        end
    end
end


end