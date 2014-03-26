function viewLiveFilter(blk)
%VIEWLIVEFILTER A friendly interface for configuring LiveFilter blocks in Simulink

if ~strcmp(get_param(blk, 'viewGui'), 'on')
    return;
end
set_param(blk, 'viewGui', 'off');

%% Tedious conversion of LiveFilter parameters to viewFilter inputs

blkVars = get_param(blk, 'MaskWSVariables');
name = blkVars(strcmp({blkVars.Name}, 'fmName')).Value;

parVar = get_param(blk, 'par');
% If parVar is inside a library block, then its name probably refers to a
% library parameter (mask variable), which has to be resolved before
% evaluating
parVar = resolveLibraryParam(parVar, blk);
par = evalin('base', parVar);

pLog.(name).OFFSET = par.offset;
pLog.(name).GAIN = par.gain;
pLog.(name).LIMIT = par.limit;

swstat = par.swstat;
% INPUT switch => SWSTAT bit 11 => SW1R bit 3
% OFFSET switch => SWSTAT bit 12 => SW1R bit 4
SW1R = sum(bitset(0, 3:4, bitget(swstat, 11:12)));
% FM1..6 => SWSTAT bit 1:6 => SW1R bits 5:2:15/6:2:16 ("user on"/"really on")
SW1R = SW1R + sum(bitset(0, 5:2:15, bitget(swstat, 1:6)));
SW1R = SW1R + sum(bitset(0, 6:2:16, bitget(swstat, 1:6)));
pLog.(name).SW1R = SW1R;

% FM7:10 => SWSTAT bit 7:10 => SW2R bits 1:2:7/2:2:8
SW2R = sum(bitset(0, 1:2:7, bitget(swstat, 7:10)));
SW2R = SW2R + sum(bitset(0, 2:2:8, bitget(swstat, 7:10)));
% LIMIT switch => SWSTAT bit 14 => SW2R bit 9
% OUTPUT switch => SWSTAT bit 13 => SW2R bit 10
SW2R = SW2R + sum(bitset(0, 9:10, bitget(swstat, [14 13])));
pLog.(name).SW2R = SW2R;

pFilt.(name) = par.fm;

%% Run Matt's snazzy viewFilter function

pLog = viewFilter(pLog, pFilt, name);

%% Tedious updating of parameters with output of viewFilter

par.offset = pLog.(name).OFFSET;
par.gain = pLog.(name).GAIN;
par.limit = pLog.(name).LIMIT;

SW1R = pLog.(name).SW1R;
SW2R = pLog.(name).SW2R;
% FM1:6 => SW1R bit 6:2:16 => SWSTAT bit 1:6
swstat = sum(bitset(0, 1:6, bitget(SW1R, 6:2:16)));
% FM7:10 => SW2R bit 2:2:8 => SWSTAT bit 7:10
swstat = swstat + sum(bitset(0, 7:10, bitget(SW2R, 2:2:8)));
% INPUT switch => SW1R bit 3 => SWSTAT bit 11
% OFFSET switch => SW1R bit 4 => SWSTAT bit 12
swstat = swstat + sum(bitset(0, 11:12, bitget(SW1R, 3:4)));
% OUTPUT switch => SW2R bit 10 => SWSTAT bit 13
% LIMIT switch => SW2R bit 9 => SWSTAT bit 14
swstat = swstat + sum(bitset(0, 13:14, bitget(SW2R, [10 9])));
par.swstat = swstat;

parVar = get_param(blk, 'par');
setInBase(parVar, par, blk);

end

function setInBase(var, val, blk)
% This function is a kludge to allow things like setting fields of
% structures (not possible with assignin alone)

% If var is inside a library block, then its name probably refers to a
% library parameter (mask variable), which has to be resolved before
% evaluating
var = resolveLibraryParam(var, blk);
assignin('base', 'zzz_assignin_kludge_tmp', val);
evalin('base', [var ' = zzz_assignin_kludge_tmp; clear zzz_assignin_kludge_tmp']);

end