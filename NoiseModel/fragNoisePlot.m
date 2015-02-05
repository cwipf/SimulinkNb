function fragNoisePlot(noiseModel, fileName, varargin)

plotterFactory = FragPlotterFactory(fileName);
noiseModel.drilldown(@(noiseModel) plotterFactory.getPlotter(noiseModel, varargin{:}));
plotterFactory.finalize()

end