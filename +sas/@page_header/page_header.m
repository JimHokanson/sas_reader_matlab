classdef page_header
    %
    %   Class:
    %   sas.page_header

    properties
        %Byte position in file from ftell()  0b?
        start_position
        
        is_u64

        n_bytes_initial

        %1:4
        page_id

        page_type
        
        %TODO: This is no longer completely unknown
        %- contains info on deleted rows (in part)
        %bytes 5:B
        unknown5

        %I think this is only uncompressed data at the end and NOT
        %the number of rows
        data_block_count %BC
        data_block_start

        unknown2
        n_subheaders %SC
        n_bytes_sub_pointer %SL

        n_bytes_all_sub_pointers
    end

    methods
        function obj = page_header(fid,h)
            %
            %   This is the first step in the processing ...
            %   
            %   header = sas.page_header(fid,h)
            
            obj.start_position = ftell(fid);
            obj.is_u64 = h.is_u64;

            if h.is_u64
                B = 32;
                SL = 24; %subpointer length
                n_bytes_initial = 40;
            else
                B = 16;
                SL = 12;
                n_bytes_initial = 24;
            end

            obj.n_bytes_initial = n_bytes_initial;
            obj.n_bytes_sub_pointer = SL;

            %Read and process the first few bytes
            %----------------------------------------------------
            %*** FREAD ***
            bytes = fread(fid,n_bytes_initial,'*uint8')';
            %1:4             <- signature
            %
            %TODO: Update, contains deleted ...
            %5:16     5:32   <- unknown1
            %17:18   33:34   <- page type (start is B+1)
            %19:20   35:36   <- block count - BC
            %21:22   37:38   <- subheader pointers count - SC
            %23:24   39:40   <- unknown2
            %25:X    41:X    <- subheader pointers
            %25+SC*SL        <- zeros for 8 byte alignment?
            %                <- packed binary data
            %                <- subheader data or filler

            obj.page_id = bytes(1:4);

            %TODO: Move deleted marker offset into here ...
            obj.unknown5 = bytes(5:B);

            obj.page_type = double(typecast(bytes(B+1:B+2),'int16'));

            %FORM DOC - I think this is all blocks, not just data blocks
            obj.data_block_count = double(typecast(bytes(B+3:B+4),'uint16'));

            %This seems to be consistently off by 1
            %
            %   Normally the last subheader is truncated as indicated
            %   by comp_flags == 1
            obj.n_subheaders = double(typecast(bytes(B+5:B+6),'uint16'));

            %??? Is this # of rows or only uncompressed data at the end?
            obj.data_block_count = obj.data_block_count - obj.n_subheaders;

            obj.unknown2 = double(typecast(bytes(B+7:B+8),'uint16'));

            SC = obj.n_subheaders;
            SL = obj.n_bytes_sub_pointer; %subheader byte length
            obj.n_bytes_all_sub_pointers = obj.n_subheaders*obj.n_bytes_sub_pointer;
            
            %Possible early return
            %---------------------------------------------
            offset = ceil((B+8+SC*SL)/8)*8;
            obj.data_block_start = offset + obj.start_position;
        end
    end
end