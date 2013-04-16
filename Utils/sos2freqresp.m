function H = sos2freqresp(sos, omega, fs)
%SOS2FREQRESP  Frequency response of SOS filters.
%
%   H = SOS2FREQRESP(SOS,W,FS) computes the frequency response H of the 
%   matrix of second order section coefficients at the frequencies
%   specified by the vector W. These frequencies should be real and in
%   radians/second.   FS is the sample rate in samples per second.
%
%   Example usage:
%
%     filters = readFilterFile('L1FOO.txt');
%     sos = filters.('FOO_NOTCH')(1).soscoef;
%     fs = filters.('FOO_NOTCH')(1).fs;
%     f = logspace(log10(8), log10(12), 1001);
%
%     H = sos2freqresp(sos, 2*pi*f, fs); 
%
%     subplot(2,1,1);
%     semilogx(f, db(H));
%     subplot(2,1,2);
%     semilogx(f, angle(H)*180/pi);
%
% See also FREQRESP, ZP2SOS, SOS2ZP, SOS2SS, SS2SOS

% Author: Tobin Fricke, <tfricke@ligo.caltech.edu> 2010-04-19
% Louisiana State University and Agricultural and Mechanical College

% Explanation:
%
%
%

% Validate the input
[rows, cols] = size(sos);
if ~(cols == 6),
    error('SOS matrix should have 6 columns');
end

% Do the computation
T = 1/fs;
s = 1i*omega;
z = exp(s * T);

% This should work no matter what the shape of omega.
H = ones(size(omega));

for ii=1:rows,
    b0 = sos(ii,1);
    b1 = sos(ii,2);
    b2 = sos(ii,3);
    a0 = sos(ii,4);
    a1 = sos(ii,5);
    a2 = sos(ii,6);
    
    H = H .* (b0 + b1./z + b2./z.^2) ./ (a0 + a1./z + a2./z.^2);
end

return;
