classdef column_name_subheader < handle
    %
    %   Class:
    %   sas.column_name_subheader


    %   Multiple names ...

    properties
        text_index
        text_offset
        text_length
    end

    methods
        function obj = column_name_subheader(bytes,is_u64)
            %

            %n_pointer_bytes_remaining = typecast(bytes(5:6),'uint16');

            if is_u64
                n_pointers = (length(bytes) - 28)/8;
                I = 16;
            else
                n_pointers = (length(bytes) - 20)/8;
                I = 12;
            end

            text_index = zeros(n_pointers,1);
            text_offset = zeros(n_pointers,1);
            text_length = zeros(n_pointers,1);

            %"column name pointers"
            
            for i = 1:n_pointers
                text_index(i) = typecast(bytes(I+1:I+2),'uint16') + 1;
                text_offset(i) = typecast(bytes(I+3:I+4),'uint16');
                text_length(i) = typecast(bytes(I+5:I+6),'uint16');
                I = I + 8;
            end

            
            obj.text_index = text_index;
            obj.text_offset = text_offset;
            obj.text_length = text_length;

            %Note, padded with 0s at the end - why??? who knows ...
        end
    end
end