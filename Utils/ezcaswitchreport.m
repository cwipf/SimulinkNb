function varargout = ezcaswitchreport(varargin)
% ezcaswitchreport(sw1r, sw2r)
% 
% This function decodes the _SW1R and _SW2R filter bank status readbacks
% in the LIGO realtime control system. 
%
% Use EPICS functions to get the values, for instance:
%
%   caget L1:ASC-WFS1_PIT_SW1R L1:ASC-WFS1_PIT_SW2R
%   L1:ASC-WFS1_PIT_SW1R           61685
%   L1:ASC-WFS1_PIT_SW2R           2035
%
% and then use this function to decode them: 
% 
%   >> ezcaswitchreport(61685,2035)
%         INPUT  ON
%        OFFSET  OFF
%   FM1 REQUEST  ON
%   FM1 ENABLED  ON
% ...
%
% You can also get an array of the filter modules that are enabled by
% doing:
%
%   modules = ezcaswitchreport(SW1R, SW2R);
%
% You can also give it the name of the filter bank and it will try to use
% EPICS to get the values.  Remember to strip away the "_SW1R" part of the 
% channel name:
%
%   modules = ezcaswitchreport('L1:ASC-WFS1_PIT')
%
% See /cvs/cds/llo/scripts/general/ezcaswitchreport for a perl script by
% Justin Garofoli that does almost the same thing.
%
% Tobin Fricke, <tfricke@ligo.caltech.edu> 2011-08-09
% Louisiana State University and Agricultural and Mechanical College

if nargin == 2
    % User gave us the SW1R and SW2R numbers directly
    SW1R = varargin{1};
    SW2R = varargin{2};
    
elseif nargin == 1 && ischar(varargin{1})
    % User gave us a filter bank name and we need to read it with EPICS
    bank_name = varargin{1};
    [status, result] = system(...
        sprintf('caget -t %s %s', [bank_name '_SW1R'], [bank_name '_SW2R']));
    if status ~= 0
        error(result)
    end
    result = sscanf(result, '%f');
    SW1R = result(1);
    SW2R = result(2);
else
    
    error('Improper usage');
end

if nargout > 0
    modules = list_enabled_modules(SW1R, SW2R);
    varargout(1) = { modules };
else
    pretty_print_filterbank_status(SW1R, SW2R);
end
end

function pretty_print_filterbank_status(SW1R, SW2R)

SW1R_bit_descriptions = {...
    [],              ...  % BIT  0 -- don't know what bits 0 and 1 are
    [],              ...  % BIT  1
    'INPUT',         ...  % BIT  2
    'OFFSET',        ...  % BIT  3   
    'FM1  REQUEST',  ...  % BIT  4 -- bits 4-13 are FM1-FM5 status
    'FM1  ENABLED',  ...  % BIT  5
    'FM2  REQUEST',  ...  % BIT  6
    'FM2  ENABLED',  ...  % BIT  7
    'FM3  REQUEST',  ...  % BIT  8
    'FM3  ENABLED',  ...  % BIT  9
    'FM4  REQUEST',  ...  % BIT 10   
    'FM4  ENABLED',  ...  % BIT 11
    'FM5  REQUEST',  ...  % BIT 12
    'FM5  ENABLED',  ...  % BIT 13   
    'FM6  REQUEST',  ...  % BIT 14
    'FM6  ENABLED'   ...  % BIT 15   
};

SW2R_bit_descriptions = {...
    'FM7  REQUEST',  ...  % BIT  0 -- buts 0-7 are FM6-FM10 status
    'FM7  ENABLED',  ...  % BIT  1
    'FM8  REQUEST',  ...  % BIT  2
    'FM8  ENABLED',  ...  % BIT  3   
    'FM9  REQUEST',  ...  % BIT  4 
    'FM9  ENABLED',  ...  % BIT  5
    'FM10 REQUEST',  ...  % BIT  6
    'FM10 ENABLED',  ...  % BIT  7
    'LIMIT',         ...  % BIT  8
    'DECIMATION',    ...  % BIT  9
    'OUTPUT',        ...  % BIT 10   
    'HOLD',          ...  % BIT 11
    [],              ...  % BIT 12 -- unknown
    [],              ...  % BIT 13
    [],              ...  % BIT 14 
    []               ...  % BIT 15
};

print_bits(SW1R_bit_descriptions, SW1R);
print_bits(SW2R_bit_descriptions, SW2R);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function modules = list_enabled_modules(SW1R, SW2R)

% Combine SW1R and SW2R into a single 32-bit word:
SW12R = uint32(SW1R) + bitshift(uint32(SW2R), 16);

% these are the "enabled" bits for each filter module in the combined form:
fm_bits  = [5, 7, 9, 11, 13, 15, 17, 19, 21, 23];

% test each bit:
is_enabled = logical(bitand(SW12R, uint32(2 .^ fm_bits)));

% find the modules that are on:
modules = find(is_enabled);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function print_bits(descriptions, bits)
for bit=0:15
    desc = descriptions{bit+1};
    if bitand(bits, 2^bit) ~= 0
        status = 'ON';
    else
        status = 'OFF';
    end
    if ~isempty(desc)
        fprintf('%12s  %s\n', desc, status);
    end
end
end

        
