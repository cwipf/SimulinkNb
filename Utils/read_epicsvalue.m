function value = read_epicsvalue(chans)

[~, b] = system(['caget ' chans]);
nn = strfind(b,'      ');
value = str2num(b(nn+5:length(b)));

