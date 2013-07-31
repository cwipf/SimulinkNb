classdef NoiseModel < handle
    %NoiseModel holds a hierarchical collection of noises.
    %
    %   Each component noise is a struct or object that defines fields 'f'
    %   (frequency vector), 'asd' (amplitude spectral density data), and
    %   'name' (label used for plotting). Note that a NoiseModel itself can
    %   act as a noise object -- so that NoiseModels can be composed of
    %   other NoiseModels. This allows the class to represent a
    %   hierarchical drill-down noise budget.
    
    properties
        modelNoises % cell array of noise terms that make up the NoiseModel
        referenceNoises % cell array of noises that can be plotted alongside the model
        getNoise % function handle that returns the NoiseModel's noise object
        noiseHooks % cell array of hook objects, providing extensibility for the NoiseModel's noise object (see also the Noise class)
        unit % label for the y axis in a noise budget plot
        title % title for a noise budget plot
        drilldownSkip % boolean that sets whether drilldown should process noises below this NoiseModel
        drilldownProlog % cell array of function handles, providing extensibility for drilldown
    end
    
    properties (Dependent)
        f % frequency vector
        asd % amplitude spectral density data
        name % label used for plotting
        sumNoise % quadrature sum of modelNoises
    end
    
    properties (Access = private)
        linked % boolean that records whether drilldown's link step has been performed already
    end
    
    methods
        function self = NoiseModel(modelNoises, varargin)
            %NoiseModel object constructor
            %
            %   NoiseModel(modelNoises) sets the modelNoises property.
            %   NoiseModel(modelNoises, referenceNoises) sets the referenceNoises property as well.
            
            % input sanity check
            if ~iscell(modelNoises)
                error('First argument to NoiseModel should be a 1xN cell array of noises');
            end
            sz = size(modelNoises);
            if length(sz) ~= 2 || min(sz) > 1
                error('First argument to NoiseModel should be a 1xN cell array of noises');
            elseif sz(1) ~= 1
                warning('First argument to NoiseModel should be a 1xN cell array of noises');
                modelNoises = modelNoises';
            end
            
            
            self.modelNoises = modelNoises;
            self.referenceNoises = {};
            self.getNoise = @(self) self.sumNoise;
            self.noiseHooks = {};
            self.unit = '';
            self.title = '';
            self.drilldownSkip = false;
            self.drilldownProlog = {};
            self.linked = false;

            if numel(varargin) > 0
                self.referenceNoises = varargin{1};
            end
            if numel(varargin) > 1
                self.getNoise = varargin{2};
            end
        end
        
        % the following methods implement the properties sumNoise, f, asd, and name
        function sumNoise = get.sumNoise(self)
            sumNoise = incoherentSum(self.modelNoises);
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
        
        function sortModel(self, varargin)
            %sortModel sorts the modelNoises.
            %
            %   sortModel() sorts using a default weight function.
            %   sortModel(weightFunction) calls the specified weight
            %   function handle as weightFunction(f, asd, asdSum) on each
            %   noise, to determine its weight relative to the sumNoise.
            weightFunction = @(f, asd, asdSum) trapz(log10(f), (asd./asdSum).^2);
            if numel(varargin) > 0
                weightFunction = varargin{1};
            end
            
            weight = cellfun(@(noise) weightFunction(noise.f, noise.asd, self.sumNoise.asd), self.modelNoises);
            [~, sortNoises] = sort(weight, 'descend');
            self.modelNoises = self.modelNoises(sortNoises);
        end

        function drilldown(self, action, varargin)
            %drilldown traverses the NoiseModel tree (breadth first), performing an action.
            %
            %   drilldown(ACTION) specifies the action to be performed.
            %   ACTION is a class constructor handle that is called for
            %   each NoiseModel, passing the NoiseModel as an argument.
            %   Then the NoiseModel's drilldownHooks are called on the
            %   resulting object, and finally the 'process' method of the
            %   object is invoked on the NoiseModel.
            %
            %   The NoiseModel's property 'drilldownSkip' can be set to
            %   control the traversal.
            persistent serialNumber
            if numel(varargin) > 0
                serialNumber = varargin{1};
            elseif isempty(serialNumber)
                serialNumber = 1;
            end
            
            queue = {self};
            while ~isempty(queue)
                this = queue{1};
                queue = queue(2:end);
                if ~this.drilldownSkip
                    for n = 1:numel(this.modelNoises)
                        if any(strcmp('drilldownSkip', properties(this.modelNoises{n})))
                            queue{end+1} = this.modelNoises{n}; %#ok<AGROW>
                            if ~this.linked
                                this.modelNoises{n}.noiseHooks{end+1} = LinkHook(['internal:' num2str(serialNumber + numel(queue))]);
                            end
                        end
                    end
                end
                
                if ~this.linked
                    this.title = ['\hypertarget{internal:' num2str(serialNumber) '}{' this.title '}'];
                end
                this.linked = true;
                serialNumber = serialNumber + 1;
                
                worker = feval(action, this);
                for n = 1:numel(this.drilldownProlog)
                    worker = feval(this.drilldownProlog{n}, worker);
                end
                worker.process(this);
            end
        end
    end
    
end

