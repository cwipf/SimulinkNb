function interpolatedNoise = interpolated(noise, f)

interpolatedNoise = noise;

if ~any(strcmp('noiseHooks', properties(interpolatedNoise)))
    interpolatedNoise = Noise(interpolatedNoise);
end

interpolatedNoise.noiseHooks{end+1} = InterpolationHook(f);

end

