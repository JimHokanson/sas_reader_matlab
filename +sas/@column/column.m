classdef column < handle
    %
    %   Class:
    %   sas.column

    properties
        name
        format
        %Observed values:
        %- datetime


        label
        data_row_offset
        column_width
        %Is this a display thing?
        name_length_flag
        %4 : length <= 8
        %1024 : often <= 8 but sometimes 9-12
        %2048 : >8
        %2560 : >8
        column_type
        %1) numeric
        %2) character
    end

    methods
        function obj = column(i,format_h,name_h,all_text_h,attr_h)
 
            %Name processing
            %---------------------------------------------
            %TODO: How do we know we have the right text
            text_index = name_h.text_index(i);
            text_h = all_text_h(text_index);

            %+4 for sig, +1 for index
            I1 = name_h.text_offset(i)+5;
            I2 = I1 + name_h.text_length(i)-1;

            obj.name = char(text_h.bytes(I1:I2));

            %Attribute processing
            %-----------------------------------------------
            obj.data_row_offset = attr_h.data_row_offset(i);
            obj.column_width = attr_h.column_width(i);
            obj.name_length_flag = attr_h.name_length_flag(i);
            obj.column_type = attr_h.column_type(i);

            if format_h.format_length > 0
                text_h = all_text_h(format_h.format_index);
                I1 = format_h.format_offset+5;
                I2 = I1 + format_h.format_length-1;
                obj.format = char(text_h.bytes(I1:I2));
            end

            if format_h.label_length > 0
                text_h = all_text_h(format_h.label_index);
                keyboard
            end


            
        end
    end
end