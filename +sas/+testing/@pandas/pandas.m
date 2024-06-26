classdef pandas
    %
    %   Class:
    %   sas.testing.pandas
    %
    %   Apparently Pandas read_sas doesn't support automatic
    %   encoding detection which means you get raw bytes back :/
    %
    %   This can be accessed in the main sas reading code via:
    %   t = sas.readFile(file_path,'parser','pandas')
     

    %{
    
    fp = '/Users/jim/Documents/repos/matlab/example_sas_data_files/data_files/deleted_rows.sas7bdat';
    pd = sas.testing.pandas();
    t = pd.read_sas(fp);
    t2 = sas.readFile(fp);

    %}

    %{
    python_env = pyenv()

    %https://www.mathworks.com/support/requirements/python-compatibility.html
    %}

    properties
        pd
    end

    methods
        function obj = pandas()
            obj.pd = py.importlib.import_module('pandas');
        end
        function t = read_sas(obj,file_path)
            df = obj.pd.read_sas(file_path);
            if verLessThan('matlab','24')
                t = sas.utils.dateframeToTable(df);
            else
                t = table(df);
            end
        end
    end
end