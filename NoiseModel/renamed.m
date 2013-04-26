function renamedNoise = renamed(noise, name)

renamedNoise = noise;

if ~any(strcmp('noiseHooks', properties(renamedNoise)))
    renamedNoise = Noise(renamedNoise);
end

renamedNoise.noiseHooks{end+1} = NameHook(name);

end

