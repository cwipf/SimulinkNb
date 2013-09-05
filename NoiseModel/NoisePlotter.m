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
        function self = NoisePlotter(noiseModel)
            %NoisePlotter object constructor
            %
            %   NoisePlotter(noiseModel) prepares to plot a NoiseModel.
            self.prolog = {@NoisePlotter.skipNegligibleNoises @NoisePlotter.setYLim @NoisePlotter.setLinesProperties};
            self.epilog = {};
            self.handles = struct();
            self.figureProperties = struct();
            self.figureProperties.DefaultTextInterpreter = 'none';
            self.axesProperties = struct();
            self.axesProperties.Box = 'on';
            self.axesProperties.XGrid = 'on';
            self.axesProperties.YGrid = 'on';
            self.axesProperties.XScale = 'log';
            self.axesProperties.YScale = 'log';
            self.axesProperties.ColorOrder = distinguishable_colors(14);
            self.axesProperties.LineStyleOrder = {'--', '-.', ':'};
            self.axesProperties.NextPlot = 'add';
            self.linesProperties = struct();
            self.linesProperties.LineWidth = 2;
            self.legendProperties = struct();
            self.titleProperties = struct();
            self.titleProperties.String = noiseModel.title;
            self.xlabelProperties = struct();
            self.xlabelProperties.String = 'frequency [Hz]';
            self.ylabelProperties = struct();
            self.ylabelProperties.String = noiseModel.unit;
            self.skipModelNoises = false(size(noiseModel.modelNoises));
            self.skipSumNoise = (numel(noiseModel.modelNoises) == 1);
        end
        
        function process(self, noiseModel)
            %process plots the NoiseModel
            for n = 1:numel(self.prolog)
                feval(self.prolog{n}, self, noiseModel);
            end
            
            plotArgs = self.noisefun(@(noise) {noise.f noise.asd}, noiseModel, 'UniformOutput', false);
            plotArgs = [plotArgs{:}];
            legendArgs = self.noisefun(@(noise) noise.name, noiseModel, 'UniformOutput', false);
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
            fg = figure();
            self.handles.fg = fg;
            set(fg, self.figureProperties);
            
            ax = axes();
            self.handles.ax = ax;
            set(ax, self.axesProperties);

            ln = plot(ax, plotArgs{:});
            self.handles.ln = ln;
            if numel(self.linesProperties) == 1
                set(ln, self.linesProperties);
            else
                for n = 1:numel(ln)
                    set(ln(n), self.linesProperties{n});
                end
            end

            lg = legend(ln, legendArgs{:});
            self.handles.lg = lg;
            set(lg, self.legendProperties);
            
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
            %skipNegligibleNoises is a prolog function that omits noises contributing less than 10% to the sum everywhere
            for n = 1:numel(noiseModel.modelNoises)
                if ~ismethod(noiseModel.modelNoises{n}, 'drilldown') && all(noiseModel.modelNoises{n}.asd < 0.1*noiseModel.sumNoise.asd)
                    self.skipModelNoises(n) = true;
                end
            end
        end
        
        function setYLim(self, noiseModel)
            %setYLim is a prolog function that sets the y-axis limits to a sane default
            function [maxNoise, minNoise] = maxminNoise(noise)
                asd = noise.asd;
                maxNoise = max(asd(isfinite(asd)));
                minNoise = min(asd(isfinite(asd)));
            end
            [modelMax, modelMin] = cellfun(@maxminNoise, noiseModel.modelNoises(~self.skipModelNoises));
            
            sumData = noiseModel.sumNoise.asd;
            sumMax = max(sumData(isfinite(sumData)));
            sumMin = min(sumData(isfinite(sumData)));
            
            minY = min([min(modelMax) sumMin]);
            maxY = max([max(modelMin) sumMax]);
            
            %%% FIXMEEE
            if minY==0 && maxY==0
                minY = .1;
                maxY = 1;
                warning('NoisePlotter:plottingzero','You are plotting zero')
            end
            
            self.axesProperties.YLim = [10^floor(log10(minY)) 10^ceil(log10(maxY))];
        end
        
        function setLinesProperties(self, noiseModel)
            %setLinesProperties is a prolog function that styles the reference and sum traces
            countReferences = numel(noiseModel.referenceNoises);
            countSum = ~self.skipSumNoise;
            countLines = countReferences + countSum + sum(~self.skipModelNoises);
            
            if numel(self.linesProperties) == 1
                self.linesProperties = num2cell(repmat(self.linesProperties, countLines, 1));
            end
            
            for n = 1:(countReferences+countSum)
                self.linesProperties{n}.LineStyle = '-';
            end
            if ~self.skipSumNoise
                self.linesProperties{countReferences+countSum}.LineWidth = 4;
            end
        end
    end
    
end