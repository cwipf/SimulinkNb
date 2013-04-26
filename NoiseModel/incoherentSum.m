function sumNoise = incoherentSum(noises, varargin)

name = 'Sum';
if numel(varargin) > 0
    name = varargin{1};
end

sumPSD = zeros(size(noises{1}.asd));
for n = 1:length(noises)
    sumPSD = sumPSD + noises{n}.asd.^2; 
end

sumNoise.f = noises{1}.f;
sumNoise.asd = sqrt(sumPSD);
sumNoise.name = name;

end