classdef read_data_options
    %
    %   Class:
    %   sas.read_data_options

    properties
        columns_keep = {}
        columns_ignore = {}
        start_stop_rows
        output_type = 'table'
    end

    methods
        function c_out = columnFilter(obj,c_in)
            
        end
    end
end