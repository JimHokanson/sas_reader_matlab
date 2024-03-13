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


        %????????
        page_type
        page_name

        contains_uncompressed_row_data
        contains_compressed_row_data

        %??? - This appears to also include subheader counts
        data_block_count %BC
        data_block_start

        unknown2
        subheader_pointer_count %SC
        sub_count_short = false

        % s.offsets = sub_offsets;
        % s.lengths = sub_length;
        % s.comp_flags = sub_comp_flag;
        % s.type = sub_type;
        subheader_pointers

        sub_headers

        row_size_subheader
        col_size_subheader
        signature_subheader
        format_subheaders

        %These all show up in the signatures subheader
        %which makes me think it is OK to have more than 1
        col_text_headers
        col_attr_headers
        col_name_headers
        col_list_headers

        full_bytes
        comp_data_rows = {}
        has_compressed = false
    end


    %{
    Layout
    -----------------------------
    %1:24 - fixed
    %25:X - subheader pointers
    %     - spacing
    %     - data
    %     - headers


    %}

    methods
        function obj = page(fid,h,page_index)
            %
            %   h : sas.header
            %
            obj.start_position = ftell(fid);

            if h.is_u64
                B = 32;
                SL = 24; %subpointer length
                n_bytes_initial = 40;
            else
                B = 16;
                SL = 12;
                n_bytes_initial = 24;
            end

            %Read and process the first few bytes
            %----------------------------------------------------
            %*** FREAD ***
            bytes = fread(fid,n_bytes_initial,'*uint8')';
            %1:4             <- signature
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
            obj.unknown1 = bytes(5:B);

            obj.page_type = double(typecast(bytes(B+1:B+2),'int16'));

            %FORM DOC - I think this is all blocks, not just data blocks
            obj.data_block_count = double(typecast(bytes(B+3:B+4),'uint16'));

            %This seems to be consistently off by 1
            obj.subheader_pointer_count = double(typecast(bytes(B+5:B+6),'uint16'));

            obj.data_block_count = obj.data_block_count - obj.subheader_pointer_count;

            %Why is this off by 1?????

            SC = obj.subheader_pointer_count;
            obj.unknown2 = double(typecast(bytes(B+7:B+8),'uint16'));

            %{
            PAGE_META <- 0
            PAGE_DATA <- 256        #1<<8
            PAGE_MIX  <- c(512,640) #1<<9,1<<9|1<<7
            PAGE_AMD  <- 1024       #1<<10
            PAGE_METC <- 16384      #1<<14 (compressed data)
            PAGE_COMP <- -28672     #~(1<<14|1<<13|1<<12) 
            PAGE_MIX_DATA <- c(PAGE_MIX, PAGE_DATA)
            PAGE_META_MIX_AMD <- c(PAGE_META, PAGE_MIX, PAGE_AMD)
            PAGE_ANY  <- c(PAGE_META_MIX_AMD, PAGE_DATA, PAGE_METC, PAGE_COMP)
            %}

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
                case 640
                    %FORM DOC
                    %
                    %date_dd_mm_yyyy_copy.sas7bdat
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
                    obj.data_block_count = 0;
                    %no subheaders
                    obj.contains_uncompressed_row_data = false;
                    obj.contains_compressed_row_data = false;
                    obj.data_block_start = -1;
                    return
                otherwise
                    error('Unrecognized option')
            end

            %Possible early return
            %---------------------------------------------
            offset = ceil((B+8+SC*SL)/8)*8;
            obj.data_block_start = offset + obj.start_position;

            if SC == 0
                %n_bytes_initial
                n_remaining = h.page_length - n_bytes_initial;
                %*** FSEEK ***
                status = fseek(fid,n_remaining,'cof');
                if status == -1
                    error('fseek failed')
                end
                return
            end


            %Subpointer info retrieval
            %----------------------------------------------------------
            n_bytes_pointers = SC*SL;
            %*** FREAD ***
            bytes = fread(fid,n_bytes_pointers,'*uint8')';

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
                sub_offsets = zeros(n_subs,1);
                sub_lengths  = zeros(n_subs,1);
                sub_comp_flags = zeros(n_subs,1);
                sub_types = zeros(n_subs,1);
                for i = 1:n_subs
                    sub_offsets(i) = typecast(bytes(I:I+7),'uint64');
                    sub_lengths(i) = typecast(bytes(I+8:I+15),'uint64');
                    sub_comp_flags(i) = bytes(I+16);
                    sub_types(i) = bytes(I+17);
                    I = I + 24;
                end
            else
                I = 1;
                n_subs = SC;
                sub_offsets = zeros(n_subs,1);
                sub_lengths  = zeros(n_subs,1);
                sub_comp_flags = zeros(n_subs,1);
                sub_types = zeros(n_subs,1);
                for i = 1:n_subs
                    sub_offsets(i) = double(typecast(bytes(I:I+3),'uint32'));
                    sub_lengths(i) = double(typecast(bytes(I+4:I+7),'uint32'));
                    sub_comp_flags(i) = bytes(I+8);
                    %TODO: check this and throw error if not 0
                    sub_types(i) = bytes(I+9);
                    I = I + 12;

                    %The final subheader on a page is usually COMP=1, 
                    %which indicates a truncated row to be ignored; the
                    %complete data row appears on the next page.
                end
            end

            s = struct;
            s.offsets = sub_offsets;
            s.lengths = sub_lengths;
            s.comp_flags = sub_comp_flags;
            s.type = sub_types;
            obj.subheader_pointers = s;

            %Processing of the subheaders
            %----------------------------------------------------
            %TODO: Make this better ...
            %Right now we're reading the entire page
            %
            %- I think eventually we want to do a more specific meta data read
            %
            %Read all if meta data present
            %
            %If only data-data, log only what's necessary
            status = fseek(fid,obj.start_position,'bof');
            if status == -1
                error('Unhandled error')
            end
            bytes = fread(fid,h.page_length,'*uint8')';
            obj.full_bytes = bytes;

            %     'F6F6F6F6' - 4143380214 - column-size subheader, n=1?
            %     'F7F7F7F7' - 4160223223 - row-size subheader, n=1?
            %   
            %     'FFFFFBFE' - 4294966270 - column-format
            %     'FFFFFC00' - 4294966272 - signature counts
            %     'FFFFFFF9' - 4294967289 - column WTF3 - seen in sigs subheader
            %     'FFFFFFFA' - 4294967290 - column WTF2 - seen in sigs subheader
            %                  
            %     'FFFFFFFB' - 4294967291 - column WTF - seen in sigs subheader
            %     'FFFFFFFC' - 4294967292 - column attributes
            %     'FFFFFFFD' - 4294967293 - column text, n >= 1?
            %     'FFFFFFFE' - 4294967294 - column list
            %     'FFFFFFFF' - 4294967295 - column name, n = ???

            %   #define SAS_SUBHEADER_SIGNATURE_COLUMN_MASK    0xFFFFFFF8
            %   /* Seen in the wild: FA (unknown), F8 (locale?) */

            %This 100 is arbitrary
            format_headers = cell(1,100);
            format_I = 0;

            col_text_headers = {};
            col_attr_headers = {};
            col_name_headers = {};
            col_list_headers = {};

            row_size_subheader_set = false;
            column_size_subheader_set = false;
            signature_subheader_set = false;

            is_u64 = h.is_u64;
            sub_headers = cell(1,n_subs);
            sigs = zeros(1,n_subs);
            for i = 1:n_subs
                offset = sub_offsets(i)+1;
                n_bytes_m1 = sub_lengths(i)-1;
                b2 = bytes(offset:offset+n_bytes_m1);
                %Check for an empty last pointer
                %-----------------------------------------
                if isempty(b2)
                    %seems to happen when sub_comp_flags(i) is 1
                    %and only at the end. If present, ignore data
                    %although BC is 0
                    %Not sure why this is happening
                    if i == n_subs
                        obj.sub_count_short = true;
                        obj.subheader_pointer_count = n_subs-1;
                        sub_headers(end) = [];
                        break
                    else
                        error('Unhandled case')
                    end
                end
                if sub_comp_flags(i) == 4
                    obj.has_compressed = true;
                    b3 = [];
                    j = 1;
                    done = false;
                    all_cmds = [];
                    while ~done
                        next_control = b2(j);
                        %upper 4 command, lower 4 length
                        cmd = bitshift(next_control,-4);
                        all_cmds = [all_cmds cmd];
                        len = double(bitand(next_control,15));

                        %https://github.com/WizardMac/ReadStat/blob/dev/src/sas/readstat_sas_rle.c#L43
                        %https://github.com/pandas-dev/pandas/blob/dc19148bf7197a928a129b1d1679b1445a7ea7c7/pandas/_libs/sas.pyx#L61
                        switch cmd
                            case 0 %SAS_RLE_COMMAND_COPY64
                                keyboard
                            case 1 %SAS_RLE_COMMAND_COPY64_PLUS_4096
                                keyboard
                            case 2 %SAS_RLE_COMMAND_COPY96
                                keyboard
                            case 3
                                error('Unrecognized option')
                            case 4 %SAS_RLE_COMMAND_INSERT_BYTE18
                                n_bytes = 18 + len*256;
                                b3 = [b3 repelem(b2(j+1),1,n_bytes)];
                                j = j + 2;
                                keyboard
                            case 5 %SAS_RLE_COMMAND_INSERT_AT17
                                n_bytes = 17 + len*256;
                                b3 = [b3 repelem(uint8('@'),1,n_bytes)];
                                j = j + 1;
                            case 6 %SAS_RLE_COMMAND_INSERT_BLANK17
                                n_bytes = 17+len*256;
                                b3 = [b3 repelem(uint8(' '),1,n_bytes)];
                                j = j + 1;
                            case 7 %SAS_RLE_COMMAND_INSERT_ZERO17
                                n_bytes = 17+len*256;
                                b3 = [b3 repelem(uint8(0),1,n_bytes)];
                                j = j + 1;
                            case 8 %SAS_RLE_COMMAND_COPY1
                                %copy next X
                                n_bytes = len + 1;
                                b3 = [b3 b2(j+1:j+n_bytes)];
                                j = j + n_bytes + 1;
                            case 9 %SAS_RLE_COMMAND_COPY17
                                n_bytes = len + 17;
                                b3 = [b3 b2(j+1:j+n_bytes)];
                                j = j + n_bytes + 1;
                            case 10 %SAS_RLE_COMMAND_COPY33
                                n_bytes = len + 33;
                                b3 = [b3 b2(j+1:j+n_bytes)];
                                j = j + n_bytes + 1;
                            case 11 %SAS_RLE_COMMAND_COPY49
                                n_bytes = len + 49;
                                b3 = [b3 b2(j+1:j+n_bytes)];
                                j = j + n_bytes + 1;
                            case 12 %SAS_RLE_COMMAND_INSERT_BYTE3
                                n_bytes = len + 3;
                                b3 = [b3 repelem(b2(j+1),1,n_bytes)];
                                j = j + 1;
                            case 13 %SAS_RLE_COMMAND_INSERT_AT2
                                n_bytes = len + 2;
                                b3 = [b3 repelem(uint8('@'),1,n_bytes)];
                                j = j + 1;
                            case 14 %SAS_RLE_COMMAND_INSERT_BLANK2
                                n_bytes = len + 2;
                                b3 = [b3 repelem(uint8(32),1,n_bytes)];
                                j = j + 1;
                            case 15 %SAS_RLE_COMMAND_INSERT_ZERO2
                                n_bytes = len + 2;
                                b3 = [b3 repelem(uint8(0),1,n_bytes)];
                                j = j + 1;
                            otherwise
                                error('Unrecognized option')
                        end
                        done = j > length(b2);
                    end
                    obj.comp_data_rows{end+1} = b3';
                    continue
                end

                header_signature = typecast(bytes(offset:offset+3),'uint32');
                sigs(i) = header_signature;
                %https://github.com/WizardMac/ReadStat/blob/887d3a1bbcf79c692923d98f8b584b32a50daebd/src/sas/readstat_sas7bdat_read.c#L626
                switch header_signature
                    case 0
                        %seen in one_observation.sas7bdat
                        if i == n_subs
                            obj.sub_count_short = true;
                            obj.subheader_pointer_count = n_subs-1;
                            sub_headers(end) = [];
                            break
                        else
                            error('Unhandled case')
                        end
                    case 4143380214 %column-size subheader
                        %-----------------------------------------
                        if column_size_subheader_set
                            error('Assumption violated')
                        end
                        obj.col_size_subheader = sas.column_size_subheader(b2,is_u64);
                        sub_headers{i} = obj.col_size_subheader;
                        column_size_subheader_set = true;
                    case 4160223223 %row-size subheader
                        %-----------------------------------------
                        if row_size_subheader_set
                            error('Assumption violated')
                        end
                        obj.row_size_subheader = sas.row_size_subheader(b2,is_u64);
                        sub_headers{i} = obj.row_size_subheader;
                        row_size_subheader_set = true;
                    case 4294966270  %column-format subheader
                        %-----------------------------------------
                        %n = 1 per column
                        %- info stored in ???
                        format_I = format_I + 1;
                        sub_headers{i} = sas.column_format_subheader(b2,is_u64);
                        format_headers(format_I) = sub_headers(i);
                        %- format
                        %- label
                    case 4294966272
                        %-----------------------------------------
                        if signature_subheader_set
                            error('Assumption violated')
                        end
                        obj.signature_subheader = sas.signature_counts_subheader(b2,is_u64);
                        sub_headers{i} = obj.signature_subheader;
                        %When a particular subheader first and last
                        %appears
                        signature_subheader_set = true;
                    case 4294967292
                        %-----------------------------------------
                        sub_headers{i} = sas.column_attributes_subheader(b2,is_u64);
                        col_attr_headers(end+1) = sub_headers(i); %#ok<AGROW>
                        %The column attribute subheader holds
                        %information regarding the column offsets
                        %within a data row, the column widths, and the
                        %column types (either numeric or character).
                    case 4294967293
                        sub_headers{i} = sas.column_text_subheader(b2,is_u64,obj.row_size_subheader);
                        col_text_headers(end+1) = sub_headers(i); %#ok<AGROW>
                        %text but not linked to any column
                    case 4294967294
                        sub_headers{i} = sas.column_list_subheader(b2,is_u64);
                        col_list_headers(end+1) = sub_headers(i); %#ok<AGROW>
                        %Unclear what this is ...
                    case 4294967295
                        sub_headers{i} = sas.column_name_subheader(b2,is_u64);
                        col_name_headers(end+1) = sub_headers(i); %#ok<AGROW>
                    otherwise
                        error('Unrecognized header')
                end
            end

            obj.sub_headers = sub_headers;

            obj.format_subheaders = [format_headers{1:format_I}];

            obj.col_text_headers = [col_text_headers{:}];
            obj.col_attr_headers = [col_attr_headers{:}];
            obj.col_name_headers = [col_name_headers{:}];
            obj.col_list_headers = [col_list_headers{:}];


        end
    end
end