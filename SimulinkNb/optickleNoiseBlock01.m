function asd = optickleNoiseBlock01(opt,f,probename,driveIndex)
%optickleNoiseBlock(opt,f,probename)
%   calls cacheTickle01 to generate quantum noise spectrum for a given probe

    if nargin < 4
        [~,~,noiseAC,~] = cacheFunction(@tickle01,opt,[],f);
    else
        [~,~,noiseAC,~] = cacheFunction(@tickle01,opt,[],f,driveIndex);
    end
    
    asd = noiseAC(getProbeNum(opt,probename),:);

end

