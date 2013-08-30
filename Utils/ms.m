function ms = ms(x,y);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%						%
%	find the ms value of y(x)		%
%	y(f) could be a spectral density	%
%	or y(t) could be a time series		%
%						%
%	usage: msY = ms(X,Y);			%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dx = diff(squeeze(x));
dx = cat(1,[dx(1)], dx);


ms = fliplr((cumsum(fliplr((squeeze(y).^2.*dx)'))));
