function s = readFileMeta(file_path)
%x Attempts to read only the file meta data
%
%   This may fail on some poorly formatted files ...
%
%   Calling forms
%   -------------
%   s = sas.readFileMeta(file_path)
%
%   %prompts for the file path
%   s = sas.readFileMeta()
%
%   Inputs
%   ------
%   file_path : string
%       Path to the file (.sas7bdat format)
%
%   Outputs
%   -------
%   s :
%       ---Example---
%       file_path: ...
%          header: [1×1 sas.header]
%         n_pages: 65
%         columns: [1×9 sas.column]
%    column_names: {9×1 cell}
%      subheaders: [1×1 sas.subheaders]
%          n_rows: 90673
  

s = struct;

persistent start_path

if nargin == 0
    if ~isempty(start_path)
        start_location = {start_path};
    else
        start_location = {};
    end
    [file_name,path_name] = uigetfile({'*.sas7bdat';}, ...
        'Pick a file',start_location{:});
    
    if file_name == 0
        return
    end
    file_path = fullfile(path_name,file_name);
end

start_path = fileparts(file_path);

s.file_path = file_path;
s.header = sas.readHeader(file_path);

options = sas.file_reading_options;
options.read_intro_pages_only = true;
f1 = sas.file(file_path,options);

s.n_pages = f1.n_pages;
s.columns = f1.columns;
s.column_names = f1.column_names;
s.subheaders = f1.subheaders;
s.n_rows = f1.subheaders.n_rows;

end