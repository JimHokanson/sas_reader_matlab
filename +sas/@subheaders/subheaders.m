classdef subheaders < handle
    %
    %   Class:
    %   sas.subheaders

    properties
        row_size
        col_size
        sig_info
        format
        signature
        text
        name
        attr
        list
    end

    properties (Constant)
       d = '------- important properties -------'
    end

    properties

    end

    methods
        function obj = subheaders()
        end
        function setRowSizeSubheader(obj,value)
            %TODO: Add check ...
            if isempty(obj.row_size)
                obj.row_size = value;
            else
                error('sas_reader:row_size_header_not_unique',...
                    'assumption violated, expecting single row-size header')
            end
        end
    end
end