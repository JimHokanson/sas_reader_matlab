function final_path = getExampleFilePath(file_name)
%
%   
%   final_path = sas.utils.getExampleFilePath(file_name)

root = sas.utils.getExampleRoot();

final_path = fullfile(root,file_name);
if ~exist(final_path,'file')
    d = dir(root,'**',file_name);
    final_path = fullfile(d.folder,d.name);
end


end