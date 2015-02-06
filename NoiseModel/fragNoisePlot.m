function handles = fragNoisePlot(noiseModel, fileName, varargin)

parser = inputParser();
parser.KeepUnmatched = true;
parser.addParamValue('fixedFigureNumber', 0);
parser.parse(varargin{:});

plotterFactory = FragPlotterFactory(fileName);
noiseModel.drilldown(@(noiseModel) plotterFactory.getPlotter(noiseModel, parser.Unmatched));
handles = plotterFactory.handles;
plotterFactory.finalize()

end