function calibratedNoise = calibrated(noise, tf)

calibratedNoise = noise;

if ~any(strcmp('noiseHooks', properties(calibratedNoise)))
    calibratedNoise = Noise(calibratedNoise);
end

calibratedNoise.noiseHooks{end+1} = CalibrationHook(tf);

end

