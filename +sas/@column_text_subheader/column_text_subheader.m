classdef column_text_subheader
    %
    %   sas.column_text_subheader
    %
    %   Contains strings but needs other subheaders to identify which
    %   string is which
    

    properties
        size_text_block
        unknown7
        unknown9
        unknown11
        unknown13
        unknown15
        bytes
    end

    methods
        function obj = column_text_subheader(bytes,is_u64)
            %
            %

            %   1:4 - signature
            %   5:6 - size of block
            %   7:8
            %   9:10
            %   11:12
            %   13:14
            %   15:16
            %
            %   17: 

            obj.size_text_block = double(typecast(bytes(5:6),'uint16'));

            obj.unknown7 = bytes(7:8);
            obj.unknown9 = bytes(9:10);
            obj.unknown11 = bytes(11:12);
            obj.unknown13 = bytes(13:14);
            obj.unknown15 = bytes(15:16);

            %??? Need LCS/LCP from row_size_subheader
            obj.bytes = bytes(:)';
        end
    end
end