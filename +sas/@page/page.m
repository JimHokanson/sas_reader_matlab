classdef page < handle
    %
    %   Class:
    %   sas.page

    properties
        %count on which page is being processed, starting at 1
        page_index

        %Byte position in file from ftell()  0b?
        start_position

        is_u64

        %1:4
        page_id
        
        %TODO: This is no longer completely unknown
        %- contains info on deleted rows (in part)
        %bytes 5:B
        unknown5

        %https://github.com/epam/parso/blob/3c514e66264f5f3d5b2970bc2509d749065630c0/src/main/java/com/epam/parso/impl/SasFileConstants.java#L553
        %
        %   TODO: Update ...
        %
        %Numeric value:
        % 0 - meta, compressed data
        % 128 - meta, compressed data, deleted rows
        % 256 - data only
        %
        page_type
        
        %The following properties are based on the page_type value
        
        has_meta
        has_uncompressed_data
        has_compressed_data
        has_deleted_rows

        data_block_count %BC
        data_block_start

        unknown2
        n_subheaders %SC
        n_bytes_sub_pointer %SL

        %Set true when the last subheader is deleted
        %due to truncation flag (or other reasons)
        sub_count_short = false

        %sas.subheader_pointers
        subheader_pointers 

        all_sub_headers

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
        delete_mask
        has_compressed = false
    end


    %{
    Rough Layout (u32)
    ---------------------------------
    %1:24 - fixed
    %25:X - subheader pointers
    %
    %     - spacing
    %     - data
    %     - headers


    %}

    methods
        function obj = page(fid,h,page_index,parent)
            %
            %   h : sas.header
            %

            %Might remove eventually ...
            obj.page_index = page_index;

            %Initial header processing
            %----------------------------------------------
            s = obj.processPageHeader(fid,h);
            B = s.B;
            SC = obj.n_subheaders;
            SL = obj.n_bytes_sub_pointer; %subheader byte length
            n_bytes_initial = s.n_bytes_initial;
            
            %Possible early return
            %---------------------------------------------
            offset = ceil((B+8+SC*SL)/8)*8;
            obj.data_block_start = offset + obj.start_position;

            %Processing of the page type
            %-------------------------------------
            %TODO: Move into sas.page_type
            obj.processPageType(); 
            
            %TODO: Verify page type assumptions with SC/BC values
            %
            %i.e. 
            %if .has_meta SC > 0
            %if .compressed SC > 0
            %etc.   

            %When no subheaders adjust file pointer to next page and exit
            %------------------------------------------------------------
            if obj.n_subheaders == 0
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
            n_subs = SC;
            s = sas.subheader_pointers(h.is_u64,n_subs,bytes);
            obj.subheader_pointers = s;

            %Subheader processing
            %----------------------------------------------------
            obj.processSubheaders(fid,h.page_length);

            %Deleted mask
            %-------------------------------------------
            obj.processDeletedMask();
        end
        function s = processPageHeader(obj,fid,h)
            %
            %   This is the first step in the processing ...
            %   
            
            obj.start_position = ftell(fid);
            obj.is_u64 = h.is_u64;

            s = struct('B',[],'SL',[],'SC',[],'n_bytes_initial',[]);
            if h.is_u64
                B = 32;
                s.B = B;
                s.SL = 24; %subpointer length
                s.n_bytes_initial = 40;
            else
                B = 16;
                s.B = B;
                s.SL = 12;
                s.n_bytes_initial = 24;
            end

            obj.n_bytes_sub_pointer = s.SL;

            %Read and process the first few bytes
            %----------------------------------------------------
            %*** FREAD ***
            bytes = fread(fid,s.n_bytes_initial,'*uint8')';
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

            %Remove the 
            obj.data_block_count = obj.data_block_count - obj.n_subheaders;

            obj.unknown2 = double(typecast(bytes(B+7:B+8),'uint16'));
        end
        function processSubheaders(obj,fid,page_length)
            %
            %
            %   Utilizing the pointer info, process each sub-header. This
            %   includes information about the row size, column size, as
            %   well as information about the columns. It may also contain
            %   compresssed data.

            s = obj.subheader_pointers;

            sub_offsets = s.offsets;
            sub_lengths = s.lengths;
            sub_comp_flags = s.comp_flags;
            sub_types = s.type;

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
            bytes = fread(fid,page_length,'*uint8')';
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

            n_subs = obj.n_subheaders;

            %Note, this is an overallocation but that's probably fine
            format_headers = cell(1,n_subs);
            format_I = 0;

            col_text_h = {};
            col_attr_h = {};
            col_name_h = {};
            col_list_h = {};

            row_size_subheader_set = false;
            column_size_subheader_set = false;
            signature_subheader_set = false;
            
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
                        obj.n_subheaders = n_subs-1;
                        sub_headers(end) = [];
                        break
                    else
                        error('Unhandled case')
                    end
                end

                %Compressed data in header
                %------------------------------------
                if sub_comp_flags(i) == 4
                    obj.has_compressed = true;
                    obj.comp_data_rows{end+1} = sas.utils.extractCompressed(b2);
                    continue
                end

                %Parso suggests that the first 4 bytes for u64 might be 
                %0 followed by the signature ...
                header_signature = typecast(bytes(offset:offset+3),'uint32');
            

                sigs(i) = header_signature;
                %https://github.com/WizardMac/ReadStat/blob/887d3a1bbcf79c692923d98f8b584b32a50daebd/src/sas/readstat_sas7bdat_read.c#L626
                %https://github.com/epam/parso/blob/3c514e66264f5f3d5b2970bc2509d749065630c0/src/main/java/com/epam/parso/impl/SasFileParser.java#L87
                switch header_signature
                    case 0
                        %seen in one_observation.sas7bdat
                        if i == n_subs
                            obj.sub_count_short = true;
                            obj.n_subheaders = n_subs-1;
                            sub_headers(end) = [];
                            break
                        else

                            % % % if (sasFileProperties.isCompressed() && subheaderIndex == null && ...
                            %               (compression == COMPRESSED_SUBHEADER_ID || compression == 0) 
                            %                   && type == COMPRESSED_SUBHEADER_TYPE) {
                            % % %          subheaderIndex = SubheaderIndexes.DATA_SUBHEADER_INDEX;
                            % % %      }

                            %SASYZCRL
                            %
                            %dates_binary.sas7bdat
                            keyboard
                            obj.sub_count_short = true;
                            obj.n_subheaders = i - 1;
                            sub_headers(i:end) = [];
                            break
                            
                            %error('Unhandled case')
                        end
                    case 4143380214 %column-size subheader
                        %-----------------------------------------
                        if column_size_subheader_set
                            error('Assumption violated')
                        end
                        obj.col_size_subheader = sas.column_size_subheader(b2,obj.is_u64);
                        sub_headers{i} = obj.col_size_subheader;
                        column_size_subheader_set = true;

                        s.logSectionType(i,'col-size');
                    case 4160223223 %row-size subheader
                        %-----------------------------------------
                        if row_size_subheader_set
                            error('Assumption violated')
                        end
                        obj.row_size_subheader = sas.row_size_subheader(b2,obj.is_u64);
                        sub_headers{i} = obj.row_size_subheader;
                        row_size_subheader_set = true;
                        s.logSectionType(i,'row-size');
                    case 4294966270  %column-format subheader
                        %-----------------------------------------
                        %n = 1 per column
                        %- info stored in ???
                        format_I = format_I + 1;
                        sub_headers{i} = sas.column_format_subheader(b2,obj.is_u64);
                        format_headers(format_I) = sub_headers(i);
                        %- format
                        %- label
                        s.logSectionType(i,'col-format');
                    case 4294966272
                        %-----------------------------------------
                        if signature_subheader_set
                            error('Assumption violated')
                        end
                        obj.signature_subheader = sas.signature_counts_subheader(b2,obj.is_u64);
                        sub_headers{i} = obj.signature_subheader;
                        %When a particular subheader first and last
                        %appears
                        signature_subheader_set = true;
                        s.logSectionType(i,'sig-counts');
                    case 4294967292
                        %-----------------------------------------
                        sub_headers{i} = sas.column_attributes_subheader(b2,obj.is_u64);
                        col_attr_h(end+1) = sub_headers(i); %#ok<AGROW>
                        %The column attribute subheader holds
                        %information regarding the column offsets
                        %within a data row, the column widths, and the
                        %column types (either numeric or character).
                        s.logSectionType(i,'col-attr');
                    case 4294967293
                        sub_headers{i} = sas.column_text_subheader(b2,obj.is_u64,obj.row_size_subheader);
                        col_text_h(end+1) = sub_headers(i); %#ok<AGROW>
                        %text but not linked to any column
                        s.logSectionType(i,'col-text');
                    case 4294967294
                        sub_headers{i} = sas.column_list_subheader(b2,obj.is_u64);
                        col_list_h(end+1) = sub_headers(i); %#ok<AGROW>
                        %Unclear what this is ...
                        s.logSectionType(i,'col-list');
                    case 4294967295
                        sub_headers{i} = sas.column_name_subheader(b2,obj.is_u64);
                        col_name_h(end+1) = sub_headers(i); %#ok<AGROW>
                        s.logSectionType(i,'col-name');
                    otherwise
                        error('Unrecognized header')
                end
            end

            obj.all_sub_headers = sub_headers;

            obj.format_subheaders = [format_headers{1:format_I}];

            obj.col_text_headers = [col_text_h{:}];
            obj.col_attr_headers = [col_attr_h{:}];
            obj.col_name_headers = [col_name_h{:}];
            obj.col_list_headers = [col_list_h{:}];

        end
        function processDeletedMask(obj)

            %   Files with deleted entries:
            %   - date_dd_mm_yyyy_copy.sas7bdat
            %   - 

            

            %https://github.com/troels/pandas/blob/fcb169919b93b95e22630a23817dbcf24e0e7cda/pandas/io/sas/sas7bdat.py
            %
            if obj.has_deleted_rows

                fprintf('wtf batman\n')

                bytes = obj.full_bytes;
                SL = obj.n_bytes_sub_pointer;
                SC = obj.n_subheaders;

                %12,24
                if obj.is_u64
                    deleted_pointer = typecast(bytes(25:28),'uint32');
                    bit_offset = 40; %B+8
                else
                    deleted_pointer = typecast(bytes(13:16),'uint32');
                    bit_offset = 24; %B+8
                end
                subheader_pointers_offset = 8;

                BC = obj.data_block_count;

                row_length = obj.row_size_subheader.row_length;

                %This awkward math comes from parso, might simplify
                %eventually ...
                align_correction = mod(bit_offset + subheader_pointers_offset + SC*SL,8);

                deleted_map_offset = bit_offset + deleted_pointer + align_correction + SC * SL + BC*row_length + 1;

                %1 bit used per row, so divide by 8 (8 bits per byte)
                n_bytes_read = ceil(BC/8);

                delete_bitmap_bytes = bytes(deleted_map_offset:deleted_map_offset+n_bytes_read-1);

                %Note, the order is reversed within a byte
                %byte 0, bit 7 - 1st row
                %byte 0, bit 6 - 2nd row
                %
                %...
                %byte 1, bit 7 - 9th row
                %etc.
                
                temp = arrayfun(@(x) bitget(x,8:-1:1),delete_bitmap_bytes,'un',0);
                obj.delete_mask = [temp{:}];

                %PARSO code
                %---------------------
                %{
                    deletedPointerOffset = PAGE_DELETED_POINTER_OFFSET_X86; //12
                    subheaderPointerLength = SUBHEADER_POINTER_LENGTH_X86; //12
                    bitOffset = PAGE_BIT_OFFSET_X86 + 8; //= 16 + 8 = 24
                    
                    int alignCorrection = (bitOffset + SUBHEADER_POINTERS_OFFSET + currentPageSubheadersCount
                            * subheaderPointerLength) % BITS_IN_BYTE;
                    List<byte[]> vars = getBytesFromFile(new Long[] {deletedPointerOffset},
                            new Integer[] {PAGE_DELETED_POINTER_LENGTH});
            
                    long currentPageDeletedPointer = bytesToInt(vars.get(0));
                    long deletedMapOffset = bitOffset + currentPageDeletedPointer + alignCorrection
                            + (currentPageSubheadersCount * subheaderPointerLength)
                            + ((currentPageBlockCount - currentPageSubheadersCount) * sasFileProperties.getRowLength());
                    List<byte[]> bytes = getBytesFromFile(new Long[] {deletedMapOffset},
                        new Integer[] {(int) Math.ceil((currentPageBlockCount - currentPageSubheadersCount) / 8.0)});
            
                    byte[] x = bytes.get(0);
                    for (byte b : x) {
                        deletedMarkers += String.format("%8s", Integer.toString(b & 0xFF, 2)).replace(" ", "0");
                    }
                %}
        
            end
        end
        
        function processPageType(obj)
            %
            %
            %   At this point the page type is specified. Based on the
            %   value we populate the following properties
            %
            %       .has_meta
            %       .has_uncompressed_data
            %       .has_compressed_data
            %       .has_deleted_rows

            %Good ref to work off of
            %https://github.com/epam/parso/blob/3c514e66264f5f3d5b2970bc2509d749065630c0/src/main/java/com/epam/parso/impl/SasFileConstants.java#L553
            switch obj.page_type
                case 0
                    %meta
                    obj.has_meta = true;
                    obj.has_uncompressed_data = false;
                    obj.has_compressed_data = true;
                    obj.has_deleted_rows = false;
                case 128
                    %FORM DOC
                    %seen in: q_del_pandas.sas7bdat
                    %obj.page_name = 'data';
                    obj.has_meta = true;
                    obj.has_uncompressed_data = false;
                    obj.has_compressed_data = true;
                    obj.has_deleted_rows = true;
                case {256 384}
                    %767543210 - bit_ids
                    %100000000 - bit_values
                    %obj.page_name = 'data';
                    obj.has_meta = false;
                    obj.has_uncompressed_data = true;
                    obj.has_compressed_data = false;
                    obj.has_deleted_rows = false;
                case 512
                    %8767543210 
                    %1000000000
                    %obj.page_name = 'mix';
                    obj.has_meta = true;
                    obj.has_uncompressed_data = true;
                    obj.has_compressed_data = false;
                    obj.has_deleted_rows = false;
                case 640
                    %FORM DOC
                    %
                    %   - date_dd_mm_yyyy_copy.sas7bdat
                    %
                    %8767543210
                    %1010000000
                    %obj.page_name = 'mix';
                    %
                    %   uncompressed with deleted rows
                    obj.has_meta = true;
                    obj.has_uncompressed_data = true;
                    obj.has_compressed_data = false;
                    obj.has_deleted_rows = true;
                case 1024
                    %98767543210 - bit_ids
                    %10000000000 - bit_values
                    %
                    %obj.page_name = 'amd';
                    %question marks for both of these ...
                    error('Unhandled case')
                case 16384
                    %321098767543210 - bit_ids
                    %100000000000000 - bit_values
                    %
                    %obj.page_name = 'meta';

                    obj.has_meta = true;
                    obj.has_uncompressed_data = false;
                    obj.has_compressed_data = true;
                    obj.has_deleted_rows = false;
                case -28672
                    %q_pandas.sas7bdat
                    %obj.page_name = 'comp';
                    %error('Unhandled case')

                    %TODO: Is this correct?

                    obj.has_meta = false;
                    obj.has_uncompressed_data = true;
                    obj.has_compressed_data = false;
                    obj.has_deleted_rows = false;
                otherwise
                    error('Unrecognized option')
            end
        end
    end
end