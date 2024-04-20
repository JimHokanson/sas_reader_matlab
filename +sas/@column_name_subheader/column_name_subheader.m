classdef column_name_subheader < handle
    %
    %   Class:
    %   sas.column_name_subheader

    properties
        unknown7
        unknown9
        unknown11
        %conversted to 1b
        text_index
        text_offset
        text_length
    end

    methods
        function obj = column_name_subheader(bytes,is_u64)
            %

            %1:4   1:8 - signature
            %5:6   9:10 - length of remaining subheader
            %7:8   11:12 - unknown7
            %9:10  13:14 - unknown9
            %11:12 15:16 - unknown11

            if is_u64
                n_pointers = (length(bytes) - 28)/8;
                I = 16;
                %not sure why needed, skipping signature then +1
                %conversion?
                read_offset = 9;
                obj.unknown7 = bytes(11:12);
                obj.unknown9 = bytes(13:14);
                obj.unknown11 = bytes(15:16);
            else
                n_pointers = (length(bytes) - 20)/8;
                I = 12;
                read_offset = 5;
                obj.unknown7 = bytes(7:8);
                obj.unknown9 = bytes(9:10);
                obj.unknown11 = bytes(11:12);
            end

            text_index = zeros(n_pointers,1);
            text_offset = zeros(n_pointers,1);
            text_length = zeros(n_pointers,1);

            %"column name pointers" - same for 32 and 64 bit
            for i = 1:n_pointers
                text_index(i) = typecast(bytes(I+1:I+2),'uint16') + 1;
                text_offset(i) = typecast(bytes(I+3:I+4),'uint16') + read_offset;
                text_length(i) = typecast(bytes(I+5:I+6),'uint16');
                I = I + 8;

                %TODO: Look at the index for missing columns ...
            end

            %https://github.com/epam/parso/blob/3c514e66264f5f3d5b2970bc2509d749065630c0/src/main/java/com/epam/parso/impl/SasFileParser.java#L1580
            
            obj.text_index = text_index;
            obj.text_offset = text_offset;
            obj.text_length = text_length;

            %Note, padded with 0s at the end - why??? who knows ...
            %12|16 + 8*n_pointers
        end
    end
end