classdef LinkHook
   
    properties
        target
    end
    
    methods
        function self = LinkHook(target)
            self.target = target;
        end
        
        function newNoise = hook(self, noise)
            newNoise.f = noise.f;
            newNoise.asd = noise.asd;
            if strfind(self.target, 'internal:')
                newNoise.name = ['\hyperlink{' self.target '}{' noise.name '}'];
            else
                newNoise.name = ['\href{' self.target '}{' noise.name '}'];
            end
        end
    end
    
end

