function tikzNoisePlot(noiseModel, fileName, varargin)

plotterFactory = TikzPlotterFactory(fileName);
noiseModel.drilldown(@(noiseModel) plotterFactory.getPlotter(noiseModel, varargin{:}));
plotterFactory.finalize()

end