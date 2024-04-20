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
    %   https://cran.r-project.org/web/packages/sas7bdat/vignettes/sas7bdat.pdf
    %
    %   https://github.com/xiaodaigh/sas7bdat-resources/blob/master/README.md
    %

    properties
        file_path
        fid

        %sas.header
        header

        n_pages
        all_pages
        columns
        column_names

        %Subheaders
        subheaders sas.subheaders

        meta_parse_time
        data_starts %for fseek
        data_n_rows

        n_rows
        bytes_per_row

        has_compression
        has_deleted_rows = false

        last_data_read_parse_time
    end

    methods
        function obj = file(file_path)
            %
            %   Loads the file meta data, setting up future data reads

            h_tic = tic;

            obj.file_path = file_path;

            %Open file
            %-------------------------------
            %TODO: Determine file size and switch approach
            %on how to read

            %This object supports reading everything into memory
            %then acts like MATLAB's fid methods
            %fid = sas.fid(file_path);

            fid = fopen(file_path,'r');
            if fid == -1
                error('Unable to open the specified file:\n%s\n',file_path)
            end
            obj.fid = fid;

            %Header parse
            %-------------------------------------------------
            h = sas.header(fid);
            obj.header = h;

            %Meta data parsing (first few pages)
            %-------------------------------------------------
            obj.subheaders = sas.subheaders(obj,fid,h.is_u64,h.page_length);

            obj.n_pages = h.page_count;
            all_pages = cell(1,obj.n_pages);

            data_starts = zeros(1,obj.n_pages);
            data_n_rows = zeros(1,obj.n_pages);

            i = 1;
            p = sas.page(fid,h,i,obj,obj.subheaders);
            all_pages{1} = p;

            data_starts(1) = p.header.data_block_start;
            data_n_rows(1) = p.header.data_block_count;

            %   one_observation.sas7bdat
            %
            %   Above file is good example where format specificatin spans
            %   3 pages
            %   - see the signature subheader

            %After the first page, we get any additional meta data pages
            %-----------------------------------------------------------
            sig_sh = obj.subheaders.signature;
            if isempty(sig_sh)
                next_page = 2;
            else
                if sig_sh.last_meta_page > 1
                    max_page = sig_sh.last_meta_page;
                    if max_page > obj.n_pages
                        max_page = obj.n_pages;
                    end
                    for i = 2:max_page
                        p = sas.page(fid,h,i,obj,obj.subheaders);
                        all_pages{i} = p;
                        data_starts(i) = p.header.data_block_start;
                        data_n_rows(i) = p.header.data_block_count;
                    end
                    next_page = max_page + 1;
                else
                    next_page = 2;
                end
            end

            %Column extraction
            %-------------------------------------------------
            %obj.columns = obj.subheaders.extractColumns();
            %obj.column_names = {obj.columns.name}';

            %Processing of the remaining pages
            %----------------------------------------------------------
            for i = next_page:obj.n_pages
                p = sas.page(fid,h,i,obj,obj.subheaders);
                data_starts(i) = p.header.data_block_start;
                data_n_rows(i) = p.header.data_block_count;
                all_pages{i} = p;
            end

            obj.columns = obj.subheaders.extractColumns();
            obj.column_names = {obj.columns.name}';

            obj.all_pages = [all_pages{:}];

            obj.bytes_per_row = obj.subheaders.row_length;
            obj.n_rows = obj.subheaders.n_rows;

            obj.data_starts = data_starts;
            obj.data_n_rows = data_n_rows;

            %Moved this into the page parsing
            obj.has_compression = any([obj.all_pages.has_compressed]);

            has_delete_mask = [obj.all_pages.has_delete_mask];
            any_delete = any(has_delete_mask);
            if any_delete
                obj.has_deleted_rows = any_delete;
                all_delete = all(has_delete_mask);
                if ~all_delete
                    keyboard
                    error('Unhandled case, some pages have delete instructions')
                end
            end

            obj.meta_parse_time = toc(h_tic);

        end
        function output = readRowFilteredData(obj,varargin)

        end
        function output = readData(obj,varargin)
            %
            %
            %   output = readData(obj,varargin)
            %
            %   Outputs
            %   -------
            %   output_type : default 'table'
            %       - 'table'
            %       - 'struct'
            %   start_stop_rows

            h = tic;

            in.start_stop_rows = [];
            in.output_type = 'table';
            in = sas.sl.in.processVarargin(in,varargin);
            
            if ~any(strcmp(in.output_type,{'table','struct'}))
                error('"output_type" option: %s, not recognized',in.output_type)
            end

            output = obj.readDataHelper(in);

            obj.last_data_read_parse_time = toc(h);

        end
    end
end

