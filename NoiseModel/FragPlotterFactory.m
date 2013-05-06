classdef FragPlotterFactory < handle
    
    properties
        fileName
        fileID
        figNum
    end
    
    methods
        function self = FragPlotterFactory(fileName)
            self.fileName = fileName;
            self.fileID = fopen(fileName, 'w');
            self.figNum = 1;
            header = {'\documentclass{article}'...
                '\usepackage{pgf}'...
                '\usepackage[graphics,tightpage,active]{preview}'...
                '\PreviewEnvironment{pgfpicture}'...
                '\pagestyle{empty}'...
                '\thispagestyle{empty}'...
                '\usepackage{color}'...
                '\usepackage{hyperref}'...
                '\providecommand\matlabtextA{\color[rgb]{0.000,0.000,0.000}\fontsize{10}{10}\selectfont\strut}%'...
                '\def\matlabfragNegXTick{\mathord{\makebox[0pt][r]{$-$}}}'...
                '\begin{document}'};
            for n = 1:numel(header)
                fwrite(self.fileID, header{n});
                fprintf(self.fileID, '\n');
            end
        end
        function plotter = getPlotter(self, noiseModel)
            plotter = NoisePlotter(noiseModel);
            plotter.figureProperties.Visible = 'off';
            %plotter.axesProperties.GridLineStyle = '-';
            %plotter.axesProperties.MinorGridLineStyle = '-';
            plotter.epilog{end+1} = @self.fragLinks;
            plotter.epilog{end+1} = @self.fragOutput;
        end
        
        function fragLinks(~, noisePlotter, ~)
            % children of axes and of legend are supposed to correspond to
            % each other
            lineObjs = findobj(get(noisePlotter.handles.ax, 'Children'), 'Type', 'line');
            legendObjs = findobj(get(noisePlotter.handles.lg, 'Children'), 'Type', 'text');
            for n = 1:numel(lineObjs)
                str = get(lineObjs(n), 'DisplayName');
                fullstr = str;
                % strip href and hyperlink links (\href, \hyperlink)
                % assume no latex inside the link text
                str = regexprep(str, '\\href{[^}]*}{([^\\]*)}', '$1');
                str = regexprep(str, '\\hyperlink{[^}]*}{([^\\]*)}', '$1');
                set(lineObjs(n), 'DisplayName', str);
                if ~strcmp(fullstr, str)
                    set(legendObjs(n), 'UserData', ['matlabfrag:' fullstr]);
                end
            end
            textObjs = findobj(noisePlotter.handles.ti, 'Type', 'text');
            for n = 1:numel(textObjs)
                str = get(textObjs(n), 'String');
                fullstr = str;
                % strip hyperlink target (\hypertarget)
                % assume target wraps the entire string, and may contain
                % links inside the target text
                str = regexprep(str, '\\hypertarget{[^}]*}{(.*)}', '$1');
                % strip href and hyperlink links (\href, \hyperlink)
                % assume no latex inside the link text
                str = regexprep(str, '\\href{[^}]*}{([^\\]*)}', '$1');
                str = regexprep(str, '\\hyperlink{[^}]*}{([^\\]*)}', '$1');
                set(textObjs(n), 'String', str);
                if ~strcmp(fullstr, str)
                    set(textObjs(n), 'UserData', ['matlabfrag:' fullstr]);
                end
            end
            set(noisePlotter.handles.lg, 'Interpreter', 'latex');
        end
        
        function fragOutput(self, noisePlotter, ~)
            jarPath = [fileparts(mfilename('fullpath')) '/../eps2pgf/'];
            tmpFileName = tempname();
            matlabfrag(tmpFileName, 'handle', noisePlotter.handles.fg);
            fix_lines([tmpFileName '.eps']);
            system(['java -jar ' jarPath 'eps2pgf.jar ' tmpFileName '.eps --text-replace ' tmpFileName '.tex']);
            tmpFileID = fopen([tmpFileName '.pgf']);
            fwrite(self.fileID, fread(tmpFileID));
            fclose(tmpFileID);
            fprintf(self.fileID, '\n\\newpage\n');
            delete([tmpFileName '.eps']);
            delete([tmpFileName '.tex']);
            delete([tmpFileName '.pgf']);
            disp(['Completed figure ' num2str(self.figNum) ' titled ' get(noisePlotter.handles.ti, 'String')]);
            self.figNum = self.figNum + 1;
        end
        
        function finalize(self)
            fprintf(self.fileID, '\\end{document}\n');
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
