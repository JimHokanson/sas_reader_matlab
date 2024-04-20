classdef page_type_info
    %
    %   Class:
    %   sas.page_type_info

    properties
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
        has_missing_column_info = false
    end

    methods
        function obj = page_type_info(page_header)
            %
            %
            %   At this point the page type is specified. Based on the
            %   value we populate the following properties
            %
            %       .has_meta
            %       .has_uncompressed_data
            %       .has_compressed_data
            %       .has_deleted_rows

            obj.page_type = page_header.page_type;

            %Good ref to work off of
            %https://github.com/epam/parso/blob/3c514e66264f5f3d5b2970bc2509d749065630c0/src/main/java/com/epam/parso/impl/SasFileConstants.java#L553
            
            %https://github.com/epam/parso/blob/3c514e66264f5f3d5b2970bc2509d749065630c0/src/main/java/com/epam/parso/impl/SasFileParser.java#L602
            
            %Assuming first bit is bit 1 ... NOT 0
            %
            %   bit 8: has deleted rows
            %   bit 9: no meta data ????
            %   
            %

            %https://github.com/epam/parso/blob/master/src/main/java/com/epam/parso/impl/PageType.java

            switch obj.page_type
                case 0
                    %meta
                    obj.has_meta = true;
                    obj.has_uncompressed_data = false;
                    obj.has_compressed_data = true;
                    obj.has_deleted_rows = false;
                case 128
                    %PAGE_CMETA_TYPE
                    %

                    %FORM DOC
                    %seen in: q_del_pandas.sas7bdat
                    %obj.page_name = 'data';
                    obj.has_meta = true;
                    obj.has_uncompressed_data = false;
                    obj.has_compressed_data = true;
                    obj.has_deleted_rows = true;
                case {256}
                    %
                    %   
                    %
                    %767543210 - bit_ids
                    %100000000 - bit_values
                    %obj.page_name = 'data';
                    obj.has_meta = false;
                    obj.has_uncompressed_data = true;
                    obj.has_compressed_data = false;
                    obj.has_deleted_rows = false;
                case 384
                    %384 - deleted_rows.sas7bdat
                    %
                    %data with deleted
                    obj.has_meta = false;
                    obj.has_uncompressed_data = true;
                    obj.has_compressed_data = false;
                    obj.has_deleted_rows = true;
                case 512
                    %PAGE_MIX_TYPE_1
                    %
                    %uncompressed, no deleted

                    obj.has_meta = true;
                    obj.has_uncompressed_data = true;
                    obj.has_compressed_data = false;
                    obj.has_deleted_rows = false;
                case 640
                    %PAGE_MIX_TYPE_2
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

                    %fts0003.sas7bdat

                    %Something about missing column info????
                    obj.has_meta = true;
                    obj.has_uncompressed_data = true;
                    obj.has_compressed_data = false;
                    obj.has_deleted_rows = false; %verified
                    obj.has_missing_column_info = true;

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
                    %
                    %   TODO: I think we are using uint16 so this
                    %   is wrong ...

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

            ph = page_header;

            %May not be true if compressed?
            if page_header.n_subheaders == 0
                %Check 'has_uncompressed_data'
                %keyboard
                %error('Expecting subheader meta data')
            end

            if page_header.data_block_count > 0
                %
                %   Need to do check on:
                %   - has_uncompressed_data
                %   - has_compressed_data
                %
                %keyboard
            end
                

            


        end
    end
end