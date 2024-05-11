function f007_encodingTesting()

%charset_grek
file_path = sas.utils.getExampleFilePath('charset_aara.sas7bdat');
file_path = sas.utils.getExampleFilePath('chinese_column_works.sas7bdat');


[s,f] = sas.readFile(file_path);

end