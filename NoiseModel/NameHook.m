classdef NameHook
   
    properties
        name
    end
    
    methods
        function self = NameHook(name)
            self.name = name;
        end
        
        function newNoise = hook(self, noise)
            newNoise = noise;
            newNoise.name = self.name;
        end
    end
    
end

