classdef column_attributes_subheader < handle
    %
    %   Class:
    %   sas.column_attributes
    %
    %   TODO: Summarize what this does ...

    properties
        bytes
        unknown7
        unknown9
        unknown11
        
        %offset, 0b, into row bytes
        data_row_offset

        %Width in bytes I believe ...
        column_width
        
        %
        name_length_flag

        %1 - numeric
        %2 - character
        column_type
        
    end

    methods
        function obj = column_attributes_subheader(bytes,is_u64)
            %
            %   1:4    1:8 - signature
            %   5:6    9:10  - remaining length
            %   7:8    11:12 - unknown7
            %   9:10   13:14 - unknown9
            %   11:12  15:16 - unknown11
            %
            %
            %   13:X   17:X  - specification of attributes
            %       - offset
            %       - width
            %       - name_length_flag - rough length of name?
            %       - column_type

            obj.bytes = bytes;
            
            QL = length(bytes);

            if is_u64
                I = 16;
                n_vectors = (QL-28)/16;
                obj.unknown7 = typecast(bytes(9:10),'int16');
                obj.unknown9 = typecast(bytes(11:12),'int16');
                obj.unknown11 = typecast(bytes(13:14),'int16');

                %Column attribute vectors
                data_row_offset = zeros(n_vectors,1);
                column_width = zeros(n_vectors,1);
                name_length_flag = zeros(n_vectors,1);
                column_type = zeros(n_vectors,1);
                for i = 1:n_vectors
                    data_row_offset(i) = typecast(bytes(I+1:I+8),'uint64');
                    column_width(i) = typecast(bytes(I+9:I+12),'uint32');
                    name_length_flag(i) = typecast(bytes(I+13:I+14),'uint16');
                    column_type(i) = bytes(I+15);
                    I = I + 16;
                end
            else
                I = 12;
                n_vectors = (QL-20)/12;
                obj.unknown7 = typecast(bytes(7:8),'int16');
                obj.unknown9 = typecast(bytes(9:10),'int16');
                obj.unknown11 = typecast(bytes(10:11),'int16');

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
        function out = merge(obj1,obj2)
            temp = [obj1 obj2];

            out = temp(1);
            for i = 2:length(temp)
                obj2 = temp(i);
                out.unknown7 = [out.unknown7 obj2.unknown7];
                out.unknown9 = [out.unknown9 obj2.unknown9];
                out.unknown11 = [out.unknown11 obj2.unknown11];
                out.data_row_offset = [out.data_row_offset; obj2.data_row_offset];
                out.column_width = [out.column_width; obj2.column_width];
                out.name_length_flag = [out.name_length_flag; obj2.name_length_flag];
                out.column_type = [out.column_type; obj2.column_type];
            end
        end
    end
end