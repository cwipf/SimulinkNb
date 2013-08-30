function mybodeplot(z, varargin)

% Makes a nice Bode Plot from a frequency vector 'f'
% and a vector 'z' of complex numbers
%
% Syntax: mybodeplot(f,z,TitleString)
%

% Turns off warning for stuff
warning off

deg = 180/pi;
twoplots = 0;
cmplot = 0;

if nargin > 3
  
  sprintf('%s','ERROR: Too many arguments')
  
elseif nargin == 1

    x = z(:,1);
    y = z(:,2);
  
    if min(size(z)) == 4
      ym = z(:,3);
      ya = z(:,4);
      cmplot = 1;
    elseif min(size(z)) ~= 2
    
      sprintf('%s','ERROR: Invalid array size')
    
    end
  
elseif nargin == 2
    
    x = z;
    y = varargin{1};
    
elseif nargin == 3
  
    z1 = z;
    z2 = varargin{1};
    
    fminn = min([min(z1(:,1)) min(z2(:,1))]);
    fmax = max([max(z1(:,1)) max(z2(:,1))]);
    
    madmax = max([max(20*log10(abs(z1(:,2)))) max(20*log10(abs(z2(:,2))))]);
    madmin = min([min(20*log10(abs(z1(:,2)))) min(20*log10(abs(z2(:,2))))]);
    twoplots = 1;
    
    if strcmp(varargin{2},'c')
      
      fminn = 9;
      fmax = 10000;
      madmax = 80;
      madmin = -40;
    end
    
end


if twoplots
  
  
  top = subplot('Position',[0.13,0.52,0.82,0.4]);
  semilogx(z1(:,1),20*log10(abs(z1(:,2))),'k',...
           z2(:,1),20*log10(abs(z2(:,2))),'r'); 
  set(top,'XTickLabel',[]);
  set(top,'GridLineStyle','--');
  axis([fminn fmax madmin madmax]);
  grid on
  ylabel('Mag (dB)');


  bottom = subplot('Position',[0.13,0.1,0.82,0.4]);
  
  semilogx(z1(:,1), angle(z1(:,2))*deg,'k',...
           z2(:,1), angle(z2(:,2))*deg,'r');
  set(bottom,'YTick',[-180:45:180]);
  axis([fminn fmax -180 180]);
  grid on
  set(bottom,'GridLineStyle','--');
  xlabel('Frequency (Hz)');
  ylabel('Phase (deg)');


elseif cmplot
  
  fminn = 10^(floor(log10(min(x)))) * 0.9;
  fmax = 10^(ceil(log10(max(x))))*1.1;
  
  mmin = -20;
  mmax = 160;
  
  top = subplot('Position',[0.13,0.52,0.82,0.4]);
  semilogx(x, 20*log10(abs(ym)),'b',...
           x, 20*log10(abs(ya)),'r',...
           x, 20*log10(abs(y)),'k')
  grid on
  axis([10^fminn 10^fmax mmin mmax])
  set(top,'XTickLabel',[]);
  set(top,'GridLineStyle','--');
  ylabel('Magnitude (dB)')
  title('Common Mode Servo')
  legend('MC\_L','AO','Total')


  bottom = subplot('Position',[0.13,0.1,0.82,0.4]);
  semilogx(x, deg * angle(ym),'b',...
           x, deg * angle(ya),'r',...
           x, deg * angle(y),'k')
  grid on
  axis([10^fminn 10^fmax -180 180])
  set(bottom,'YTick',[-180:45:180]);
  set(bottom,'GridLineStyle','--');
  xlabel('Frequency (Hz)')
  ylabel('Phase (deg)')

  
else
  
top = subplot('Position',[0.13,0.52,0.82,0.4]);

semilogx(x,20*log10(abs(y)));
set(top,'XTickLabel',[]);
set(top,'GridLineStyle','--');
axis tight;
xlim([min(x) max(x)])
grid
ylabel('Mag (dB)');


bottom = subplot('Position',[0.13,0.1,0.82,0.4]);

semilogx(x, angle(y)*deg);

set(bottom,'YTick',[-180:45:180]);
axis([min(x) max(x) -180 180]);
grid
set(bottom,'GridLineStyle','--');
xlabel('Frequency (Hz)');
ylabel('Phase (deg)');
end

warning on

return

