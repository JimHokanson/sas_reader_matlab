classdef column_text_subheader
    %
    %   sas.column_text_subheader
    %
    %   Contains strings but needs other subheaders to identify which
    %   string is which
    

    properties
        bytes
    end

    methods
        function obj = column_text_subheader(bytes,is_u64)
            %
            %   5:8 - size of block
            %   17: 

            %??? Need LCS/LCP from row_size_subheader
            obj.bytes = bytes;
        end
    end
end