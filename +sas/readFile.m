function [t,file] = readFile(file_path)
%
%
%   [t,file] = sas.readFile(file_path)
%
%   See Also
%   --------
%   sas.file
%   

%   Interfaces to examine:
%   https://haven.tidyverse.org/reference/read_sas.html

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
        t = [];
        file = [];
        return
    end
    file_path = fullfile(path_name,file_name);
end

start_path = fileparts(file_path);

file = sas.file(file_path);
t = file.readAllData('output_type','table');


end