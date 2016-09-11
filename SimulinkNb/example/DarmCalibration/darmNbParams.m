function darmNbParams
%DARMNBPARAMS  Defines noises for the DARM.mdl Simulink NoiseBudget
%
% It outputs to a variable called "ifoParams.darmNb" in the matlab workspace.

%% Setup and meta-parameters

ifoParams = evalin('base', 'ifoParams');

ifoParams.darmNb.meta.paramsFileName = mfilename('fullpath');
ifoParams.darmNb.meta.name = 'L1';

if exist('NbSVNroot.m', 'file') ~= 2
    error('Please add the NbSVN''s Common/Utils folder to your MATLAB path');
end

noiseModelDir = [NbSVNroot 'Common/Utils/NoiseModel'];
quadLisoDir = [NbSVNroot 'Dev/SusElectronics/LISO/QUAD/'];
currentDir = pwd;

%% QUAD Actuator

% DAC
% units: V/rtHz
% source: placeholder, TBD
% Note: each length actuator consists of multiple coils (TOP coil count = 2
% and UIM/PUM coil count = 4).  Simulink TFs assume that the coils add
% coherently.  But the DAC noise spectra should be summed incoherently,
% and so they are rescaled here by the sqrt of the coil count.
% (eventually we may want to put multiple coils in the model directly)

ifoParams.darmNb.quadTopDac = 100e-9/sqrt(2);
ifoParams.darmNb.quadUimDac = 100e-9/sqrt(4);
ifoParams.darmNb.quadPumDac = 100e-9/sqrt(4);

% Coil driver electronics (also called coil driver "self noise")
% units: A/rtHz
% source: LISO modeling
% Choose the appropriate LISO data based on the dewhite state
% Note: just like the DAC noise spectra above, these have to be scaled
% based on the number of coils.

cd(noiseModelDir);
quadTopSelf = incoherentSum(lisoNoises([quadLisoDir 'TOP/D0902747-v9_LISO' ...
    '_SWLP-' num2str(ifoParams.act.drivers.top.state.lp) ...
    '_NoiseIcoil.out']));
ifoParams.darmNb.quadTopSelf = interp1(quadTopSelf.f, quadTopSelf.asd, ifoParams.freq)/sqrt(2);

quadUimSelf = incoherentSum(lisoNoises([quadLisoDir 'UIM/D070481-04-K_LISO' ...
    '_SWLP3-' num2str(ifoParams.act.drivers.uim.state.lp3) ...
    '_SWLP2-' num2str(ifoParams.act.drivers.uim.state.lp2) ...
    '_SWLP1-' num2str(ifoParams.act.drivers.uim.state.lp1) ...
    '_NoiseIcoil.out']));
ifoParams.darmNb.quadUimSelf = interp1(quadUimSelf.f, quadUimSelf.asd, ifoParams.freq)/sqrt(4);

quadPumSelf = incoherentSum(lisoNoises([quadLisoDir 'PUM/D070483-05-K_LISO' ...
    '_SWLP-' num2str(ifoParams.act.drivers.pum.state.lp) ...
    '_SWACQ-' num2str(ifoParams.act.drivers.pum.state.acq) ...
    '_NoiseIcoil.out']));
ifoParams.darmNb.quadPumSelf = interp1(quadPumSelf.f, quadPumSelf.asd, ifoParams.freq)/sqrt(4);
cd(currentDir);

%% Squeezed Film Damping
% units: N/rtHz
% source: placeholder, loosely based on T0900582

ifoParams.darmNb.squeezedFilmDamping = 1.53e-14; % 5 mm gap
%ifoParams.darmNb.squeezedFilmDamping = 5.9e-15; % 2 cm gap

%% Local Damping (BOSEM)
% units: m/rtHz
% source: placeholder, loosely based on T0900496

ifoParams.darmNb.bosem = 1e-10;

%% Optickle/Lentickle-derived noises
% model source: LentickleAligo/FullIFO

currentWarnState = warning('off','MATLAB:unknownElementsNowStruc');
tickleData = load('DarmLentickle.mat');
warning(currentWarnState);

sensNames = tickleData.cucumber.sensNames;
dofNames = tickleData.cucumber.dofNames;
mirrNames = tickleData.cucumber.mirrNames;
omcSensing = squeeze(tickleData.results.mirrSens(strcmp('OMC_DC', sensNames),:,:))';

% Note: Lentickle model assumes 25 W input.  The model must be re-run to
% update radiation pressure effects and quantum noise if the input power
% changes.

if (ifoParams.sens.laserPower ~= 25)
    warning('ifoParams.sens.laserPower is not consistent with the Lentickle model');
end

% Laser Intensity
% units: RIN/rtHz (in), W/rtHz (out)
% source: placeholder, loosely based on IOO requirements doc T020020

laserRin = [1 1e-8; 10000 1e-8];
laserRin = interp1(laserRin(:,1), laserRin(:,2), ifoParams.freq);
sensingFromAm = omcSensing(:,strcmp('AM', mirrNames));
ifoParams.darmNb.laserAm = 2 .* laserRin .* interp1(tickleData.results.f, abs(sensingFromAm), ifoParams.freq);

% Laser Frequency
% units: Hz/rtHz (in), W/rtHz (out)
% source: placeholder, loosely based on IOO requirements doc T020020

laserFreq = [1 1e-6; 10000 1e-6];
laserFreq = interp1(laserFreq(:,1), laserFreq(:,2), ifoParams.freq);
sensingFromPm = omcSensing(:,strcmp('PM', mirrNames));
ifoParams.darmNb.laserPm = 2*pi./ifoParams.freq .* laserFreq .* interp1(tickleData.results.f, 0 * abs(sensingFromPm), ifoParams.freq);

% Oscillator Amplitude
% units: RAN/rtHz (in), W/rtHz (out)
% source: placeholder, loosely based on IOO requirements doc T020020

oscAm = [1 1e-8; 10000 1e-8];
oscAm = interp1(oscAm(:,1), oscAm(:,2), ifoParams.freq);
sensingFromOscAm = omcSensing(:,strcmp('OSC_AM', mirrNames));
ifoParams.darmNb.oscAm = oscAm.*interp1(tickleData.results.f, abs(sensingFromOscAm), ifoParams.freq);

% Oscillator Phase
% units: rad/rtHz (in), W/rtHz (out)
% source: placeholder, loosely based on IOO requirements doc T020020

oscPm = [1 1e-7; 10000 1e-7];
oscPm = interp1(oscPm(:,1), oscPm(:,2), ifoParams.freq);
sensingFromOscPm = omcSensing(:,strcmp('OSC_PM', mirrNames));
ifoParams.darmNb.oscPm = oscPm .* interp1(tickleData.results.f, abs(sensingFromOscPm), ifoParams.freq);

% Quantum (combined shot and RP noise as seen at the OMC PD)
% units: W/rtHz

ifoParams.darmNb.quantum = interp1(tickleData.results.f, tickleData.results.noiseSens(strcmp('OMC_DC', sensNames),:), ifoParams.freq);

% MICH Coupling
% units: W/rtHz

% First propagate the MICH quantum noise through the Lentickle model to
% find the displacement noise imparted to the mirror

michSensErr = frd(tickleData.results.sensErr(strcmp('MICH', dofNames),:,:), tickleData.results.f, 'Units', 'Hz');
michErrCtrl = frd(tickleData.results.errCtrl(strcmp('MICH', dofNames),strcmp('MICH', dofNames),:), tickleData.results.f, 'Units', 'Hz');
michCtrlCorr = frd(tickleData.results.ctrlCorr(:,strcmp('MICH', dofNames),:), tickleData.results.f, 'Units', 'Hz');
corrMirr = frd(tickleData.results.corrMirr, tickleData.results.f, 'Units', 'Hz');
michSensMirr = freqresp(corrMirr * michCtrlCorr * michErrCtrl * michSensErr, 2*pi*tickleData.results.f);

michNoiseMirrSq = zeros(numel(mirrNames), numel(tickleData.results.f));
for n = 1:numel(tickleData.results.f)
    michNoiseMirrSq(:,n) = abs(michSensMirr(:,:,n)) * tickleData.results.noiseSens(:, n).^2;
end

% Then propagate mirror displacement to the OMC PD

ifoParams.darmNb.mich = interp1(tickleData.results.f, sqrt(sum(abs(omcSensing)' .* michNoiseMirrSq)), ifoParams.freq);

%% ASPD Dark
% units: A/rtHz
% source: placeholder, loosely based on T1300552

ifoParams.darmNb.aspdDark = 2e-11;

%% ADC
% units: V/rtHz
% source: placeholder, TBD

ifoParams.darmNb.adc = 5e-6;

%% Scattered Light Ring
% units: m/rtHz
% source: placeholder, loosely based on T1300354

scatteredLightRing = log10([1 1e-19; 10 1e-20; 100 1e-23; 10000 1e-23]); % m/rtHz
ifoParams.darmNb.scatteredLightRing = 10.^interp1(scatteredLightRing(:,1), scatteredLightRing(:,2), log10(ifoParams.freq));

%% Output

assignin('base', 'ifoParams', ifoParams);
