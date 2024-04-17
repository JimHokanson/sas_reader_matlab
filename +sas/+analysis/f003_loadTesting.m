function f003_loadTesting

file_paths = sas.utils.getExampleFilePaths();
for i = 1:length(file_paths)
    [~,name] = fileparts(file_paths{i});
    if name == "corrupt"
        continue
    end
    fprintf('%s\n',name)
    try
        [s,f] = sas.readFile(file_paths{i});
    catch ME
        if ME.identifier == "sas_reader:big_endian"
            %do nothing
        else
            rethrow(ME)
        end
    end
end



end