function f003_loadTesting

n_errors = 0;
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
            fprintf('big: %s\n',name)
        else
            n_errors = n_errors + 1;
            fprintf(2,'%s\n',name)
            keyboard
            %rethrow(ME)
        end
    end
    %{
    cf = [f.columns.format_sh];
    all_bytes = vertcat(cf.bytes);
    sc = log(double(all_bytes)+1);
    imagesc(sc)
    title(name)
    pause
    %}
end



end