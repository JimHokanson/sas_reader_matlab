classdef column < handle
    %
    %   Class:
    %   sas.column
    %
    %   See Also
    %   --------
    %   sas.column_name_subheader
    %   sas.column_format_subheader
    %   sas.column_size_subheader

    properties
        name
        format = ''
        informat

        attr_sh
        format_sh
        %Observed values:
        %- datetime

        u5
        u47


        label = ''
        data_row_offset
        
        %Width is in bytes
        column_width

        name_length_flag
        %4 : length <= 8
        %1024 : often <= 8 but sometimes 9-12
        %2048 : >8
        %2560 : >8
        column_type
        is_numeric
        is_character
        %1) numeric
        %2) character
    end

    methods
        function obj = column(i,format_h,name_h,all_text_h,attr_h)
            %
            %   format_h : length 1 by design
            %   name_h : length 1, arrays of length n_columns
            %   all_text_h : variable length
            %   attr_h :length 1, arrays of length n_columns
            %
            %   See Also
            %   --------
            %   sas.file

            obj.format_sh = format_h;
            obj.attr_sh = attr_h;

            obj.u5 = format_h.unknown5;
            obj.u47 = format_h.unknown47;
 
            %Name processing
            %---------------------------------------------
            %TODO: How do we know we have the right text
            text_index = name_h.text_index(i);
            text_h = all_text_h(text_index);

            I1 = name_h.text_offset(i);
            I2 = I1 + name_h.text_length(i)-1;

            obj.name = char(text_h.bytes(I1:I2));

            %Attribute processing
            %-----------------------------------------------
            obj.data_row_offset = attr_h.data_row_offset(i);
            obj.column_width = attr_h.column_width(i);
            obj.name_length_flag = attr_h.name_length_flag(i);
            obj.column_type = attr_h.column_type(i);
            obj.is_numeric = obj.column_type == 1;
            obj.is_character = obj.column_type == 2;

            if format_h.format_length > 0
                text_h = all_text_h(format_h.format_index);
                I1 = format_h.format_offset;
                I2 = I1 + format_h.format_length-1;
                obj.format = char(text_h.bytes(I1:I2));
            end

            if format_h.informat_length > 0
                text_h = all_text_h(format_h.format_index);
                I1 = format_h.informat_offset;
                I2 = I1 + format_h.informat_length-1;
                obj.informat = char(text_h.bytes(I1:I2));
            end

            if format_h.label_length > 0
                text_h = all_text_h(format_h.label_index);
                I1 = format_h.label_offset;
                I2 = I1 + format_h.label_length-1;
                obj.label = char(text_h.bytes(I1:I2));
            end


            
        end
    end
end