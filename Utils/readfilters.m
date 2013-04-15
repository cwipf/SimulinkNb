%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ------------------------------------------------------
% This was separated from DARMmodel.m on Nov 3 2009 by Keita.
% \/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [sos,gain,name] = readfilters(file,module,varargin)
% [sos,gain,name] = readfilters(file,module,filterbanks)
%
% Read foton filter definition file, and convert to
% sos, digital gain and the concatenated names of the filter banks.
%
% file: file name of the filter, e.g. 'H1LSC.txt'.
% module: name of the module, e.g. 'DARM'.
% filterbanks: array of active filter bank numbers, e.g. [0 3 4].
% 

ret = 1;
fm = [varargin{:}];
fid = fopen(file);
firstflag = 1;
mlen = length(module);

while 1
  
  tline = fgetl(fid);
  
  if ~ischar(tline), break, end

  if strncmp(tline,module,mlen)

    arr = strread(tline,'%s','delimiter',' ');
    if strcmp(arr(1),module)
      rfm = str2double(arr(2));
      if ismember(rfm,fm)
        if firstflag        
          name = arr(7);
          gain = str2double(arr(8));
          coef = str2double([arr(9) arr(10) arr(11) arr(12)]);
  	firstflag = 0;
        else
          name = strcat(name,'/',arr(7));
          gain = gain*str2double(arr(8));
          coef = [coef str2double([arr(9) arr(10) arr(11) arr(12)])];
        end
        
        nsos = str2double(arr(4));
        
        if nsos > 1
          for ksos=1:nsos-1
  	       tline = fgetl(fid);
  	       arr = strread(tline,'%s','delimiter',' ');
  	       coef = [coef str2double([arr(1) arr(2) arr(3) arr(4)])];
  	    end;
        end
      end;
    end;
  end
end
fclose(fid);
g = coef;
dim = length(g);
n2b = dim/4;
soscoef = [];

for i = 1:n2b,
   a = [1, g(1+(i-1)*4), g(2+(i-1)*4)];
   b = [1, g(3+(i-1)*4), g(4+(i-1)*4)];
   soscoef = [soscoef; b(1) b(2) b(3) a(1) a(2) a(3)];
end
sos = soscoef;
return
%%%%%%% ***************************************************************

