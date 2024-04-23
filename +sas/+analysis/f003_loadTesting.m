function f003_loadTesting

%TODO: have flags for ignoring problem files and big endian
file_paths = sas.utils.getExampleFilePaths(...
    'include_big_endian',false,'include_corrupt_files',false);
for i = 1:length(file_paths)
    [~,name] = fileparts(file_paths{i});
    fprintf('%s\n',name)
    [s,f] = sas.readFile(file_paths{i});
    if ~isempty(f.logger.unrecognized_sigs)
        %keyboard
    end
    %wtf{end+1} = f.logger.getStruct();
end


%t = struct2table(s2);
%has_384 = [s2.has_384];



end