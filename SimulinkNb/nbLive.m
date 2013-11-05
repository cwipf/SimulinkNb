function nb = nbLive(mdl, sys, nb, start, duration, varargin)

if numel(varargin) == 0
    asdFromData = @(data, Fs) defaultAsdFromData(data, Fs, nb.f);
end

chanList = findChan(mdl, nb);
% conn = nds2.connection(server, port);
% buffers = conn.fetch(start, end, chanList);
data = get_data(chanList, 'raw', start, duration);


noisesByChan = containers.Map();
for n = 1:numel(data)
    asd = asdFromData(data(n).data, data(n).rate);
    noisesByChan(data.name) = asd;
end

nb = updateNoises(nb, sys, noisesByChan);

end

function asd = defaultAsdFromData(data, Fs, freq)

df = geomean(diff(freq));
NFFT = round(Fs/df);
[psd, f] = pwelch(data, hann(NFFT), NFFT/2, NFFT, Fs);
asd = interp1(f, sqrt(psd), freq);

end

function chanList = findChan(mdl, nb, varargin)

if numel(varargin) == 0
    chanList = {};
else
    chanList = varargin{1};
end

for n = 1:numel(nb.modelNoises)
    noise = nb.modelNoises{n};
    if isprop(noise, 'modelNoises')
        chanList = findChan(mdl, noise, chanList);
    else
        if isprop(noise, 'noiseData')
            noisePath = noise.noiseData.name;
        else
            noisePath = noise.name;
        end
        chan = get_param(noisePath, 'chan');
        chan = evalin('base', chan);
        if ~isempty(chan) && ~any(strcmp(chan, chanList))
            disp(['Found DAQ channel ' chan ' for source ' noisePath]);
            chanList = [chanList {chan}]; %#ok<AGROW>
        end
    end
end

end

function nb = updateNoises(nb, sys, noisesByChan)

for n = 1:numel(nb.modelNoises)
    noise = nb.modelNoises{n};
    if isprop(noise, 'modelNoises')
        noise = updateNoises(noise, sys, noisesByChan);
    else
        if isprop(noise, 'noiseData')
            noisePath = noise.noiseData.name;
        else
            noisePath = noise.name;
        end
        chan = get_param(noisePath, 'chan');
        chan = evalin('base', chan);
        if ~isempty(chan)
            disp(['Updating noise from source ' noisePath]);
            noiseTf = sys(strcmp(noisePath, sys.InputName));
            noiseAsd = noisesByChan(chan) .* abs(squeeze(freqresp(noiseTf, nb.f, 'Hz')))';
            if isprop(noise, 'noiseData')
                noise.noiseData.asd = noiseAsd;
            else
                noise.asd = noiseAsd;
            end
        end
    end
    nb.modelNoises{n} = noise;
end

end