classdef Noise
   
    properties
        noiseData
        getNoise
        noiseHooks
    end
    
    properties (Dependent)
        f
        asd
        name
    end
    
    methods
        function self = Noise(noiseData)
            self.noiseData = noiseData;
            self.getNoise = @(self) self.noiseData;
            self.noiseHooks = {};
        end
        
        function f = get.f(self)
            noise = self.getNoise(self);
            for n = 1:numel(self.noiseHooks)
                noise = self.noiseHooks{n}.hook(noise);
            end
            f = noise.f;
        end
        
        function asd = get.asd(self)
            noise = self.getNoise(self);
            for n = 1:numel(self.noiseHooks)
                noise = self.noiseHooks{n}.hook(noise);
            end
            asd = noise.asd;
        end
        
        function name = get.name(self)
            noise = self.getNoise(self);
            for n = 1:numel(self.noiseHooks)
                noise = self.noiseHooks{n}.hook(noise);
            end
            name = noise.name;
        end
    end
    
end

