function varargout = mybode(varargin)

% MYBODE    Makes a nice Bode Plot 
% 
% Same syntax as the builtin 'bode' function otherwise
%
% Syntax: mybode(z1, z2, z3, 2*pi*f)
%

% Turns off warning for stuff
warning off

global phandles

deg = 180/pi;

if nargin < 2
   error('Not enough arguments')
end

nozs = nargin - 1;

f = varargin{nargin} / 2 / pi;

zs = [];

for kk=1:nozs
  
  bb = mybodesys(varargin{kk},f);
  
  szs = size(bb);
  
  if szs(2) > 1
    bb = bb.';
  end
  
  zs(:,kk) = bb;
  
end


top = subplot('Position',[0.13,0.52,0.82,0.4]);

plotstring = 'semilogx(f, 20 * log10(abs(zs(:,1)))';
for kk = 2:nozs
    plotstring = [ plotstring ', ' 'f, 20 * log10(abs(zs(:,' num2str(kk) ')))'];
end
plotstring = ...
    [plotstring ', ''LineWidth'', 2.0);']
eval(plotstring);


% ----------- STYLE MATRIX ------------------%
styles = {[1.0   0.0   0.0], '-', 3.0;              
          [0.0   0.8   0.0], '-', 2.0;              
          [0.0   0.0   1.0], '-', 2.0;              
          [0.0   0.0   0.0], '--',2.0;              
          [0.7   0.7   0.0], '-', 2.0;              
          [0.7   0.0   0.8], '-', 2.0;              
          [1.0   0.6   0.0], '--',2.0;              
          [0.6   0.4   0.3], '-', 2.0;              
          [1.0   0.4   0.7], '--',2.0;              
          [1.0   1.0   0.0], '--',2.0;              
          [0.5   0.4   0.2], '--',1.0;              
          [0.7   0.7   0.2], '--',1.0;              
          [0.0   1.0   1.0], '--',1.0;              
          [0.3   0.0   0.8], '--',1.0;              
          [0.5   0.5   0.5], '-', 1.0;              
          [1.0   1.0   0.0], '-', 1.0;              
          [0.9  0.67   1.0], '-', 1.0;              
          [0.0   1.0   0.0], '--', 1;               
          [0.3   0.0   0.3], '-.', 3};        
% -------------------------------------------%

ourlines = findobj(top,'Type','line');
ourlines = flipud(ourlines);  %resort the matrix cuz its backwards
props = {'Color','LineStyle','LineWidth'};
set(ourlines, props, styles(1:nozs,:))


% Prettification of the plot
ylabel('Mag [dB]',...
       'FontWeight','normal',...
       'Color','black','FontSize',18)


set(top,'XTickLabel',[]);
set(top,'GridLineStyle','--');
axis tight;
axis([min(f) max(f) -30 80])
grid



bottom = subplot('Position',[0.13,0.1,0.82,0.4]);

plotstring = 'semilogx(f, deg * angle((zs(:,1)))';
for kk = 2:nozs
    plotstring = [ plotstring ', ' 'f, deg * angle(zs(:,' num2str(kk) '))'];
end
plotstring = ...
    [plotstring ', ''LineWidth'', 2.0);'];
eval(plotstring);

ourlines = findobj(bottom,'Type','line');
ourlines = flipud(ourlines);  %resort the matrix cuz its backwards
props = {'Color'; 'LineStyle'; 'LineWidth'};
set(ourlines, props, styles(1:nozs,:))

set(bottom,'YTick',[-180:45:180]);
axis([-Inf Inf -180 180]);
grid
set(bottom,'GridLineStyle','--');
ylabel('Phase [deg]',...
       'FontWeight','normal',...
       'Color','black','FontSize',18)       
xlabel('Frequency [Hz]',...
       'FontWeight','normal',...
       'Color','black','FontSize',18)

warning on

if nargout > 1
  varargout{1} = abs(zs);
  varargout{2} = angle(zs);
  if nargout > 2
    varargout{3} = [top bottom];
    if nargout > 3
      error('Too many output arguments: Max=3');
    end
  end
end

  
