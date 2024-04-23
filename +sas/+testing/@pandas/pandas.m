classdef pandas
    %
    %   Class:
    %   sas.testing.pandas


    %{
    
    fp = '/Users/jim/Documents/repos/matlab/example_sas_data_files/data_files/deleted_rows.sas7bdat';
    pd = sas.testing.pandas();
    t = pd.read_sas(fp);
    t2 = sas.readFile(fp);

    %}

    %{
    python_env = pyenv()

    wtf = pyrun(["import pandas as pd","pd.__version__"]);

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
            t = sas.utils.dateframeToTable(df);
        end
    end
end