function darmParams
%DARMPARAMS  Defines parameters for the DARM.mdl Simulink model
%
% It outputs to a variable called "ifoParams" in the matlab workspace.
% 
% based on the DARM calibration model by J. Kissel, April 2013

%% Common Parameters
ifoParams.paramsFileName = mfilename('fullpath');
ifoParams.name = 'L1';
ifoParams.freq = logspace(log10(5),log10(7000),1000);

if exist('NbSVNroot.m', 'file') ~= 2
    error('Please add the NbSVN''s Common/Utils folder to your MATLAB path');
end

svnDir.sus = '/ligo/svncommon/SusSVN/sus/trunk/';
svnDir.cds = '/opt/rtcds/userapps/release/';
svnDir.cal = '/ligo/svncommon/CalSVN/aligocalibration/trunk/Runs/S7/';
quadModelDir = [svnDir.sus 'Common/SusModelTags/Matlab/'];
quadModelProductionDir = [svnDir.sus 'QUAD/Common/MatlabTools/QuadModel_Production'];
quadFilterDir = [svnDir.sus 'QUAD/Common/FilterDesign/'];
calToolsDir = [svnDir.cal 'Common/MatlabTools/'];
quadLisoDir = [NbSVNroot 'Dev/SusElectronics/LISO/QUAD/'];

currentDir = pwd;

fileName.quadModel  = [quadModelDir 'quadmodelproduction-rev3767_ssmake4pv2eMB5f_fiber-rev3601_fiber-rev3602_released-2013-01-31.mat'];
fileName.dampFilters = [quadFilterDir 'MatFiles/dampingfilters_QUAD_2013-05-01.mat'];
fileName.darmFilters = [quadFilterDir 'HierarchicalControl/2013-01-08_DARMQUAD_HierDesign.mat'];

ifoParams.filterDir.sus = [svnDir.cds 'sus/' ifoParams.name '/filterfiles/'];
ifoParams.filterDir.isc = [svnDir.cds 'isc/' ifoParams.name '/filterfiles/'];
ifoParams.act.filterfiles.etmx = [ifoParams.filterDir.sus ifoParams.name 'SUSETMX.txt'];
ifoParams.act.filterfiles.etmy = [ifoParams.filterDir.sus ifoParams.name 'SUSETMY.txt'];
ifoParams.dig.filterFiles.lsc = [ifoParams.filterDir.isc ifoParams.name 'LSC.txt'];

%% Common Parameters
% This should be pulled out of here and made into a common function
ifoParams.c = 299792458;
ifoParams.armLength = 3995.1;          % [m]
ifoParams.armLightTransitTime = ifoParams.armLength/ifoParams.c; %[s]
ifoParams.FSR = ifoParams.c/(2 * ifoParams.armLength);

% CDS IOP 16k Up/Down sampling filter
cd(calToolsDir);
ifoParams.iop16kAAAI = iopdownsamplingfilters(ifoParams.freq,'16k','biquad');
cd(currentDir);

%% ACTUATION FUNCTION
ifoParams.act.darm2etmx =  0.5;
ifoParams.act.darm2etmy = -0.5;

% LSC_ETM? Filters
ifoParams.act.lsc.etmxGain = 1;
ifoParams.act.lsc.etmyGain = 1;
for iFilterModule = 1:10;
    ifoParams.act.lsc.etmx(iFilterModule).ss = ss(zpk([],[],1));
    ifoParams.act.lsc.etmy(iFilterModule).ss = ss(zpk([],[],1));
end

hierDesign = load(fileName.darmFilters);

% LOCK Filters
% Using FRD TFs to work around backward compatibility issues with the state
% space models.
% M0 (no low frequency offload)
ifoParams.act.M0.lockGain = 1; 
for iFilterModule = 1:10
    ifoParams.act.M0.lock(iFilterModule).ss = ss(zpk([],[],1));
end

% UIM (10 Low Pass + Plant Inv)
ifoParams.act.L1.lockGain = 1; % Gain built into the filters
%ifoParams.act.L1.lock(1).ss = hierDesign.plantInv(2).dof(1).filter.ss;
ifoParams.act.L1.lock(1).ss = ss(zpk([],[],1));
ifoParams.act.L1.lock(1).frd = interp(frd(hierDesign.plantInv(2).dof(1).filter.fd, logspace(-2, log10(7000), 1000), 'Units', 'Hz'), ifoParams.freq);
%ifoParams.act.L1.lock(2).ss = hierDesign.blend(2).dof(1).lp.model.ss;
ifoParams.act.L1.lock(2).ss = ss(zpk([],[],1));
ifoParams.act.L1.lock(2).frd = interp(frd(hierDesign.blend(2).dof(1).lp.model.fd, logspace(-2, log10(7000), 1000), 'Units', 'Hz'), ifoParams.freq);
ifoParams.act.L1.lock(3).ss = ss(zpk([],[],1)); % dummy

% PUM (10-50 Hz Band pass + Plant Inv)
ifoParams.act.L2.lockGain = 1; % Gain built into the filters
%ifoParams.act.L2.lock(1).ss = hierDesign.plantInv(3).dof(1).filter.ss;
ifoParams.act.L2.lock(1).ss = ss(zpk([],[],1));
ifoParams.act.L2.lock(1).frd = interp(frd(hierDesign.plantInv(3).dof(1).filter.fd, logspace(-2, log10(7000), 1000), 'Units', 'Hz'), ifoParams.freq);
%ifoParams.act.L2.lock(2).ss = hierDesign.blend(3).dof(1).hp.model.ss;
ifoParams.act.L2.lock(2).ss = ss(zpk([],[],1));
ifoParams.act.L2.lock(2).frd = interp(frd(hierDesign.blend(3).dof(1).hp.model.fd, logspace(-2, log10(7000), 1000), 'Units', 'Hz'), ifoParams.freq);
%ifoParams.act.L2.lock(3).ss = hierDesign.blend(3).dof(1).lp.model.ss;
ifoParams.act.L2.lock(3).ss = ss(zpk([],[],1));
ifoParams.act.L2.lock(3).frd = interp(frd(hierDesign.blend(3).dof(1).lp.model.fd, logspace(-2, log10(7000), 1000), 'Units', 'Hz'), ifoParams.freq);

% TST (50 Hz High Pass + [dummy] Plant Inv)
ifoParams.act.L3.lockGain = 1; % Gain built into the filters
%ifoParams.act.L3.lock(1).ss = hierDesign.plantInv(4).dof(1).filter.ss;
ifoParams.act.L3.lock(1).ss = ss(zpk([],[],1));
ifoParams.act.L3.lock(1).frd = interp(frd(hierDesign.plantInv(4).dof(1).filter.fd, logspace(-2, log10(7000), 1000), 'Units', 'Hz'), ifoParams.freq);
%ifoParams.act.L3.lock(2).ss = hierDesign.blend(3).dof(1).hp.model.ss;
ifoParams.act.L3.lock(2).ss = ss(zpk([],[],1));
ifoParams.act.L3.lock(2).frd = interp(frd(hierDesign.blend(3).dof(1).hp.model.fd, logspace(-2, log10(7000), 1000), 'Units', 'Hz'), ifoParams.freq);
%ifoParams.act.L3.lock(3).ss = hierDesign.blend(4).dof(1).hp.model.ss;
ifoParams.act.L3.lock(3).ss = ss(zpk([],[],1));
ifoParams.act.L3.lock(3).frd = interp(frd(hierDesign.blend(4).dof(1).hp.model.fd, logspace(-2, log10(7000), 1000), 'Units', 'Hz'), ifoParams.freq);

for iFilterModule = 4:10
    ifoParams.act.L1.lock(iFilterModule).ss = ss(zpk([],[],1));
    ifoParams.act.L2.lock(iFilterModule).ss = ss(zpk([],[],1));
    ifoParams.act.L3.lock(iFilterModule).ss = ss(zpk([],[],1));
end

% Save for when we're reading in live from the filter files.
% for iFilterModule = 1:10
%     ifoParams.act.M0.lock(iFilterModule).ss = ss(zpk([],[],1));
%     ifoParams.act.L1.lock(iFilterModule).ss = ss(zpk([],[],1));
%     ifoParams.act.L2.lock(iFilterModule).ss = ss(zpk([],[],1));
%     ifoParams.act.L3.lock(iFilterModule).ss = ss(zpk([],[],1));
% end


% ESD Bias [counts]
ifoParams.act.esdBias_ct = 1.5e5; % [ct] = 11.4 [V] out of the DAC

% 16k to 64k IOP upsampling filter 
ifoParams.act.cdsUpsamplingFilter_16kto64k.ss = ifoParams.iop16kAAAI.ss;

% DAC
ifoParams.act.dacGain = 20 / 2^18; % [V/ct] 18 Bit DAC

% Coil Driver States
ifoParams.act.drivers.top.state.lp  = 1;

ifoParams.act.drivers.uim.state.lp1 = 1;
ifoParams.act.drivers.uim.state.lp2 = 1;
ifoParams.act.drivers.uim.state.lp3 = 0;

ifoParams.act.drivers.pum.state.lp  = 1;
ifoParams.act.drivers.pum.state.acq = 0;

% Coil Driver FRDs
tmp = lisoFrd([quadLisoDir 'TOP/D0902747-v9_LISO' ...
    '_SWLP-' num2str(ifoParams.act.drivers.top.state.lp) ...
    '_IOUTPUT.out']);
ifoParams.act.drivers.top.frd = interp(tmp, ifoParams.freq);

tmp = lisoFrd([quadLisoDir 'UIM/D070481-04-K_LISO' ...
    '_SWLP3-' num2str(ifoParams.act.drivers.uim.state.lp3) ...
    '_SWLP2-' num2str(ifoParams.act.drivers.uim.state.lp2) ...
    '_SWLP1-' num2str(ifoParams.act.drivers.uim.state.lp1) ...
    '_IOUTPUT.out']);
ifoParams.act.drivers.uim.frd = -interp(tmp, ifoParams.freq);

tmp = lisoFrd([quadLisoDir 'PUM/D070483-05-K_LISO' ...
    '_SWLP-' num2str(ifoParams.act.drivers.pum.state.lp) ...
    '_SWACQ-' num2str(ifoParams.act.drivers.pum.state.acq) ...
    '_IOUTPUT.out']);
ifoParams.act.drivers.pum.frd = interp(tmp, ifoParams.freq);

%%
%tmp = load(fileName.quadModel);
% Due to backward compatibility issues with the saved quadModel .mat file,
% generate a fresh model instead.
cd(quadModelProductionDir);
currentFontSize = get(0, 'DefaultAxesFontSize'); % prevent model generator from messing with the font size
quadModel = generate_QUAD_Model_Production(ifoParams.freq, 'fiber');
set(0, 'DefaultAxesFontSize', currentFontSize);
cd(currentDir);
ifoParams.act.quadModel.ss = prescale(quadModel.ss, {2*pi*min(ifoParams.freq), 2*pi*max(ifoParams.freq)});
ifoParams.act.quadModel.frd = frd(ifoParams.act.quadModel.ss, ifoParams.freq, 'Units', 'Hz');
%%
tmp = load(fileName.dampFilters);
ifoParams.act.damp(1).ss = tmp.calibFilter.L.ss;
ifoParams.act.damp(2).ss = tmp.calibFilter.T.ss;
ifoParams.act.damp(3).ss = tmp.calibFilter.V.ss;
ifoParams.act.damp(4).ss = tmp.calibFilter.R.ss;
ifoParams.act.damp(5).ss = tmp.calibFilter.P.ss;
ifoParams.act.damp(6).ss = tmp.calibFilter.Y.ss;

ifoParams.act.esdBias_ct = 1000;

%%
ifoParams.act.cavityCrossCouplings.T2L = 0;     % Does not couple to cavity
ifoParams.act.cavityCrossCouplings.V2L = 0.001; % [m/m]   Due to Earth's Curvature over 4km
ifoParams.act.cavityCrossCouplings.R2L = 0;     % Does not couple to cavity
ifoParams.act.cavityCrossCouplings.P2L = 0.001; % [m/rad] Due to mis-centered beam on optic
ifoParams.act.cavityCrossCouplings.Y2L = 0.001; % [m/rad] Due to mis-centered beam on optic

%% SENSING FUNCTION
ifoParams.sens.adcGain = 2^16/40; %[ct/V]

ifoParams.sens.cdsDownsamplingFilter_64kto16k.ss = ifoParams.iop16kAAAI.ss;

ifoParams.sens.preamp.zswitch.state = 1; % 1 corresponds to energized, 400 Ohms
                                         % 0 corresponds to de-energized, 100 Ohms

ifoParams.sens.iscinf(1).ss = ss(zpk([],[],1));                                         
                                         
ifoParams.sens.whitening.stage1.state = 0; % 1 bypasses whitening
ifoParams.sens.whitening.stage2.state = 0; % 1 bypasses whitening

ifoParams.sens.ifo2pd1 = 0.5;
ifoParams.sens.ifo2pd2 = 0.5;

ifoParams.sens.pdQuantumEfficiency = 0.95; % [A/W]
   
ifoParams.sens.cavityPole.avgFreq = 393;  % [Hz] Assume the same arm cavity reflectivities
% ifoParams.sens.cavityPole.xFreq = 393; % [Hz] % Assume different arm cavity reflectivities
% ifoParams.sens.cavityPole.yFreq = 393; % [Hz] % Assume different arm cavity reflectivities

ifoParams.sens.ifoResponse.opticalGain_1W = 10.^(128/20); % [W/m] eye-balled from Adam Mullavey's Optickle Analsys
ifoParams.sens.laserPower = 25; % [W] 
if isfield(ifoParams.sens.cavityPole,'avgFreq')
    % Assume the same arm cavity reflectivities
    poleFreq = ifoParams.sens.cavityPole.avgFreq;
    
    % Would love to use the full Fabry-Perot response, but can't figure out
    % how to make an LTI without tons of poles and zeros to represent the
    % FSR resonances. For now, just go back to using a cavity pole.
    % (FlexTf can be used instead, see below)
    cavityResponse = ss(zpk([], -2*pi*poleFreq, 2*pi*poleFreq));
    cavityResponse = ifoParams.sens.laserPower * ...
                     ifoParams.sens.ifoResponse.opticalGain_1W * ...
                     cavityResponse;
else
    % Assume different arm cavity reflectivities
    xPoleFreq = ifoParams.sens.cavityPole.xFreq;
    yPoleFreq = ifoParams.sens.cavityPole.xFreq;
    
    % Would love to use the full Fabry-Perot response, but can't figure out
    % how to make an LTI without tons of poles and zeros to represent the
    % FSR resonances. For now, just go back to using a cavity pole.
    % (FlexTf can be used instead, see below)
    cavityResponse = ss((zpk([], -2*pi*xPoleFreq, 2*pi*xPoleFreq)+zpk([], -2*pi*yPoleFreq, 2*pi*yPoleFreq))/2) ;
    cavityResponse = ifoParams.sens.laserPower * ...
                     ifoParams.sens.ifoResponse.opticalGain_1W * ...
                     cavityResponse;
end
ifoParams.sens.ifoResponse.ss = cavityResponse;

% Cavity response FRD from Lentickle (25 W input)
% Note: Lentickle model assumes 25 W input.  The model must be re-run to
% update radiation pressure effects and quantum noise if the input power
% changes.

if (ifoParams.sens.laserPower ~= 25)
    warning('ifoParams.sens.laserPower is not consistent with the Lentickle model');
end

currentWarnState = warning('off','MATLAB:unknownElementsNowStruc');
tickleData = load('DarmLentickle.mat'); % from running LentickleAligo/FullIFO model
warning(currentWarnState);

sensNames = tickleData.cucumber.sensNames;
dofNames = tickleData.cucumber.dofNames;
omcSensing = squeeze(tickleData.results.mirrSens(strcmp('OMC_DC', sensNames),:,:))';
omcSensing = omcSensing *ifoParams.sens.laserPower/25;
sensingFromDARM = omcSensing * tickleData.cucumber.dofMirr(:,strcmp('DARM', dofNames));
ifoParams.sens.ifoResponse.frd = interp(frd(sensingFromDARM, tickleData.results.f, 'Units', 'Hz'), ifoParams.freq);

ifoParams.sens.armTimeDelay.sec = ifoParams.armLightTransitTime;
ifoParams.sens.armTimeDelay.f   = exp(-2*pi*1i*ifoParams.freq(:)*ifoParams.sens.armTimeDelay.sec);

%% DIGITAL FILTER
% Using FRD TFs to work around backward compatibility issues with the state
% space models.
ifoParams.dig.darmGain = 1; % Gain built into filters
%ifoParams.dig.darm(1).ss = hierDesign.darm.filter.ss;
ifoParams.dig.darm(1).ss = ss(zpk([],[],1));
ifoParams.dig.darm(1).frd = interp(frd(hierDesign.darm.filter.fd, logspace(-2, log10(7000), 1000), 'Units', 'Hz'), ifoParams.freq);
%ifoParams.dig.darm(2).ss = hierDesign.iscinf.dof(1).model.ss;
ifoParams.dig.darm(2).ss = ss(zpk([],[],1));
ifoParams.dig.darm(2).frd = interp(frd(hierDesign.iscinf.dof(1).model.fd, logspace(-2, log10(7000), 1000), 'Units', 'Hz'), ifoParams.freq);

for iFilterModule=3:10
    ifoParams.dig.darm(iFilterModule).ss = ss(zpk([],[],1));
end

% Save for when we're reading in live from the filter files.
% for iFilterModule=1:10
%     ifoParams.dig.darm(iFilterModule).ss = ss(zpk([],[],1));
% end

assignin('base', 'ifoParams', ifoParams);
