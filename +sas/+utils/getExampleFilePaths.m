function file_paths = getExampleFilePaths()
%
%   file_paths = sas.utils.getExampleFilePaths()

root = sas.utils.getExampleRoot();

d = dir(fullfile(root,'**','*.sas7bdat'));

file_paths = arrayfun(@(x) fullfile(x.folder,x.name),d,'un',0);

end