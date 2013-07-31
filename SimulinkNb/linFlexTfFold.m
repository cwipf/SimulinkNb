function [ sysFold ] = linFlexTfFold(sys, flexTfs)
%LINFLEXTFFOLD  Joins a linearized Simulink model and a collection of FlexTf block models
%
%   sysFold = LINFLEXTFFOLD(sys, flexTfs)
%
%   This function is analogous to LINLFTFOLD.  Using PRESCALE before
%   calling LINFLEXTFFOLD may improve the numerical accuracy.
%
%   See also: LINFLEXTF, LINLFT, LINLFTFOLD, PRESCALE, FRD.

if numel(flexTfs) < 1
    warning('No FlexTf blocks provided')
    sysFold = sys;
    return;
end

sysFold = lft(sys, flexTfs);

end