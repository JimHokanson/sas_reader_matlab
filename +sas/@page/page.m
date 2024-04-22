classdef page < handle
    %
    %   Class:
    %   sas.page
    %
    %   See Also
    %   --------
    %   sas.file

    properties
        %count on which page is being processed, starting at 1
        page_index


        header sas.page_header
        data_block_count
        data_block_start


        page_type_info sas.page_type_info
        has_deleted_rows

        subheader_pointers sas.subheader_pointers

        subheaders

        full_bytes
        comp_data_rows = []
        
        delete_mask
        has_delete_mask = false
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
        function obj = page(fid,file_header,page_index,logger,subheaders)
            %
            %   h : sas.header
            %

            %Might remove eventually ...
            obj.page_index = page_index;
        
            %Page header processing
            %---------------------------------------------
            obj.header = sas.page_header(fid,file_header);

            obj.data_block_count = obj.header.data_block_count;
            obj.data_block_start = obj.header.data_block_start;

            %Page type info processing
            %---------------------------------------------
            %
            % - Based on page_type in header, get more info
            % - validate other properties of the header
            obj.page_type_info = sas.page_type_info(obj.header);
            obj.has_deleted_rows = obj.page_type_info.has_deleted_rows;

            page_type = obj.page_type_info.page_type;
            if page_type == 384
                logger.has_384 = page_index;
            elseif page_type == 512
                logger.has_512 = page_index;
            elseif page_type == 640
                logger.has_640 = page_index;
            elseif page_type == 1024
                logger.has_1024 = page_index;
            elseif page_type == 16384
                logger.has_16384 = page_index;
            elseif page_type == -28672
                logger.has_28672 = page_index;
            end

            %-28672
            %-> skip ...
            if obj.page_type_info.page_type == -28672
                n_remaining = file_header.page_length - obj.header.n_bytes_initial;
                status = fseek(fid,n_remaining,'cof');
                if status == -1
                    error('fseek failed')
                end
                return
            end
 
            %When no subheaders adjust file pointer to next page and exit
            %------------------------------------------------------------
            if obj.header.n_subheaders == 0
                n_remaining = file_header.page_length - obj.header.n_bytes_initial;
                %*** FSEEK ***
                status = fseek(fid,n_remaining,'cof');
                if status == -1
                    error('fseek failed')
                end
                
                %This is a bit of a hack. Not sure if deleted is really
                %present. I think it is. Find example file.
                if obj.has_deleted_rows
                    status = fseek(fid,obj.header.start_position,'bof');
                    if status == -1
                        error('Unhandled error')
                    end
                    bytes = fread(fid,file_header.page_length,'*uint8')';
                    obj.full_bytes = bytes;
                    obj.processDeletedMask(subheaders);
                elseif obj.has_deleted_rows
                    %This is a complete hack that is now "hacked" in
                    %"sas.file"
                    obj.delete_mask = false(1,obj.data_block_count);
                    obj.has_delete_mask = true;
                end
                return
            end

            %Subpointer info retrieval
            %----------------------------------------------------------
            %*** FREAD ***
            bytes = fread(fid,obj.header.n_bytes_all_sub_pointers,'*uint8')';
            n_subs = obj.header.n_subheaders;
            obj.subheader_pointers = sas.subheader_pointers(file_header.is_u64,n_subs,bytes);

            %Subheader processing
            %----------------------------------------------------
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
            %
            %   Low priority for now although this may be useful
            %   for larger compressed files where we may want to 
            %   
            status = fseek(fid,obj.header.start_position,'bof');
            if status == -1
                error('Unhandled error')
            end
            bytes = fread(fid,file_header.page_length,'*uint8')';
            obj.full_bytes = bytes;

            [obj.subheaders,obj.comp_data_rows] = subheaders.processPageSubheaders(obj.subheader_pointers,obj,bytes);
            
            obj.has_compressed = ~isempty(obj.comp_data_rows);

            %Deleted mask
            %-------------------------------------------
            obj.processDeletedMask(subheaders);

            if obj.page_type_info.has_missing_column_info
                %keyboard
            end
        end        
        function processDeletedMask(obj,subheaders)

            %   Files with deleted entries:
            %   - date_dd_mm_yyyy_copy.sas7bdat
            %   - 

            has_deleted_rows = obj.page_type_info.has_deleted_rows;

            %https://github.com/troels/pandas/blob/fcb169919b93b95e22630a23817dbcf24e0e7cda/pandas/io/sas/sas7bdat.py
            %
            if has_deleted_rows

                %fprintf('wtf batman\n')

                bytes = obj.full_bytes;
                SL = obj.header.n_bytes_sub_pointer;
                SC = obj.header.n_subheaders;

                %12,24
                if obj.header.is_u64
                    deleted_pointer = typecast(bytes(25:28),'uint32');
                    bit_offset = 40; %B+8
                else
                    deleted_pointer = typecast(bytes(13:16),'uint32');
                    bit_offset = 24; %B+8
                end
                subheader_pointers_offset = 8;

                BC = obj.header.data_block_count;

                row_length = subheaders.row_size.row_length;

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
                obj.has_delete_mask = true;

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
    end
end

function h__seekToNextPage(obj,file_header,page_header)
    n_remaining = file_header.page_length - page_header.n_bytes_initial;
    %*** FSEEK ***
    status = fseek(fid,n_remaining,'cof');
    if status == -1
        error('fseek failed')
    end
end