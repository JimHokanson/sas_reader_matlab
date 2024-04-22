classdef page_type_info
    %
    %   Class:
    %   sas.page_type_info

    properties
        %https://github.com/epam/parso/blob/3c514e66264f5f3d5b2970bc2509d749065630c0/src/main/java/com/epam/parso/impl/SasFileConstants.java#L553
        %
        %   TODO: Update ...
        %
        % -----------------------------------
        %                   meta, data1, cdata, data2, deleted
        %      0
        %    128
        %    256 
        %    257
        %    384 - data2
        %    512 - data
        %    640 - mix2     
        %   1024 - amd
        %  16384 - meta2
        % -28672 - comp

        %{
        %From readstat
        #define SAS_PAGE_TYPE_META   0x0000
        #define SAS_PAGE_TYPE_DATA   0x0100  256
        #define SAS_PAGE_TYPE_MIX    0x0200  512
                                     0x0280  640
        #define SAS_PAGE_TYPE_AMD    0x0400 1024
        #define SAS_PAGE_TYPE_MASK   0x0F00
        
        #define SAS_PAGE_TYPE_META2  0x4000
        #define SAS_PAGE_TYPE_COMP   0x9000
        %}


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

            obj.page_type = double(page_header.page_type);

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
                    obj.has_meta = true;
                    obj.has_uncompressed_data = false;
                    obj.has_compressed_data = true;
                    obj.has_deleted_rows = false;
                case 128
                    obj.has_meta = true;
                    obj.has_uncompressed_data = false;
                    obj.has_compressed_data = true;
                    obj.has_deleted_rows = true;
                case 256
                    obj.has_meta = false;
                    obj.has_uncompressed_data = true;
                    obj.has_compressed_data = false;
                    obj.has_deleted_rows = false;
                case 384
                    %{
                        'load_log'
                        'data_page_with_deleted'
                        'deleted_rows'
                    %}
                    obj.has_meta = false;
                    obj.has_uncompressed_data = true;
                    obj.has_compressed_data = false;
                    obj.has_deleted_rows = true;
                case 512
                    obj.has_meta = true;
                    obj.has_uncompressed_data = true;
                    obj.has_compressed_data = false;
                    obj.has_deleted_rows = false;
                case 640
                    %{
                    'date_dd_mm_yyyy_copy'
                    'datetime_deleted_rows'
                    'deleted_rows'
                    'load_log'
                    'all_rand_normal_with_deleted'
                    'all_rand_normal_with_deleted2'
                    %}
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
                    %{
                    'test_meta2_page'
                    %}

                    obj.has_meta = true;
                    obj.has_uncompressed_data = false;
                    obj.has_compressed_data = true;
                    obj.has_deleted_rows = false;
                case -28672
                    %
                    %   TODO: I think we are using uint16 so this
                    %   is wrong ...
                    %
                    %   q_del_pandas.sas7bdat

                    %q_pandas.sas7bdat
                    %obj.page_name = 'comp';
                    %error('Unhandled case')

                    %TODO: Is this correct?

                    obj.has_meta = false;
                    obj.has_uncompressed_data = true;
                    obj.has_compressed_data = false;
                    obj.has_deleted_rows = true;
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