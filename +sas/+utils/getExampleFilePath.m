function final_path = getExampleFilePath(file_name)
%
%   
%   final_path = sas.utils.getExampleFilePath(file_name)

root = sas.sl.stack.getPackageRoot();

file_path = fullfile(root,'examples_path.txt');

if ~exist(file_path,'file')
    error('The root of this repo must contain a file called examples_path.txt')
end

root2 = strtrim(fileread(file_path));

final_path = fullfile(root2,file_name);

end