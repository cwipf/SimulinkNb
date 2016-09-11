%RUN_DARM_NB  Script to run the DARM NoiseBudget demo

%% Path setup

findNbSVNroot;
addpath(genpath([NbSVNroot 'Common/Utils']));

%% Load parameters, linearize the model, and extract noise terms

disp('Loading parameters for the DARM Simulink model')
darmParams;
darmNbParams;
[noises, sys] = nbFromSimulink('DARM', ifoParams.freq);

%% Make a quick NB plot

disp('Plotting noises')
nb = nbGroupNoises('DARM', noises, sys);
nb.sortModel();
matlabNoisePlot(nb);