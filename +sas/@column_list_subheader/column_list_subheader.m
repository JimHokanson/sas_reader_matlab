classdef column_list_subheader < handle
    %
    %   Class:
    %   sas.column_list_subheader

    properties
        bytes
    end

    methods
        function obj = column_list_subheader(bytes,is_u64)
            %
            %   Unclear what the purpose of this is ...

            obj.bytes = bytes;
        end
    end
end