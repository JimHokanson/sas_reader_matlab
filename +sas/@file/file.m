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
        Property1
    end

    methods
        function obj = file(file_path)
            fid = fopen(file_path,'r');
            h = sas.header(fid);

            n_pages = h.page_count;
            all_pages = cell(1,n_pages);
            for i = 1:n_pages
                all_pages{i} = sas.page(fid,h);
            end

            keyboard
        end
    end
end