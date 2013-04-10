%
% This script find the active filter of FM1-FM10
% and returns the total frequency response of the specific filter bank.
% 
% Keiko Kokeyama, 2012-08-08
% originally by Tobin Fricke, 2010-04-19
%
% -  Read the FOTON file using the most excellent readFilterFile 
% (from http://www.ligo.caltech.edu/~rana/mat/utilities/readFilterFile.m)
% - Checks which FMs are active
% - Calculate the total frequency response of the module
%
%
%
% input varargin :
% 1 ifo (L1 or H1), string
% 2 subsystem name (SUS, IOO ...), string
% 3 the foton file name, string
% 4 filter bank name, string
% 5 frequency vector, num vector
% 6 plot flag (true or false) to plot the total active module response
%
% output
% ModResp : frequency response of the bank module you specify (complex number)
%
%
% example
% frequency = logspace(-2, 4, 500);
% ModResp = ...
% getFilterResp('L1', 'SUS', '/opt/rtcds/llo/l1/chans/L1SUSMC2.txt', 'MC2_M3_LOCK_L', freqency, true);
%
%

function ModuResp = getFilterResp(varargin)

ifo = varargin{1};
subsystem = varargin{2};
foton = varargin{3};
bank_name = varargin{4};
freq = varargin{5};

sos = [];

%% Read the filter and state

filters = readFilterFile(foton);

cmd1 = ['[a1, b1] = system(''ezcaread -n ' [ifo] ':' [subsystem] '-' [bank_name] '_SW1R '');'];
cmd2 = ['[a2, b2] = system(''ezcaread -n ' [ifo] ':' [subsystem] '-' [bank_name] '_SW2R '');'];
eval(cmd1)
eval(cmd2)

p = ezcaswitchreport(str2num(b1),str2num(b2));


for ii=1:length(p),
    newsos = filters.(bank_name)(p(ii)).soscoef;
    sos = vertcat(sos, newsos);
end
fs = filters.(bank_name)(1).fs;

% Choose the frequencies at which we want to know the response

% Call SOS2FREQRESP
ModuResp = sos2freqresp(sos, 2*pi*freq, fs);

%% Make a Bode plot

if varargin{6} == true
H = ModuResp;
subplot(2,1,1);
semilogx(freq, db(H));
xlim([min(freq) max(freq)]);
grid on;
ylabel('gain [dB]');
title(sprintf('Bode plot of all %s active filter modules', bank_name), 'interpreter','none');

subplot(2,1,2);
semilogx(freq, angle(H)*180/pi);
xlim([min(freq) max(freq)]);
set(gca, 'YTick', 45*(-4:4));
grid on;
ylabel('phase [degrees]');
xlabel('frequency [Hz]');
end

