classdef row_size_subheader < handle
    %
    %   Class:
    %   sas.row_size_subheader
    %
    %   TODO: Pull permlink
    %   https://github.com/WizardMac/ReadStat/blob/dev/src/sas/readstat_sas7bdat_read.c#L231
    %
    %   Data are stored in rows.
    %
    %   Expected size: only 1 element
    %
    %   Possible Added Info
    %   -------------------
    %   unknown29 - looks like it contains info on truncating the file
    %   

    properties
        bytes

        %signature %1:4
        unknown5  %5:20

        %in date_dd_mm_yyyy_copy.sas7bdat corresponds
        %to the # of rows at the end to drop
        unknown33 %33:36
        unknown45 %45:52
        unknown57
        unknown65 %65:72
        unknown72 

        %# of bytes per row
        row_length %21:24, RL

        total_row_count %25:28, TRC

        %29:32
        rows_deleted_count
        
        %number of Column Format and Label Subheader on first page
        ncfl1 %37:40

        %number of Column Format and Label Subheader on second page
        ncfl2 %41:44

        %unknown45 - %45:52
        page_length %53:56
        %unknown57 %57:60
        max_row_count_on_mix_page %61:64
        

        n_pages_subheader_data %NPSHD   273:276  ,  

        n_column_text_subheaders
        max_length_column_names
        max_length_columns_labels

        %693:694 u64 space
        compression_method_offset
        
        %695:696 u64 space
        compression_method_length

        length_creator_software_string
        length_creator_PROC_step_name
    end

    methods
        function obj = row_size_subheader(bytes,is_u64)
            obj.bytes = bytes;


            %  1:4      1:8  - signature
            %x 5:20     9:40 - unknown5
            %x 21:24    41:48 - row_length
            %x 25:28    49:56 - total_row_count
            %x 29:36    57:72 - unknown29
            %x 37:40    73:80 - ncfl1
            %x 41:44    81:88 - ncfl2 
            %x 45:52    89:104  - unknown45
            %x 53:56    105:112 - page_length
            %x 57:60    113:120 - unknown57
            %x 61:64    121:128 - max_row_count_on_mix_page
            %65:72    129:144  : all FF?
            %73:220   145:440  : all zeros?
            %221:224  441:444  : page signature again?
            %225:264  445:512  : zeros?
            %265:268  513:520  : value 1 observed in 4 test files
            %269:270  521:522  : int, value 2 observed 
            %271:272  523:528  : zero padded to boundary?            
            %x 273:276  529:536  : n_pages_subheader_data
            %x 355:356  683:684 : length_creator_software_string
            %  361:364  693:694 : compression method offset
            %  365:366  695:696 : compression method length
            %x 379:380  707:708 : length of Creator PROC step name
            %x 421:422  749:750 : number of Column Text subheaders in file
            %x 423:424  751:752 : max length of column names
            %x 425:426  753:754 : max length of column labels

            %36, 38


            if is_u64
                obj.unknown5 = bytes(9:40);
                %TODO: Decided on strategy for uint64 vs double here
                obj.row_length = double(typecast(bytes(41:48),'uint64'));
                obj.total_row_count = double(typecast(bytes(49:56),'uint64'));
                obj.rows_deleted_count = double(typecast(bytes(57:64),'uint64'));
                obj.unknown33 = bytes(57:72);
                obj.ncfl1 = double(typecast(bytes(73:80),'uint64'));
                obj.ncfl2 = double(typecast(bytes(81:88),'uint64'));
                obj.unknown45 = bytes(89:104);
                obj.page_length = double(typecast(bytes(105:112),'uint64'));
                obj.unknown57 = bytes(113:120);
                obj.max_row_count_on_mix_page = double(typecast(bytes(121:128),'uint64'));
                obj.unknown65 = bytes(129:144);
                obj.n_pages_subheader_data = double(typecast(bytes(529:536),'uint64'));
                obj.length_creator_software_string = double(typecast(bytes(683:684),'uint16'));

                %from Parso
                %subheaderOffset + COMPRESSION_METHOD_OFFSET + 82 * intOrLongLength,
                %subheaderOffset + COMPRESSION_METHOD_LENGTH_OFFSET + 82 * intOrLongLength,
                obj.compression_method_offset = double(typecast(bytes(693:694),'uint16'));
                obj.compression_method_length = double(typecast(bytes(695:696),'uint16'));

            %  361:364  693:694 : compression method offset
            %  365:366  695:696 : compression method length


                obj.length_creator_PROC_step_name = double(typecast(bytes(707:708),'uint16'));
                obj.n_column_text_subheaders = double(typecast(bytes(749:750),'uint16'));
                obj.max_length_column_names = double(typecast(bytes(751:752),'uint16'));
                obj.max_length_columns_labels = double(typecast(bytes(753:754),'uint16'));
            else
                obj.unknown5 = bytes(5:20);
                obj.row_length = double(typecast(bytes(21:24),'uint32'));
                obj.total_row_count = double(typecast(bytes(25:28),'uint32'));
                obj.rows_deleted_count = double(typecast(bytes(29:32),'uint32'));
                obj.unknown33 = bytes(33:36);
                obj.ncfl1 = double(typecast(bytes(37:40),'uint32'));
                obj.ncfl2 = double(typecast(bytes(41:44),'uint32'));
                obj.unknown45 = bytes(45:52);
                obj.page_length = double(typecast(bytes(53:56),'uint32'));
                obj.unknown57 = bytes(57:60);
                obj.max_row_count_on_mix_page = double(typecast(bytes(61:64),'uint32'));
                obj.unknown65 = bytes(65:72);
                obj.n_pages_subheader_data = double(typecast(bytes(273:276),'uint32'));
                obj.length_creator_software_string = double(typecast(bytes(355:356),'uint16'));
                
                %Fix for u32
                %obj.compression_method_offset = double(typecast(bytes(693:694),'uint16'));
                %obj.compression_method_length = double(typecast(bytes(695:696),'uint16'));
                
                obj.length_creator_PROC_step_name = double(typecast(bytes(379:380),'uint16'));
                obj.n_column_text_subheaders = double(typecast(bytes(421:422),'uint16'));
                obj.max_length_column_names = double(typecast(bytes(423:424),'uint16'));
                obj.max_length_columns_labels = double(typecast(bytes(425:426),'uint16'));
            end
        end
    end
end