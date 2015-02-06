classdef TikzPlotterFactory < handle
    
    properties
        fixedFigureNumber = 0;
        handles = {}
        fileName
        fileID
    end
    
    methods
        function self = TikzPlotterFactory(fileName)
            self.fileName = fileName;
            self.fileID = fopen(fileName, 'w');
            header = {'\documentclass{article}'...
                '\usepackage{tikz,amsmath,siunitx,pgfplots}'...
                '\usetikzlibrary{plotmarks}'...
                '\pgfplotsset{compat=newest}'...
                '\pgfplotsset{plot coordinates/math parser=false}'...
                '\usepackage[graphics,tightpage,active]{preview}'...
                '\PreviewEnvironment{tikzpicture}'...
                '\PreviewEnvironment{equation}'...
                '\PreviewEnvironment{equation*}'...
                '\newlength{\figurewidth}'...
                '\newlength{\figureheight}'...
                '\pagestyle{empty}'...
                '\thispagestyle{empty}'...
                '\usepackage{hyperref}'...
                '\begin{document}'...
                '\setlength{\figurewidth}{6in}'...
                '\setlength{\figureheight}{4in}'};
            for n = 1:numel(header)
                fwrite(self.fileID, header{n});
                fprintf(self.fileID, '\n');
            end
        end
        
        function plotter = getPlotter(self, noiseModel, varargin)
            plotter = NoisePlotter(noiseModel, varargin{:});
            plotter.prolog{end+1} = @self.setFigureNumber;
            plotter.epilog{end+1} = @self.tikzOutput;
            plotter.epilog{end+1} = @self.harvestHandles;
        end
        
        function setFigureNumber(self, noisePlotter, ~)
            if self.fixedFigureNumber
                noisePlotter.figureProperties.Number = self.fixedFigureNumber;
                self.fixedFigureNumber = self.fixedFigureNumber + 1;
            end
        end
        
        function harvestHandles(self, noisePlotter, ~)
            self.handles{end+1} = noisePlotter.handles;
        end
        
        function tikzOutput(self, noisePlotter, ~)
            matlab2tikz([], 'filehandle', self.fileID, 'figurehandle', noisePlotter.handles.fg, 'parseStrings', false, 'width', '\figurewidth', 'height', '\figureheight', 'showInfo', false, 'checkForUpdates', false);
            fprintf(self.fileID, '\n');
            fwrite(self.fileID, '\newpage');
            fprintf(self.fileID, '\n');
            close(noisePlotter.handles.fg);
        end
        
        function finalize(self)
            fwrite(self.fileID, '\end{document}');
            fprintf(self.fileID, '\n');
            fclose(self.fileID);
        end
        
        function render(self)
            system(['pdflatex ' self.fileName]);
        end
        
        function cleanup(self)
            [pathStr, name, ~] = fileparts(self.fileName);
            delete(fullfile(pathStr, [name '.log']));
            delete(fullfile(pathStr, [name '.aux']));
            delete(fullfile(pathStr, [name '.out']));
        end
    end
    
end

