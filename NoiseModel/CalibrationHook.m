classdef CalibrationHook
   
    properties
        tf
    end
    
    methods
        function self = CalibrationHook(tf)
            self.tf = tf;
        end
        
        function newNoise = hook(self, noise)
            newNoise = noise;
            newNoise.asd = newNoise.asd .* abs(self.tf.tf);
        end
    end
    
end

