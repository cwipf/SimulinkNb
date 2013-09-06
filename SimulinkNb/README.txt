This directory contains a Simulink-based noise budget toolkit, and an
example based on the DARM Simulink model from the aligocalibration SVN
repository.



==============================
Getting started: example model
==============================

To run the example, go to the example/ subdirectory and use the
run_DARM_NB script.  You'll need Matlab R2010a or newer, and a recent
checkout of the SUS and aligocalibration repositories.  (The SUS SVN
is vast and not all of it is needed, but make sure to include at least
the paths listed at the top of darmParams.m.  Also, edit the paths
there, and at the top of run_DARM_NB, if your SVN directories are in a
different location.)

SVN repository URLs:
SUS -- https://redoubt.ligo-wa.caltech.edu/svn/sus
aligocalibration -- https://svn.ligo.caltech.edu/svn/aligocalibration

The script should conclude by popping up a series of noise budget and
sub-budget plots.  The following noise terms are modeled:
* ADC Noise
* ASPD Dark Noise
* BOSEM L Noise
* Laser Frequency Noise
* Laser Intensity Noise
* MICH Coupling Noise
* Oscillator Amplitude Noise
* Oscillator Phase Noise
* QUAD Actuator Noise
* Quantum Noise
* Scattered Light Ring Noise
* Squeezed Film Damping Noise

Note: not all of these terms are broken out in the plots.  Only the
leading contributors are shown.

Also note: the example is supplied only as a demo to illustrate how
the various tools can be used.  The DARM model included here has not
been gone over with a fine toothed comb, and is certainly not correct
in all particulars.  Most of the input spectra are just placeholders.
There is absolutely no warranty on the output of this example.



===============================
Getting started: your own model
===============================

To substitute frequency response data for a Simulink block in your
model:

1. Right-click the block and open its Properties.

2. Type a FlexTf configuration line at the top of the block
description field in the General tab of the Block Properties window.
This is similar to how certain CDS parts are configured in the aLIGO
RCG.  The FlexTf line should start with the identifier string
"FlexTf:".  After the ":", type a Matlab expression (variable name or
function call).  This expression, when evaluated, should yield a frd
object containing frequency response data to substitute for the block.

3. To make the substitution more obvious, it's helpful to display the
block's description as an annotation under its name.  To do this, go
the Block Annotation tab, choose the %<Description> token from the
list, and add it to the displayed annotations.

4. Use the linFlexTf function (in place of linmod or linmod2) to
linearize the model.  Note that linFlexTf has two outputs, a
linearized system with extra I/O ports for the FlexTf blocks, and a
cell array of frd objects describing the FlexTf blocks.

5. Use the linFlexTfFold function to combine the two outputs of
linFlexTf.  The output is a frd object containing the frequency
response of the linearized system.


To graphically configure a noise budget for your model:

1. Open NbLibrary.mdl and copy in a NbNoiseSink block.  Connect it in
series with the signal that you actually measure (for example,
digitized photodetector output).  Double-click the block to set the
name of the DOF you are measuring (a string).

2. Copy in a NbNoiseCal block.  Sum it in to the signal that you
"want" to measure and budget the noise of (for example, test mass
displacement calibrated in meters).  Double-click the block and set
the DOF name string (which must correspond with the Sink block) and
the unit string (for example, 'displacement [m/rtHz]').

3. Copy in one or more NbNoiseSource blocks.  Sum them in throughout
the model wherever noise couples.  Double-click each block and set the
ASD of the noise source (which can be a constant or a vector).  If
desired, set one or more group strings, to name the noise source
and/or form sub-budgets.

4. Use the nbFromSimulink function to obtain the individual noise
terms and calibration TFs.

5. Use the nbGroupNoises function to organize the noise terms into a
hierarchical noise budget (NoiseModel object).

6. A NoiseModel object can be plotted using a function such as
matlabNoisePlot or fragNoisePlot from the NoiseModel distribution.



=============
File overview
=============

* linFlexTf.m, linFlexTfFold.m
linFlexTf and linFlexTfFold are functions for incorporating frequency
response data into Simulink linearizations.  These functions take the
place of linmod or linmod2, and should prove to be more robust and
accurate when frequency response data are available.  They're really
just wrappers around Matlab's linlft and linlftfold functions.  See
the help for more details.

* nbFromSimulink.m, nbGroupNoises.m, NbLibrary.mdl
These are tools for processing Simulink-based noise budgets, to
automatically identify, calibrate, and organize all the noise terms
they contain.  See the help for more details.

* lisoFrd.m, optickleFrd.m, scb.m
lisoFrd imports LISO transfer functions for use with linFlexTf.
optickleFrd is a full-fledged Optickle interface for SimulinkNB,
developed by Nicolas Smith-Lefebvre.  It automatically hooks up the
drives and probes of an Optickle object to a FlexTf block, and calls
tickle to compute the frequency response data if needed. scb is a
helper function used by linFlexTf and nbFromSimulink when they process
a block: it lets clever extension functions such as optickleFrd figure
out which block called them, and act accordingly.

* example/run_DARM_NB.m
Main script used for the example.

* example/DARM.mdl, example/darmParams.m, example/darmNbParams.m
Demo Simulink model for DARM, and functions to define its parameters
(adapted from Jeff Kissel's DARM model).  Examples of how to configure
FlexTf and NbNoiseSource blocks can be seen in the Simulink model by
drilling down into the subsystems, such as: DARM.mdl/Actuation
Function/ETMX/Hierarchy Loops/Driver Electronics

* example/DarmLentickle.mat
Lentickle model results used to supply the cavity response as a
FlexTf, and to add various noise couplings to the model.
