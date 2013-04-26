%% Import TF data from LISO .out file
function tf = lisoTF(fileName)

fileID = fopen(fileName, 'r');
data = textscan(fileID, '%f%f%f', 'Delimiter', ' ', 'MultipleDelimsAsOne', 1, 'CommentStyle', '#');
fclose(fileID);

data = cell2mat(data);

tf = struct('f', [], 'tf', [], 'name', []);
tf.f = data(:,1);
tf.tf = 10.^(data(:,2)/20).*exp(1i*pi*data(:,3)/180);
tf.name = 'LISO TF';

end