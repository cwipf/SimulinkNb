% Noise budget test script
%
% $Id$

%% Add paths
clear all
close all
%svnDir = '/ligo/svncommon/NbSVN/aligonoisebudget/trunk/';
%addpath([svnDir 'Common/Utils/SimulinkNb'])
%addpath([svnDir 'Common/Utils/NoiseModel/'])
%addpath([svnDir 'Common/Utils/'])
%addpath(genpath([svnDir 'Dev/Utils/']))


%% Define some filters and plot expected OLTF
K = 1;
Sen = 1e3;
Filt = zpk(-2*pi*10,-2*pi*100,10);
Act = zpk([],[-2*pi*(0.1+0.995*i) -2*pi*(0.1-0.995*i)],10);
Gol = K*Sen*Filt*Act;
figure(100)
bode(Gol)
grid on

%% Define some parameters and get live parts parameters
freq = logspace(-2,2,1000);
liveModel = 'TEST_Live';
dof = 'TST';    % name of DOF to plot NB
startTime = 1189322466;   % start GPS time
durationTime = 1;
IFO = 'L1';
site = 'LLO';

% load cached outputs
loadFunctionCache()

% get live parts parameters
liveParts(liveModel, startTime, durationTime, freq)

%% Compute noises and save cache
% Compute noises
[noises, sys] = nbFromSimulink(liveModel, freq, 'dof', dof);

% save cached outputs
saveFunctionCache();

%% Make a quick NB plot
disp('Plotting noises')
nb = nbGroupNoises(liveModel, noises, sys);

% Get noise data from DAQ. Put NdNoiseSource block with DAQ channel
% specified. Put something (e.g. 1) in ASD parameter of that block.
%nb = nbAcquireData(liveModel, sys, nb, startTime, durationTime);

nb.sortModel();
matlabNoisePlot(nb);
figure(1)
ylim([1e-6,1e1])

%% plot expected curve from calculation

mag=bode((1+Gol)/(K*Filt*Sen),2*pi*freq);
loglog(freq,squeeze(mag),'g:', 'LineWidth', 3)
hold on

mag=bode(tf(1)/K/Sen,2*pi*freq);
loglog(freq,squeeze(mag),'k:', 'LineWidth', 3)

