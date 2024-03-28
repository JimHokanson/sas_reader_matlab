function f001_deletedEntriesAnalysis

%date_dd_mm_yyyy_copy.sas7bdat
%q_del

d = dir(fullfile(root,'*.sas7bdat'));

for i = 47:length(d)
    fprintf('%s\n',d(i).name);
    if d(i).name == "corrupt.sas7bdat"
        continue
    end
    file_path = fullfile(d(i).folder,d(i).name);
    try
        [s,f] = sas.readFile(file_path);
    catch ME
        if ME.identifier == "sas_reader:big_endian"
            %do nothing
        else
            rethrow(ME)
        end
    end
end