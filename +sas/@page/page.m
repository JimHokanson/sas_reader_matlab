classdef page < handle
    %
    %   Class:
    %   sas.page

    properties
        start_position
        page_id
        unknown1

        %0 - meta
        %256 - data
        %512 - mix
        %1024 - amd
        %16384 - meta
        %-28672 - comp
        page_type
        page_name

        has_subheaders
        contains_uncompressed_row_data
        contains_compressed_row_data

        %???
        data_block_count

        unknown2
        subheader_pointer_count

        % s.offsets = sub_offsets;
        % s.lengths = sub_length;
        % s.comp_flags = sub_comp_flag;
        % s.type = sub_type;
        subheader_pointers
        
        wtf1 %This is for NRD > 0, 8 byte alignment; DL=B+8+SC*SL
        packed_binary_data_row_count_RC
        RC
        end_index


        sub_headers
    end

    %{
    Columns
    ------------------------

    %}


    methods
        function obj = page(fid,h)
            %
            %   h : sas.header
            %
            obj.start_position = ftell(fid);

            %1:4             <- signature
            %5:16     5:32   <- unknown1
            %17:18   33:34   <- page type
            %19:20   35:36   <- block count - BC
            %21:22   37:38   <- subheader pointers count - SC
            %23:24   39:40   <- unknown2
            %25:X    41:X    <- subheader pointers
            %25+SC*SL        <- zeros for 8 byte alignment?
            %                <- packed binary data
            %                <- subheader data or filler

            if h.is_u64
                B = 32;  %offset (from Matt's docs)
                SL = 24; %subpointer length
                n_bytes_initial = 40;
            else
                B = 16;
                SL = 12;
                n_bytes_initial = 24;
            end

            %Read and process the first few bytes
            %----------------------------------------------------
            bytes = fread(fid,n_bytes_initial,'*uint8');
            obj.page_id = bytes(1:4);
            obj.unknown1 = typecast(bytes(5:6),'uint16');

            obj.page_type = typecast(bytes(B+1:B+2),'int16');

            obj.data_block_count = typecast(bytes(B+3:B+4),'uint16');
            BC = obj.data_block_count;
            obj.subheader_pointer_count = typecast(bytes(B+5:B+6),'uint16');

            SC = obj.subheader_pointer_count;
            obj.unknown2 = typecast(bytes(B+7:B+8),'uint16');

            %Assuming this is the rule ...
            obj.has_subheaders = SC > 0;

            switch obj.page_type
                case 0
                    obj.page_name = 'meta';
                    obj.contains_uncompressed_row_data = false;
                    obj.contains_compressed_row_data = true;
                case 256
                    obj.page_name = 'data';
                    obj.contains_uncompressed_row_data = true;
                    obj.contains_compressed_row_data = false;
                case 512
                    obj.page_name = 'mix';
                    obj.contains_uncompressed_row_data = true;
                    obj.contains_compressed_row_data = false;
                case 1024
                    obj.page_name = 'amd';
                    %question marks for both of these ...
                    obj.contains_uncompressed_row_data = true;
                    obj.contains_compressed_row_data = false;
                case 16384
                    obj.page_name = 'meta';
                    obj.contains_uncompressed_row_data = false;
                    obj.contains_compressed_row_data = true;
                case -28672
                    obj.page_name = 'comp';
                    obj.contains_uncompressed_row_data = false;
                    obj.contains_compressed_row_data = false;
                otherwise
                    error('Unrecognized option')
            end

            %Subpointer info retrieval
            %----------------------------------------------------------
            n_bytes_pointers = SC*SL;
            bytes = fread(fid,n_bytes_pointers,'*uint8');

            %Pointer info:
            %1:4 or 1:8  - offset from page start to subheader
            %5:8 or 9:16 - length of subheader - QL
            %               - if zero the subheader can be ignored
            %9   or 17   - compression flag
            %                0 - no compression
            %                1 - truncated (ignore data)
            %                4 - RLE with control byte
            %10  or 18 - subheader type (ST)
            %                0 - Row Size, Column Size, Subheader Counts, Column Format and Label, in Uncompressed file
            %                1 - Column Text, Column Names, Column Attributes, Column List
            %                1 - all subheaders (including row data), in Compressed file.
            %11:12 or 19:24 - zeros - why?? - to flush to 4|8 boundary?
            if h.is_u64
                I = 1;
                n_subs = SC;
                sub_offsets = zeros(n_subs,1,'uint64');
                sub_length  = zeros(n_subs,1,'uint64');
                sub_comp_flag = zeros(n_subs,1);
                sub_type = zeros(n_subs,1);
                for i = 1:n_subs
                    sub_offsets(i) = typecast(bytes(I:I+7),'uint64');
                    sub_length(i) = typecast(bytes(I+8:I+15),'uint64');
                    sub_comp_flag(i) = bytes(I+16);
                    sub_type(i) = bytes(I+17);
                    I = I + 24;
                end
            else
                I = 1;
                n_subs = SC;
                sub_offsets = zeros(n_subs,1);
                sub_length  = zeros(n_subs,1);
                sub_comp_flag = zeros(n_subs,1);
                sub_type = zeros(n_subs,1);
                for i = 1:n_subs
                    sub_offsets(i) = typecast(bytes(I:I+3),'uint32');
                    sub_length(i) = typecast(bytes(I+4:I+7),'uint32');
                    sub_comp_flag(i) = bytes(I+8);
                    sub_type(i) = bytes(I+9);
                    I = I + 12;
                end
            end

            s = struct;
            s.offsets = sub_offsets;
            s.lengths = sub_length;
            s.comp_flags = sub_comp_flag;
            s.type = sub_type;
            obj.subheader_pointers = s;

            

            %Processing of the subheaders
            %----------------------------------------------------
            %TODO: Make this better ...
            %Right now we're reading the entire page
            %
            %- I think eventually we want to do a more specific meta data read
            status = fseek(fid,obj.start_position,'bof');
            if status == -1
                error('Unhandled error')
            end
            bytes = fread(fid,h.page_length,'*uint8');

            %     'F6F6F6F6' - 4143380214 - column-size subheader
            %     'F7F7F7F7' - 4160223223 - row-size subheader
            %     'FFFFFBFE' - 4294966270 - column-format
            %     'FFFFFC00' - 4294966272 - signature counts
            %     'FFFFFFFC' - 4294967292 - column attributes
            %     'FFFFFFFD' - 4294967293 - column text
            %     'FFFFFFFE' - 4294967294 - column list
            %     'FFFFFFFF' - 4294967295 - column name

            %   #define SAS_SUBHEADER_SIGNATURE_COLUMN_MASK    0xFFFFFFF8
            %   /* Seen in the wild: FA (unknown), F8 (locale?) */

            if h.is_u64
                is_u64 = true;
                error('Unhandled case')
            else
                is_u64 = false;
                sub_headers = cell(1,n_subs);
                sigs = zeros(1,n_subs);
                for i = 1:n_subs
                    offset = sub_offsets(i)+1;
                    n_bytes_m1 = sub_length(i)-1;
                    b2 = bytes(offset:offset+n_bytes_m1);
                    if isempty(b2)
                        continue
                    end
                    header_signature = typecast(bytes(offset:offset+3),'uint32');
                    sigs(i) = header_signature;
                    switch header_signature
                        case 4143380214 %column-size subheader
                            sub_headers{i} = sas.column_size_subheader(b2,is_u64);
                            column_size_subheader = sub_headers{i};
                        case 4160223223 %row-size subheader
                            sub_headers{i} = sas.row_size_subheader(b2,is_u64);
                            row_size_subheader = sub_headers{i};
                        case 4294966270 
                            sub_headers{i} = sas.column_format_subheader(b2,is_u64);
                            column_format_subheader = sub_headers{i};
                        case 4294966272
                            sub_headers{i} = sas.signature_counts_subheader(b2,is_u64);
                            signature_counts_subheader = sub_headers{i};
                        case 4294967292
                            sub_headers{i} = sas.column_attributes_subheader(b2,is_u64);
                            column_attributes_subheader = sub_headers{i};
                        case 4294967293 
                            sub_headers{i} = sas.column_text_subheader(b2,is_u64);
                            column_text_subheader = sub_headers{i};
                        case 4294967294
                            sub_headers{i} = sas.column_list_subheader(b2,is_u64);
                            column_list_subheader = sub_headers{i};
                        case 4294967295   
                            sub_headers{i} = sas.column_name_subheader(b2,is_u64);
                            column_name_subheader = sub_headers{i};
                        otherwise
                            error('Unrecognized header')
                    end
                end
            end

            obj.sub_headers = sub_headers;

            DL = mod((B+8+SC*SL+7),8)*8;
            RC = BC - SC;

            I = B+8+SC*SL+DL+1;

            formats = sub_headers(sigs == 4294966270);
            n_columns = length(formats);
            keyboard
            cols = cell(1,n_columns);
            for i = 1:n_columns
                cols{i} = sas.column(formats{i});
            end

            keyboard

        end
    end
end