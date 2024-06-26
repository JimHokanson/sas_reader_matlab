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
    %   sas.column_attributes
    %
    %   Improvements
    %   ------------
    %   1. DONE Extract informat and format from this class
    %

    %{
    The column format and label subheader contains pointers to a column
    format and label relative to a column text subheader. Since the column
    label subheader only contains information regarding a single column,
    there are typically as many of these subheaders as columns. The
    structure of column format pointers was contributed by Clint Cummins.
    %}

    properties
        bytes
        unknown5
        unknown47
        d = 'These go into the text entries'
        format_index
        %https://support.sas.com/publishing/pubcat/chaps/59498.pdf
        %
        %width
        %precision
        %char informat: $INFORMATw
        %numeric informat: INFORMATw.d
        %date/time informat: INFORMATw.
        informat_width
        informat_precision
        informat_offset
        informat_length
        format_width
        format_precision
        format_offset
        format_length
        label_index
        label_offset
        label_length
    end

    methods
        function obj = column_format_subheader(bytes,is_u64)

            obj.bytes = bytes;

            %1:4   1:8 - signature
            %5:34  9:46- unknown5

            %FORM DOC - TODO: Out of date - see code
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
                obj.unknown5 = bytes(9:42);

                %dates.sas7bdat byte 17 is 12 which matches the format

                %timesimple_parso.sas7bdat
                %   
                %   - all but column_3 have informat width only
                %   - column3 has format
                %

                
                %obj.format_width = double(typecast(bytes(17:18),'uint16'));
                %obj.format_precision = double(typecast(bytes(19:20),'uint16'));

                obj.format_width = double(typecast(bytes(25:26),'uint16'));
                obj.format_precision = double(typecast(bytes(27:28),'uint16'));

                %??? Is this correct
                obj.informat_width = double(typecast(bytes(29:30),'uint16'));
                obj.informat_precision = double(typecast(bytes(31:32),'uint16'));

                obj.informat_offset = double(typecast(bytes(43:44),'uint16'))+9;
                obj.informat_length = double(typecast(bytes(45:46),'uint16'));
                obj.format_index = double(typecast(bytes(47:48),'uint16'))+1;
                obj.format_offset = double(typecast(bytes(49:50),'uint16'))+9;
                obj.format_length = double(typecast(bytes(51:52),'uint16'));
                obj.label_index = double(typecast(bytes(53:54),'uint16'))+1;
                obj.label_offset = double(typecast(bytes(55:56),'uint16'))+9;
                obj.label_length = double(typecast(bytes(57:58),'uint16'));
                obj.unknown47 = bytes(59:end);
            else
                %Examples
                %date_dd_mm_yyyy_copy.sas7bdat
                %   - has width for both format and informat
                %ivesc.sas7bdat
                %   - 1st entry has width for format but not informat
                %   

                obj.unknown5 = bytes(5:30);
                
                obj.format_width = double(typecast(bytes(13:14),'uint16'));
                obj.format_precision = double(typecast(bytes(15:16),'uint16'));
                obj.informat_width = double(typecast(bytes(17:18),'uint16'));
                obj.informat_precision = double(typecast(bytes(19:20),'uint16'));

                obj.informat_offset = double(typecast(bytes(31:32),'uint16'))+9;
                obj.informat_length = double(typecast(bytes(33:34),'uint16'));
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