classdef column_size_subheader < handle
    %
    %   Class:
    %   sas.column_size_subheader

    properties
        n_columns
    end

    %{
    col_size <- get_subhs(subhs, SUBH_COLSIZE)
    if(length(col_size) != 1)
        stop(paste("found", length(col_size),
            "column size subheaders where 1 expected", BUGREPORT))
    col_size <- col_size[[1]]
    col_count_6  <- read_int(col_size$raw,
                             if(u64) 8 else 4,
                             if(u64) 8 else 4)
    col_count    <- col_count_6

    %}

    methods
        function obj = column_size_subheader(bytes,is_u64)
            obj.n_columns = double(typecast(bytes(5:8),'uint32'));
        end
    end
end