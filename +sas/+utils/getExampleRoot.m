function root2 = getExampleRoot()
%
%
%   root = sas.utils.getExampleRoot()


root = sas.sl.stack.getPackageRoot();

file_path = fullfile(root,'examples_path.txt');

if ~exist(file_path,'file')
    error('The root of this repo must contain a file called examples_path.txt')
end

root2 = strtrim(fileread(file_path));

end