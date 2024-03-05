classdef column_format_subheader < handle
    %
    %   Class:
    %   sas.column_format_subheader
    %
    %   See Also
    %   --------
    %   sas.column_name_subheader

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
        format_index
        format_offset
        format_length
        label_index
        label_offset
        label_length
    end

    methods
        function obj = column_format_subheader(bytes,is_u64)

            %1:4 - signature
            %5:34 - unknown5
            %35:36 - column_format_index to select text subheader
            %37:38 - column_format_offset - for text signature
            %39:40 - column_format_length
            %41:42 - column_label_index_to_select
            %43:44 - column_label_offset_wrt_end_
            %45:46 - column_label_length
            %47:end - unknown47

            

            if is_u64

            else
                obj.unknown5 = bytes(5:34);
                obj.format_index = double(typecast(bytes(35:36),'uint16'))+1;
                obj.format_offset = double(typecast(bytes(37:38),'uint16'));
                obj.format_length = double(typecast(bytes(39:40),'uint16'));
                obj.label_index = double(typecast(bytes(41:42),'uint16'))+1;
                obj.label_offset = double(typecast(bytes(43:44),'uint16'));
                obj.label_length = double(typecast(bytes(45:46),'uint16'));
                obj.unknown47 = bytes(47:end);
            end
        end
    end
end