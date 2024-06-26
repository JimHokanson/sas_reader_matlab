function f006_pandasTesting()

file_paths = sas.utils.getExampleFilePaths(...
    'include_big_endian',false,'include_corrupt_files',false);
for i = 46:length(file_paths)
    [~,name] = fileparts(file_paths{i});
    fprintf('%s\n',name)
    fp = file_paths{i};
    %[s,f] = sas.readFile(fp);
    
    pd = sas.testing.pandas();
    try
        t = pd.read_sas(fp);
    catch ME
        fprintf(2,'%s\n',name)
    end
end


end