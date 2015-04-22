# SimulinkNb - NoiseBudget toolbox for Simulink

### How to graphically configure a noise budget for your Simulink model:

1. Open SimulinkNb/NbLibrary.mdl and copy in a NbNoiseSink block.  Connect it in series with the signal that you actually measure (for example, digitized photodetector output).  Double-click the block to give a name to the DOF you are measuring (a string).

2. Copy in a NbNoiseCal block.  Sum it in to the signal that you "want" to measure and budget the noise of (for example, test mass displacement calibrated in meters).  Double-click the block and set the DOF name (which must correspond with the Sink block) and the unit string (for example, 'displacement [m/rtHz]').

3. Copy in one or more NbNoiseSource blocks.  Sum them in throughout the model wherever noise couples.  Double-click each block and set the ASD of the noise source (which can be a constant or a vector).  If desired, set one or more group strings, to name the noise source and/or form sub-budgets.

4. Use the nbFromSimulink function to obtain the individual noise terms and calibration TFs.

5. Use the nbGroupNoises function to organize the noise terms into a hierarchical noise budget (NoiseModel object).

6. Plot the noise budget using a function such as matlabNoisePlot or fragNoisePlot.
