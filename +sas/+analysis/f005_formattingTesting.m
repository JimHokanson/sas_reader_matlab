function f005_formattingTesting

%u64
file_path = sas.utils.getExampleFilePath('timesimple_parso.sas7bdat');
[s,f] = sas.readFile(file_path);

%This one has custom formats, how do we find that out?
file_path = sas.utils.getExampleFilePath('ivesc.sas7bdat');
[s,f] = sas.readFile(file_path);

%This has unknown subheader
file_path = sas.utils.getExampleFilePath('fts0003.sas7bdat');
[s,f] = sas.readFile(file_path);




file_path = sas.utils.getExampleFilePath('date_dd_mm_yyyy_copy.sas7bdat');
[s,f] = sas.readFile(file_path);

file_path = sas.utils.getExampleFilePath('dates.sas7bdat');
[s,f] = sas.readFile(file_path);

%datetime - has precision

cf = [f.columns.format_sh];
all_bytes = vertcat(cf.bytes);
sc = log(double(all_bytes)+1);


file_path = sas.utils.getExampleFilePath('many_columns.sas7bdat');
f = sas.file(file_path);
[s,f] = sas.readFile(file_path);


b1 = sl.io.readBytes(file_path);
file_path = sas.utils.getExampleFilePath('issue_pandas.sas7bdat');
f = sas.file(file_path);
b2 = sl.io.readBytes(file_path);








end