function handles = tikzNoisePlot(noiseModel, fileName, varargin)

parser = inputParser();
parser.KeepUnmatched = true;
parser.addParamValue('fixedFigureNumber', 0);
parser.parse(varargin{:});

plotterFactory = TikzPlotterFactory(fileName);
plotterFactory.fixedFigureNumber = parser.Results.fixedFigureNumber;
noiseModel.drilldown(@(noiseModel) plotterFactory.getPlotter(noiseModel, parser.Unmatched));
handles = plotterFactory.handles;
plotterFactory.finalize()

end