%% get all the parameters for the NB

f = logspace(1,3,1e3);

[noises, sys] = nbFromSimulink('exampleNB', f, 'dof', 'REFLI');

disp('Plotting noises')
nb = nbGroupNoises('exampleNB', noises, sys);
nb.sortModel();
matlabNoisePlot(nb);

