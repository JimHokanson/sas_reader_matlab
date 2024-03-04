classdef row_size_subheader < handle
    %
    %   Class:
    %   sas.row_size_subheader
    %
    %   https://github.com/WizardMac/ReadStat/blob/dev/src/sas/readstat_sas7bdat_read.c#L231

    properties
        bytes
        row_length %RL
        total_row_count %TRC
        col_count_p1
        col_count_p2
        max_row_count_on_mix_page
        n_pages_subheader_data %NPSHD
        max_length_column_names
        max_length_columns_labels
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

            obj.row_length = double(typecast(bytes(21:24),'uint32'));
            obj.total_row_count = double(typecast(bytes(25:28),'uint32'));
            obj.col_count_p1 = double(typecast(bytes(37:40),'uint32'));
            obj.col_count_p2 = double(typecast(bytes(41:44),'uint32'));
            obj.max_row_count_on_mix_page = double(typecast(bytes(61:64),'uint32'));
            obj.n_pages_subheader_data = double(typecast(bytes(272:275),'uint32'));
            obj.max_length_column_names = double(typecast(bytes(423:426),'uint32'));
            obj.max_length_columns_labels = double(typecast(bytes(425:428),'uint32'));

        end
    end
end