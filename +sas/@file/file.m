classdef file < handle
    %
    %   Class:
    %   sas.file
    %
    %   https://github.com/WizardMac/ReadStat
    %
    %       - sas_read_header
    %       - 
    %
    %   https://cran.r-project.org/web/packages/sas7bdat/vignettes/sas7bdat.pdfv
    %   https://github.com/BioStatMatt/sas7bdat
    %   https://github.com/pandas-dev/pandas/blob/main/pandas/io/sas/sas7bdat.py
    %   https://github.com/pandas-dev/pandas/blob/main/pandas/io/sas/sas_constants.py
    %   https://github.com/WizardMac/ReadStat/blob/dev/src/sas/readstat_sas7bdat_read.c
    %   

    properties
        header
        n_pages
        first_page
        columns
    end

    methods
        function obj = file(file_path)
            %Open file
            fid = fopen(file_path,'r');

            %Header parse
            h = sas.header(fid);
            obj.header = h;

            obj.n_pages = h.page_count;
            all_pages = cell(1,obj.n_pages);

            %Pass 1 - check signatures, are we done to make column?
            p = sas.page(fid,h);
            obj.first_page = p;

            if any(p.signature_subheader.page_last_appear > 1)
                error('Unhandled case')
            end

            formats = p.format_subheaders;
            n_columns = length(formats);
            cols = cell(1,n_columns);
            for i = 1:n_columns
                cols{i} = sas.column(i,formats(i),p.col_name_headers,...
                    p.col_text_headers,p.col_attr_headers);
            end

            obj.columns = [cols{:}];

            keyboard

            for i = 2:obj.n_pages
                all_pages{i} = p;
                keyboard
            end

            
        end
    end
end