function tf = lisoFrd(fileName)
%LISOFRD  Imports TF data from a LISO .out file

fileID = fopen(fileName, 'r');
data = textscan(fileID, '%f%f%f', 'Delimiter', ' ', 'MultipleDelimsAsOne', 1, 'CommentStyle', '#');
fclose(fileID);

data = cell2mat(data);

tf = frd(10.^(data(:,2)/20).*exp(1i*pi*data(:,3)/180), data(:,1), 'Units', 'Hz');

end