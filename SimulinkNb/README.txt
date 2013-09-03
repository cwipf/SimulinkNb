This directory contains a prototype Simulink-based noise budget
toolkit, and a demo that's based on the DARM Simulink model from the
aligocalibration SVN repository.

To run the demo, use the run_DARM_NB script.  You'll need Matlab
R2010a or newer, and a recent checkout of the SUS and aligocalibration
repositories.  (The SUS SVN is vast and not all of it is needed, but
make sure to include at least the paths listed at the top of
darmParams.m.  Also, edit the paths there, and at the top of
run_DARM_NB, if your SVN directories are in a different location.)

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

Also note: the demo is supplied only as an example to illustrate how
the various tools can be used.  The DARM model included here has not
been gone over with a fine toothed comb, and is certainly not correct
in all particulars.  Most of the input spectra are just placeholders.
There is absolutely no warranty on the output of this demo.

== File overview ==

* run_DARM_NB.m
Main script used for the demo.

* linFlexTf.m, linFlexTfFold.m
Functions for incorporating frequency response data into Simulink
linearizations.  These functions take the place of linmod or linmod2,
and should prove to be more robust and accurate when frequency
response data are available.  They're really just wrappers around
Matlab's linlft and linlftfold functions.  See the linFlexTf help for
more details.

* nbFromSimulink.m, nbGroupNoises.m, NbLibrary.mdl
Tools for processing Simulink-based noise budgets, to automatically
identify, calibrate, and organize all the noise terms they contain.
See the help for more details.

* DARM.mdl, darmParams.m, darmNbParams.m, lisoFrd.m
Demo Simulink model for DARM, and helper functions to define its
parameters (adapted from Jeff Kissel's DARM model).  Examples of how
to configure FlexTf and NbNoiseSource blocks can be seen in the
Simulink model by drilling down into the subsystems, such as:
DARM.mdl/Actuation Function/ETMX/Hierarchy Loops/Driver Electronics

It's meant to be easy to add such blocks to an existing model.  The
NbNoiseSource/Sink/Cal blocks can be copied in from NbLibrary.mdl.
And to convert any existing block into a FlexTf block, you right-click
on it, open its parameters, and type the FlexTf configuration line
into the block description field.  (aLIGO RCG users will be familiar
with this, as it's the same way we configure CDS parts in the front
end models.)

* DarmLentickle.mat
Lentickle model results used to supply the cavity response as a
FlexTf, and to add various noise couplings to the model.
