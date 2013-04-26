function tikzNoisePlot(noiseModel, fileName)
plotterFactory = TikzPlotterFactory(fileName);
noiseModel.drilldown(@plotterFactory.getPlotter);
plotterFactory.finalize()
end