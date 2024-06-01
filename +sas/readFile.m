function [t,file] = readFile(file_path,varargin)
%X read file and load data into a table
%
%   This function loads the file and returns data in one call. If you would
%   like more control over the data returned load the file and then call a
%   data retrieval method:
%       
%       f = sas.file(file_path)
%       t = f.readData ...
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

%Note, I'm not advertising this but it works
in.parser = 'matlab';
in = sas.sl.in.processVarargin(in,varargin);

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

switch in.parser
    case 'matlab'
        file = sas.file(file_path);
        t = file.readData('output_type','table');
    case 'pandas'
        pd = sas.testing.pandas();
        t = pd.read_sas(file_path);
        file = [];
    case 'parso'
        p = sas.testing.parso();
        [t,file] = p.read_sas(file_path);
end


end