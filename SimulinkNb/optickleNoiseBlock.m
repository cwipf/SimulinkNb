function asd = optickleNoiseBlock(opt,f,probename,driveIndex)
%optickleNoiseBlock(opt,f,probename)
%   calls cacheTickle to generate quantum noise spectrum for a given probe

    if nargin < 4
        [~,~,~,~,noiseAC] = cacheFunction(@tickle,opt,[],f);
    else
        [~,~,~,~,noiseAC] = cacheFunction(@tickle,opt,[],f,driveIndex);
    end
    
    asd = noiseAC(getProbeNum(opt,probename),:);

end

