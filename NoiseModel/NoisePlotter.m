classdef NoisePlotter < handle
    %NoisePlotter is a configurable plotting engine for NoiseModel
    %
    %   It maintains structures figureProperties, axesProperties, etc. for
    %   configuring the settings of each graphics object in the plot. The
    %   plot can be further customized by applying prolog and epilog
    %   functions. Individual model traces and the sum trace can be
    %   selectively included or omitted.
    %
    %   NoisePlotter objects are typically created using a PlotterFactory
    %   object.
    properties
        prolog % cell array of function handles that are called before the plot is drawn
        epilog % cell array of function handles that are called after the plot is drawn
        handles % struct of graphics handles for each component of the plot
        plotterProperties
        figureProperties
        axesProperties
        linesProperties
        legendProperties
        titleProperties
        xlabelProperties
        ylabelProperties
        skipModelNoises % boolean array specifying whether to plot each model noise trace
        skipSumNoise % boolean specifying whether to plot the sum noise trace
    end
    
    methods
        function self = NoisePlotter(noiseModel, varargin)
            %NoisePlotter object constructor
            %
            %   NoisePlotter(noiseModel) prepares to plot a NoiseModel.
            
            %% Parse arguments
            
            opt = NoisePlotter.defaultOptions(noiseModel);
            parser = inputParser();
            parser.addParamValue('prolog', opt.prolog, @iscell);
            parser.addParamValue('epilog', opt.epilog, @iscell);
            parser.addParamValue('plotterProperties', opt.plotterProperties, @isstruct);
            parser.addParamValue('figureProperties', opt.figureProperties, @isstruct);
            parser.addParamValue('axesProperties', opt.axesProperties, @isstruct);
            parser.addParamValue('linesProperties', opt.linesProperties, @isstruct);
            parser.addParamValue('legendProperties', opt.legendProperties, @isstruct);
            parser.addParamValue('titleProperties', opt.titleProperties, @isstruct);
            parser.addParamValue('xlabelProperties', opt.xlabelProperties, @isstruct);
            parser.addParamValue('ylabelProperties', opt.ylabelProperties, @isstruct);
            parser.parse(varargin{:});
            opt = parser.Results;
            
            %% Initialize object
            
            self.handles = struct();
            self.skipModelNoises = false(size(noiseModel.modelNoises));
            self.skipSumNoise = (numel(noiseModel.modelNoises) == 1);
            
            self.prolog = opt.prolog;
            self.epilog = opt.epilog;
            self.plotterProperties = opt.plotterProperties;
            self.figureProperties = opt.figureProperties;
            self.axesProperties = opt.axesProperties;
            self.linesProperties = opt.linesProperties;
            self.legendProperties = opt.legendProperties;
            self.titleProperties = opt.titleProperties;
            self.xlabelProperties = opt.xlabelProperties;
            self.ylabelProperties = opt.ylabelProperties;
            
        end
        
        function process(self, noiseModel)
            %process plots the NoiseModel
            for n = 1:numel(self.prolog)
                feval(self.prolog{n}, self, noiseModel);
            end
            
            plotArgs = self.noisefun(@(noise) {noise.f noise.asd},...
                noiseModel, 'UniformOutput', false);
            plotArgs = [plotArgs{:}];
            legendArgs = self.noisefun(@(noise) noise.name, noiseModel,...
                'UniformOutput', false);
            self.buildPlot(plotArgs, legendArgs);
            
            for n = 1:numel(self.epilog)
                feval(self.epilog{n}, self, noiseModel);
            end
        end
        
        function output = noisefun(self, functionHandle, noiseModel, varargin)
            %noisefun is a cellfun implementation that respects the skipModelNoises property
            output = cellfun(functionHandle, noiseModel.referenceNoises, varargin{:});
            if ~self.skipSumNoise
                output = [output cellfun(functionHandle, {noiseModel.sumNoise}, varargin{:})];
            end
            if isempty(self.skipModelNoises)
                self.skipModelNoises = false(size(noiseModel.modelNoises));
            end
            output = [output cellfun(functionHandle, noiseModel.modelNoises(~self.skipModelNoises), varargin{:})];
        end
        
        function buildPlot(self, plotArgs, legendArgs)
            %buildPlot generates the plot components
            if isfield(self.figureProperties, 'Number')
                % apply figure number property specially
                % (it's read-only after figure creation)
                fg = figure(self.figureProperties.Number);
                self.handles.fg = fg;
                set(fg, rmfield(self.figureProperties, 'Number'));
            else
                fg = figure();
                self.handles.fg = fg;
                set(fg, self.figureProperties);
            end
            
            ax = axes();
            self.handles.ax = ax;
            set(ax, self.axesProperties);
            
            if ~isempty(plotArgs)
                ln = plot(ax, plotArgs{:});
                self.handles.ln = ln;
                if ~iscell(self.linesProperties)
                    set(ln, self.linesProperties);
                else
                    for n = 1:numel(ln)
                        set(ln(n), self.linesProperties{n});
                    end
                end
            else
                warning('NoisePlotter:emptyplot', 'There are no noises available to plot');
                self.handles.ln = [];
            end
            
            
            if ~isempty(legendArgs)
                lg = legend(ln, legendArgs{:});
                self.handles.lg = lg;
                set(lg, self.legendProperties);
            else
                self.handles.lg = [];
            end
            
            ti = title(ax, '');
            self.handles.ti = ti;
            set(ti, self.titleProperties);
            
            xl = xlabel(ax, '');
            self.handles.xl = xl;
            set(xl, self.xlabelProperties);
            
            yl = ylabel(ax, '');
            self.handles.yl = yl;
            set(yl, self.ylabelProperties);
        end
    end
    
    methods (Static)
        function skipNegligibleNoises(self, noiseModel)
            %skipNegligibleNoises is a prolog function that omits noises contributing only a negligible amount to the sum everywhere
            epsi = self.plotterProperties.NegligibleNoiseLevel;
            for n = 1:numel(noiseModel.modelNoises)
                if ~ismethod(noiseModel.modelNoises{n}, 'drilldown') && ...
                        all(noiseModel.modelNoises{n}.asd < epsi*noiseModel.sumNoise.asd)
                    self.skipModelNoises(n) = true;
                end
            end
        end
        
        function setXLim(self, noiseModel)
            %setXLim is a prolog function that sets the x-axis limits to a sane default
            self.axesProperties.XLim = [min(noiseModel.f) max(noiseModel.f)];
        end
        
        function setYLim(self, noiseModel)
            %setYLim is a prolog function that sets the y-axis limits to a sane default
            
            % Sanity check on the noises
            nonFinite = cellfun(@(noise) ~any(isfinite(noise.asd)), noiseModel.modelNoises);
            if any(nonFinite(~self.skipModelNoises))
                warning('NoisePlotter:nonfinitenoises', 'Model noises whose ASD is nonfinite everywhere are being skipped');
                self.skipModelNoises = self.skipModelNoises | nonFinite;
            end
            allZero = cellfun(@(noise) all(noise.asd==0), noiseModel.modelNoises);
            if any(allZero(~self.skipModelNoises))
                warning('NoisePlotter:identicallyzeronoises', 'Model noises whose ASD is zero everywhere are being skipped');
                self.skipModelNoises = self.skipModelNoises | allZero;
            end
            if sum(~self.skipModelNoises) == 0
                return
            end
            
            function [maxNoise, minNoise] = maxminNoise(noise)
                asd = double(noise.asd);
                maxNoise = max(asd(isfinite(asd)));
                minNoise = min(asd(isfinite(asd)));
            end
            [modelMax, modelMin] = cellfun(@maxminNoise, noiseModel.modelNoises(~self.skipModelNoises));
            
            sumData = noiseModel.sumNoise.asd;
            sumMax = max(sumData(isfinite(sumData)));
            sumMin = min(sumData(isfinite(sumData)));
            
            minY = min([min(modelMax) sumMin]);
            maxY = max([max(modelMin) sumMax]);
            
            self.axesProperties.YLim = [10^floor(log10(minY)) 10^ceil(log10(maxY))];
        end
        
        function setLinesProperties(self, noiseModel)
            %setLinesProperties is a prolog function that styles the reference and sum traces
            countReferences = numel(noiseModel.referenceNoises);
            countSum        = ~self.skipSumNoise;
            countLines      = countReferences + countSum + sum(~self.skipModelNoises);
            
            if ~iscell(self.linesProperties)
                self.linesProperties = num2cell(repmat(self.linesProperties, countLines, 1));
            end
            
            for n = 1:(countReferences+countSum)
                self.linesProperties{n}.LineStyle = '-';
            end
            if ~self.skipSumNoise
                self.linesProperties{countReferences+countSum}.LineWidth = 4;
            end
        end
        
        function d = defaultOptions(noiseModel)
            d = struct();
            d.prolog = {@NoisePlotter.skipNegligibleNoises @NoisePlotter.setXLim @NoisePlotter.setYLim @NoisePlotter.setLinesProperties};
            d.epilog = {};
            d.plotterProperties = struct();
            d.plotterProperties.NegligibleNoiseLevel = 0;
            d.figureProperties = struct();
            d.figureProperties.DefaultTextInterpreter = 'none';
            d.axesProperties = struct();
            d.axesProperties.Box = 'on';
            d.axesProperties.XGrid = 'on';
            d.axesProperties.YGrid = 'on';
            d.axesProperties.XScale = 'log';
            d.axesProperties.YScale = 'log';
            %d.axesProperties.ColorOrder = distinguishable_colors(11);
            % precomputed color vector - avoids depending on the image
            % processing toolbox
            d.axesProperties.ColorOrder = [0 0 1; 1 0 0; 0 1 0; 0 0 0.1724; ...
                1 0.1034 0.7241; 1 0.8276 0; 0 0.3448 0; 0.5172 0.5172 1; ...
                0.6207 0.3103 0.2759; 0 1 0.7586; 0 0.5172 0.5862];
            d.axesProperties.LineStyleOrder = {'--', '-.', ':'};
            d.axesProperties.NextPlot = 'add';
            d.linesProperties = struct();
            d.linesProperties.LineWidth = 2;
            d.legendProperties = struct();
            d.legendProperties.interpreter = 'none';
            d.titleProperties = struct();
            d.titleProperties.String = noiseModel.title;
            d.xlabelProperties = struct();
            d.xlabelProperties.String = 'Frequency [Hz]';
            d.ylabelProperties = struct();
            d.ylabelProperties.String = noiseModel.unit;
        end
    end
end