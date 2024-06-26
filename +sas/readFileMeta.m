function s = readFileMeta(file_path)
%
%   s =  sas.readFileMeta(file_path);

s = struct;

s.header = sas.readHeader(file_path);

options = sas.file_reading_options;
options.read_intro_pages_only = true;
f1 = sas.file(file_path,options);

s.n_pages = f1.n_pages;
s.columns = f1.columns;
s.column_names = f1.column_names;
s.subheaders = f1.subheaders;
s.n_rows = f1.subheaders.n_rows;

end