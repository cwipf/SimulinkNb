function [resgain_ss] = resgain(f0,Q,k);

% RESGAIN  state space model of a resonant filter stage, 
% described by:
%                             k*w0*s
%	T(s)  =  1  +  ----------------------
%                       s^2 + (w0/Q)s + w0^2
%
%  The constant 1 is added so that far from the resonance
%  the response is unity. The response at resonance is Q*k,
%  with the width being f0/Q.
%
%         sys = resgain(f0,Q,k)   returns a state-space
%         model of the filter, with f0 the resonant frequency
%         in Hertz (=w0/2pi).
%

w0 = 2*pi*f0;
sys = tf([1 w0*(k+Q^-1) w0^2],[1 w0/Q w0^2]);
resgain_ss = ss(sys);
