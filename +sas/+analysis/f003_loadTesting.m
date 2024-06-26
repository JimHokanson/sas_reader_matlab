function f003_loadTesting

profile on

file_paths = sas.utils.getExampleFilePaths(...
    'include_big_endian',false,'include_corrupt_files',false);
n_files = length(file_paths);

char_sets = cell(n_files,1); 
names = cell(n_files,1);  

for i = 1:n_files
    [~,name] = fileparts(file_paths{i});
    names{i} = name;
    fprintf('%s\n',name)
    fp = file_paths{i};
    [s,f] = p.read_sas(fp);
    [s,f] = sas.readFile(fp);
    char_sets{i} = f.header.character_encoding_name;
end
profile off
profile viewer



end