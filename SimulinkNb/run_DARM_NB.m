%RUN_DARM_NB  Script to run the DARM NoiseBudget demo

%% Path setup

svnDir.anb = '/ligo/svncommon/40mSVN/trunk/NB/aLIGO/';
addpath(genpath([svnDir.anb 'Dev/MatlabTools']));
clear svnDir

%% Load parameters, linearize the model, and extract noise terms

disp('Loading parameters for the DARM Simulink model')
darmParams;
darmNbParams;
[noises, sys] = nbFromSimulink('DARM', ifoParams.freq);

%% Make a quick NB plot

disp('Plotting noises')
nb = nbGroupNoises('DARM', noises);
nb.sortModel();
matlabNoisePlot(nb);