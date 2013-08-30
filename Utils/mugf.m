function mag = mugf(f,z,ugf)
% MUGF is a UGF finder
% 
% Ex:  mag = mugf(f,z,ugf)
%
% where 'f' is the frequency vector
%       'z' is the transfer function vector
%       'ugf' is the frequency at which the mag is desired
%       'mag' is the magnitude of 'z' at f=ugf

% finds the magnitude of the data 'z' on frequency vector 'f'
% at frequency 'ugf'

n = min(find(f > ugf));

mag = abs(z(n));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
