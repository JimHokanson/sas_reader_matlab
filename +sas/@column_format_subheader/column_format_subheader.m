classdef column_format_subheader < handle
    %
    %   Class:
    %   sas.column_format_subheader
    %
    %   size: 1 per column
    %
    %   See Also
    %   --------
    %   sas.column_name_subheader
    %   sas.column
    %

    %{
    The column format and label subheader contains pointers to a column
    format and label relative to a column text subheader. Since the column
    label subheader only contains information regarding a single column,
    there are typically as many of these subheaders as columns. The
    structure of column format pointers was contributed by Clint Cummins.
    %}

    properties
        unknown5
        unknown47
        d = 'These go into the text entries'
        format_index
        format_offset
        format_length
        label_index
        label_offset
        label_length
    end

    methods
        function obj = column_format_subheader(bytes,is_u64)

            %1:4   1:8 - signature
            %5:34  9:46- unknown5

            %FORM DOC - 
            %29:30 41:42 - informat index
            %31:32 43:44 - informat offset
            %33:34 45:46 - informat length

            %35:36 47:48 - column_format_index to select text subheader
            %37:38 49:50 - column_format_offset - for text signature
            %39:40 51:52 - column_format_length
            %41:42 53:54 - column_label_index_to_select
            %43:44 55:56 - column_label_offset
            %45:46 57:58 - column_label_length
            %47:52 59:64 - unknown47

            if is_u64

                

                %For dates.sas7bdat byte 17 is 12 which matches the format

                obj.unknown5 = bytes(9:46);
                obj.format_index = double(typecast(bytes(47:48),'uint16'))+1;
                obj.format_offset = double(typecast(bytes(49:50),'uint16'))+9;
                obj.format_length = double(typecast(bytes(51:52),'uint16'));
                obj.label_index = double(typecast(bytes(53:54),'uint16'))+1;
                obj.label_offset = double(typecast(bytes(55:56),'uint16'))+9;
                obj.label_length = double(typecast(bytes(57:58),'uint16'));
                obj.unknown47 = bytes(59:end);
            else

                %date_dd_mm_yyyy_copy.sas7bdat
                %9 & 13 - both contain 8
                %
                %DATE displays as DATE8: 31DEC59

                obj.unknown5 = bytes(5:34);
                obj.format_index = double(typecast(bytes(35:36),'uint16'))+1;
                obj.format_offset = double(typecast(bytes(37:38),'uint16'))+5;
                obj.format_length = double(typecast(bytes(39:40),'uint16'));
                obj.label_index = double(typecast(bytes(41:42),'uint16'))+1;
                obj.label_offset = double(typecast(bytes(43:44),'uint16'))+5;
                obj.label_length = double(typecast(bytes(45:46),'uint16'));
                obj.unknown47 = bytes(47:end);
            end
        end
    end
end