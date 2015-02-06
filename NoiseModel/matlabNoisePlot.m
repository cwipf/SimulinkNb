function handles = matlabNoisePlot(noiseModel, varargin)

parser = inputParser();
parser.KeepUnmatched = true;
parser.addParamValue('fixedFigureNumber', 0);
parser.parse(varargin{:});

plotterFactory = MatlabPlotterFactory();
plotterFactory.fixedFigureNumber = parser.Results.fixedFigureNumber;
noiseModel.drilldown(@(noiseModel) plotterFactory.getPlotter(noiseModel, parser.Unmatched));
handles = plotterFactory.handles;

end