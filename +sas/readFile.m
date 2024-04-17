function [t,file] = readFile(file_path)
%X read file and load data into a table
%
%   This function loads the file and returns data in one call. If you would
%   like more control over the data returned load the file and then call a
%   data retrieval method (TODO: point to documentation)
%
%   Calling forms
%   -------------
%   [t,file] = sas.readFile(file_path)
%
%   %prompts for the file path
%   [t,file] = sas.readFile()
%
%   Inputs
%   ------
%   file_path : string
%       Path to the file (.sas7bdat format)
%
%   Outputs
%   -------
%   t : table
%   file : sas.file
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
t = file.readData('output_type','table');


end