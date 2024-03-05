classdef row_size_subheader < handle
    %
    %   Class:
    %   sas.row_size_subheader
    %
    %   https://github.com/WizardMac/ReadStat/blob/dev/src/sas/readstat_sas7bdat_read.c#L231

    properties
        bytes
        %signature %1:4

        unknown5  %5:20
        unknown29 %29:36
        unknown45 %45:52
        unknown57

        row_length %21:24, RL
        total_row_count %25:28, TRC
        %-
        
        col_count_p1 %37:40
        col_count_p2 %41:44
        %unknown45 - %45:52
        page_length %53:56
        %unknown57 %57:60
        max_row_count_on_mix_page %61:64
        n_pages_subheader_data %NPSHD

        max_length_column_names

        max_length_columns_labels

        length_creator_software_string
        length_creator_PROC_step_name

    end

    %{
    %https://github.com/BioStatMatt/sas7bdat/blob/master/R/sas7bdat.R#L404
    row_size <- get_subhs(subhs, SUBH_ROWSIZE)
    if(length(row_size) != 1)
        stop(paste("found", length(row_size),
            "row size subheaders where 1 expected", BUGREPORT))
    row_size <- row_size[[1]]
    row_length   <- read_int(row_size$raw,
                             if(u64) 40 else 20,
                             if(u64) 8  else 4)
    row_count    <- read_int(row_size$raw,
                             if(u64) 48 else 24,
                             if(u64) 8  else 4)
    col_count_p1 <- read_int(row_size$raw,
                             if(u64) 72 else 36,
                             if(u64) 8  else 4)
    col_count_p2 <- read_int(row_size$raw,
                             if(u64) 80 else 40,
                             if(u64) 8  else 4)
    row_count_fp <- read_int(row_size$raw,
                             if(u64) 120 else 60,
                             if(u64) 8   else 4)

    %}

    methods
        function obj = row_size_subheader(bytes,is_u64)
            obj.bytes = bytes;


            %1:4   - signature
            %5:20  - unknown5

            obj.unknown5 = bytes(5:20);
            obj.row_length = double(typecast(bytes(21:24),'uint32'));
            obj.total_row_count = double(typecast(bytes(25:28),'uint32'));
            obj.unknown29 = bytes(29:36);
            obj.col_count_p1 = double(typecast(bytes(37:40),'uint32'));
            obj.col_count_p2 = double(typecast(bytes(41:44),'uint32'));

            obj.unknown45 = bytes(45:52);

            obj.page_length = double(typecast(bytes(53:56),'uint32'));

            obj.unknown57 = bytes(57:60);

            %AKA: page_row_count
            obj.max_row_count_on_mix_page = double(typecast(bytes(61:64),'uint32'));
            
            %65:72 - FF
            %could verify all == 255

            %73:220 - all zeros
            %221:224 - page signature again
            %225:264 - all zeros
            %265:268
            %269:270 - 
            %271:272 - zeros
            obj.n_pages_subheader_data = double(typecast(bytes(273:276),'uint32'));
            
            obj.length_creator_software_string = double(typecast(bytes(355:356),'uint16'));

            obj.length_creator_PROC_step_name = double(typecast(bytes(379:380),'uint16'));

            obj.max_length_column_names = double(typecast(bytes(423:426),'uint32'));
            obj.max_length_columns_labels = double(typecast(bytes(425:428),'uint32'));

        end
    end
end