function asd = optickleNoiseBlock(opt,f,probename)
%optickleNoiseBlock(opt,f,probename)
%   calls cacheTickle to generate quantum noise spectrum for a given probe

    [~,~,~,~,noiseAC] = cacheTickle(opt,[],f);

    asd = noiseAC(getProbeNum(opt,probename),:);

end

