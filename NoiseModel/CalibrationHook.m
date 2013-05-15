classdef CalibrationHook
   
    properties
        tf
    end
    
    methods
        function self = CalibrationHook(tf)
            self.tf = tf;
        end
        
        function newNoise = hook(self, noise)
            newNoise.f = noise.f;
            newNoise.name = noise.name;
            newNoise.asd = noise.asd .* abs(self.tf.tf);
        end
    end
    
end

