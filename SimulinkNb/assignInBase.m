function assignInBase(var, val)
%ASSIGNINBASE  Assign variable in base workspace.
%
%   ASSIGNINBASE('VAR', VAL) assigns the variable 'VAR' in the base
%   workspace the value VAL.  This function is a kludge to allow things
%   like setting fields of structures (not possible with ASSIGNIN alone).
%   See also: ASSIGNIN.

assignin('base', 'zzz_assigninbase_kludge_tmp', val);
cleanupVar = onCleanup(@() evalin('base', 'clear zzz_assigninbase_kludge_tmp'));
evalin('base', [var ' = zzz_assigninbase_kludge_tmp;']);
clear cleanupVar;

end

