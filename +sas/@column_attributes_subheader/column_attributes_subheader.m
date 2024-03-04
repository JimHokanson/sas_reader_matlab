classdef column_attributes_subheader < handle
    %
    %   Class:
    %   sas.column_attributes

    properties
        data_row_offset
        column_width
        name_length_flag
        column_type
        %1 - numeric
        %2 - character
    end

    methods
        function obj = column_attributes_subheader(bytes,is_u64)
            %
            %
            %I=12|16
            
            QL = length(bytes);

            if is_u64
                I = 16;
                n_vectors = (QL-28)/16;
            else
                I = 12;
                n_vectors = (QL-20)/12;
            end



            if is_u64
                error('Not yet implemented')
            else
                %Column attribute vectors
                data_row_offset = zeros(n_vectors,1);
                column_width = zeros(n_vectors,1);
                name_length_flag = zeros(n_vectors,1);
                column_type = zeros(n_vectors,1);
                for i = 1:n_vectors
                    data_row_offset(i) = typecast(bytes(I+1:I+4),'uint32');
                    column_width(i) = typecast(bytes(I+5:I+8),'uint32');
                    name_length_flag(i) = typecast(bytes(I+9:I+10),'uint16');
                    column_type(i) = bytes(I+11);
                    I = I + 12;
                end
            end

            obj.data_row_offset = data_row_offset;
            obj.column_width = column_width;
            obj.name_length_flag = name_length_flag;
            obj.column_type = column_type;

        end
    end
end