function final_path = getExampleFilePath(file_name)
%
%   
%   final_path = sas.utils.getExampleFilePath(file_name)

root = sas.utils.getExampleRoot();

final_path = fullfile(root2,file_name);
%if ~exist


end