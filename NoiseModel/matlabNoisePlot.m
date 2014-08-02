function matlabNoisePlot(noiseModel)
       
     plotterFactory = MatlabPlotterFactory();
     noiseModel.drilldown(@plotterFactory.getPlotter);
     
end