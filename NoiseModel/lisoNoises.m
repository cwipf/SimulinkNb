%% Import noise data from LISO .out file
function noises = lisoNoises(fileName)

% first count the number of columns in the file (and save their names)
fileID = fopen(fileName, 'r');
textLine = fgetl(fileID);
atOutput = false;
while ischar(textLine)
    if ~isempty(strfind(textLine, '#OUTPUT'))
        atOutput = true;
    elseif atOutput
        columnInfo = textscan(textLine(2:end), '%s', 'Delimiter', ' ', 'MultipleDelimsAsOne', 1);
        columnInfo = [{'freq'}; columnInfo{1}];
        break;
    end
    textLine = fgetl(fileID);
end
fclose(fileID);
nColumns = length(columnInfo);

% then reopen and read in the data
fileID = fopen(fileName, 'r');
data = textscan(fileID, repmat('%f', [1 nColumns]), 'Delimiter', ' ', 'MultipleDelimsAsOne', 1, 'CommentStyle', '#');
fclose(fileID);

data = cell2mat(data);

% omit the 'freq' column
f = data(:,1);
columnInfo = columnInfo(2:end);
data = data(:,2:end);
nColumns = nColumns - 1;

% omit the 'sum' column if present
sumInd = strcmp(columnInfo, 'sum');
columnInfo = columnInfo(~sumInd);
data = data(:,~sumInd);
nColumns = nColumns - sum(sumInd);

% return data as an array of noises
noises{nColumns} = [];
for n = 1:nColumns
    noises{n}.f = f;
    noises{n}.asd = data(:,n);
    % rewrite opamp column names
    columnInfo(n) = strrep(columnInfo(n), '(0)', '(U)');
    columnInfo(n) = strrep(columnInfo(n), '(1)', '(I+)');
    columnInfo(n) = strrep(columnInfo(n), '(2)', '(I-)');
    noises{n}.name = columnInfo{n};
end

end