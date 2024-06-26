classdef column_size_subheader < handle
    %
    %   Class:
    %   sas.column_size_subheader

    properties
        n_columns
        unknown9
    end

    methods
        function obj = column_size_subheader(bytes,is_u64)

            %1:4  1:8  - signature
            %5:8  9:16 - n_columns
            %9:12 17:24 - unknown 9

            if is_u64
                obj.n_columns = double(typecast(bytes(9:16),'uint64'));
                obj.unknown9 = bytes(17:24);
            else
                obj.n_columns = double(typecast(bytes(5:8),'uint32'));
                obj.unknown9 = bytes(9:12);
            end
        end
    end
end