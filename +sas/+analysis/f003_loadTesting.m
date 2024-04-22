function f003_loadTesting

%all_rand_normal - 2nd page is way off for some reason ...

problem_files = ["corrupt","invalid_lengths",...
    "issue_pandas","issue1_pandas","sas_infinite_loop"];
n_errors = 0;
wtf = {};
file_paths = sas.utils.getExampleFilePaths();
for i = 1:length(file_paths)
    [~,name] = fileparts(file_paths{i});
    if any(problem_files == name)
        continue
    end
    fprintf('%d) %s\n',i, name)
    try
        [s,f] = sas.readFile(file_paths{i});
        wtf{end+1} = f.logger.getStruct();
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

s2 = [wtf{:}];

t = struct2table(s2);

has_384 = [s2.has_384];



end