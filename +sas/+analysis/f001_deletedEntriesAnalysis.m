function f001_deletedEntriesAnalysis
%
%
%   I'm writing this to look through all files and find
%   examples of deleted entries ...
%
%   TODO: Should implement infrastructure for loading files

%date_dd_mm_yyyy_copy.sas7bdat
%q_del

for i = 49:length(d)
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