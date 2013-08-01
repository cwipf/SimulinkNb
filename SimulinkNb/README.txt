This directory contains a prototype Simulink-based noise budget
toolkit, and a demo that's based on the DARM Simulink model from the
aligocalibration SVN repository.

To run the demo, use the run_DARM_NB script.  For it to work, you'll
need a recent checkout of the directories listed at the top of
DARMParams.m (edit the paths there as needed).  The script should
conclude by popping up a noise plot of suspension electronics terms in
the DARM noise budget.

Note: the DARM model included here has not been vetted and is
certainly not correct in all its particulars.  It's supplied only as
an example to illustrate how the various tools can be used.

== File overview ==

* linFlexTf.m, linFlexTfFold.m
Tools for incorporating frequency response data into Simulink
linearizations.  See the linFlexTf help for details.

* nbFromSimulink.m, NbLibrary.mdl
Tools for generating calibrated noise terms from a Simulink model.
See the nbFromSimulink help for details.

* DARM.mdl, DARMParams.m
Simulink model for DARM and associated parameters (adapted from the
model developed for the calibration group by Jeff Kissel).  Examples
of FlexTf and NbNoiseSource blocks can be seen in the Simulink model
by drilling down into the subsystems, such as:
DARM.mdl/Actuation Function/ETMX/Hierarchy Loops/Driver Electronics

* run_DARM_NB.m, lisoFrd.m
Main script and helper function used for the demo.
