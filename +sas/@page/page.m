classdef page < handle
    %
    %   Class:
    %   sas.page

    properties
        start_position
        page_id
        unknown1
        first_b_bytes
        page_type
        page_name
        has_subheaders
        contains_uncompressed_row_data
        contains_compressed_row_data
        block_count_BC
        BC
        unknown2
        subheader_pointer_count_SC
        SC
        SL
        subheader_pointers
        
        wtf1 %This is for NRD > 0, 8 byte alignment; DL=B+8+SC*SL
        packed_binary_data_row_count_RC
        RC
        end_index

    end

    methods
        function obj = page(fid,h)
            %SC
            obj.start_position = ftell(fid);
            
            %Length to data
            %4 + 12 or 28 + 2 + 2 + 2 + 2 + SC*SL

            %TODO: Fix this ...
            bytes = fread(fid,1000,'*uint8');
            obj.page_id = bytes(1:4);
            obj.unknown1 = typecast(bytes(5:6),'uint16');

            if h.is_u64
                B = 32;
                obj.SL = 24;
            else
                B = 16;
                obj.SL = 12;
            end
            
            obj.first_b_bytes = bytes(1:B);

            obj.page_type = typecast(bytes(B+1:B+2),'int16');
            obj.block_count_BC = typecast(bytes(B+3:B+4),'uint16');
            obj.subheader_pointer_count_SC = typecast(bytes(B+5:B+6),'uint16');
            obj.SC = obj.subheader_pointer_count_SC;
            obj.unknown2 = typecast(bytes(B+7:B+8),'uint16');

            %Pointers:
            %SC*SL
            keyboard

            switch obj.page_type
                case 0
                    obj.page_name = 'meta';
                case 256
                    obj.page_name = 'data';
                case 512
                    obj.page_name = 'mix';
                case 1024
                    obj.page_name = 'amd';
                case 16384
                    obj.page_name = 'meta';
                case -28672
                    obj.page_name = 'comp';
                otherwise
                    error('Unrecognized option')
            end
        end
    end
end