function matlabNoisePlot(noiseModel, varargin)

plotterFactory = MatlabPlotterFactory();
noiseModel.drilldown(@(noiseModel) plotterFactory.getPlotter(noiseModel, varargin{:}));

end