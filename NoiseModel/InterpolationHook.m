classdef InterpolationHook
    
    properties
        f
    end
    
    methods
        function self = InterpolationHook(f)
            self.f = f;
        end
        
        function newNoise = hook(self, noise)
            newNoise.name = noise.name;
            newNoise.f = self.f;
            newNoise.asd = interp1(noise.f, noise.asd, newNoise.f);
        end
    end
    
end

