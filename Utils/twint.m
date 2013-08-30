function [twint_ss] = twint(varargin);

% twint  state space model of a twin-T notch filter with 
% positive feedback, described by:
%
%                       s^2 + w0^2
%	T(s)  =   ----------------------
%                 s^2 + (w0/Q)s + w0^2
%
%  See page 6.37 of the electronic filter design book
%
%         sys = twint(f0,Q)   returns a state-space
%         model of the filter, with f0 the resonant frequency
%         in Hertz (=w0/2pi).
%
% sys = twint(f0,Q,depth)
%                              s^2 + w0^2
%	T(s)  = Depth +  ----------------------
%                        s^2 + (w0/Q)s + w0^2
%
%


w0 = 2*pi*varargin{1};
Q = varargin{2};

if nargin == 2
  sys = tf([1 0 w0^2],[1 w0/Q w0^2]);

elseif nargin == 3
  depth = varargin{3};
  sys = tf([1 depth*w0/Q w0^2],[1 w0/Q w0^2]);
  
else
  error('Number of arguments should be 2 or 3')
  return
end


twint_ss = ss(sys);
