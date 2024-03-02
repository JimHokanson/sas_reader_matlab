classdef row_size_subheader < handle
    %
    %   Class:
    %   sas.row_size_subheader
    %
    %   https://github.com/WizardMac/ReadStat/blob/dev/src/sas/readstat_sas7bdat_read.c#L231

    properties
        row_length
        total_row_count %20
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
        function obj = row_size_subheader(bytes)

            keyboard
        end
    end
end