function final_path = getExampleFilePath(file_name)
%
%   
%   final_path = sas.utils.getExampleFilePath(file_name)

root = sas.utils.getExampleRoot();

if (length(file_name) < 9) || ...
        (file_name(end-8:end) ~= ".sas7bdat")
    file_name = file_name + ".sas7bdat";
end

final_path = fullfile(root,file_name);

%TODO: ensure sas7bdat for file name

if ~exist(final_path,'file')
    d = dir(fullfile(root,'**',file_name));
    final_path = fullfile(d.folder,d.name);
end


end