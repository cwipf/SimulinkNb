function fragNoisePlot(noiseModel, fileName)
plotterFactory = FragPlotterFactory(fileName);
noiseModel.drilldown(@plotterFactory.getPlotter);
plotterFactory.finalize()
end