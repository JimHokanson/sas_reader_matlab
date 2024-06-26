function f004_speedTesting()

%This one decompresses into a ton of columns
file_path = sas.utils.getExampleFilePath('fts0003.sas7bdat');
tic
[s,f] = sas.readFile(file_path);
toc


%Examine numeric
file_path = sas.utils.getExampleFilePath('ivesc.sas7bdat');
bytes = sl.io.readBytes(file_path);
[s,f] = sas.readFile(file_path);



end