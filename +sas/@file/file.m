classdef file < handle
    %
    %   Class:
    %   sas.file
    %
    %   See Also
    %   --------
    %   sas.readFile

    properties
        file_path
        fid

        header sas.header

        n_pages
        all_pages sas.page
        columns sas.column
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
        logger sas.logger
    end

    methods
        function obj = file(file_path)
            %
            %   Loads the file meta data, setting up future data reads

            h_tic = tic;

            obj.file_path = file_path;
            obj.logger = sas.logger;
            [~,name] = fileparts(file_path);
            obj.logger.name = name;

            %Open file
            %-------------------------------
            fid = fopen(file_path,'r');
            if fid == -1
                error('Unable to open the specified file:\n%s\n',file_path)
            end
            obj.fid = fid;

            %Header parse
            %-------------------------------------------------
            file_header = sas.header(fid);
            obj.header = file_header;


            %Subheader initialization
            %--------------------------------------------------
            %
            %   This was a bit surprising that some of the pages (often
            %   just the 1st) contain information which are necessary for
            %   parsing the rest of the pages.
            %
            %   This is in contrast to a file structure which puts that
            %   type of information in the main header.
            %   
            obj.subheaders = sas.subheaders(obj,fid,file_header.is_u64,...
                file_header.page_length,obj.logger);

            %Page parsing
            %-------------------------------------------------
            %
            %   Note initially I was using one of the subheaders to 
            %   only parse meta data pages but one file didn't write this
            %   info properly and eventually I just settled on reading all
            %   pages.
            %
            %   Current reading approach (may change)
            %   - All subheaders on a page are parsed, this includes
            %   compressed data as well as uncompressed data that is
            %   interleaved with the compressed data.
            %   - Any sections that are just uncompressed data are just
            %   noted as such. In particular the start of the data and the
            %   # of rows are logged.

            obj.n_pages = double(file_header.page_count);
            all_pages = cell(1,obj.n_pages);

            data_starts = zeros(1,obj.n_pages);
            data_n_rows = zeros(1,obj.n_pages);

            for i = 1:obj.n_pages
                p = sas.page(fid,file_header,i,obj.logger,obj.subheaders);
                data_starts(i) = p.header.data_block_start;
                data_n_rows(i) = p.header.data_block_count;
                obj.has_deleted_rows = obj.has_deleted_rows || p.has_deleted_rows;
                all_pages{i} = p;
            end

            obj.all_pages = [all_pages{:}];

            obj.data_starts = data_starts;
            obj.data_n_rows = data_n_rows;

            %Column extraction
            %------------------------------------------------
            if obj.subheaders.n_columns ~= 0
                obj.columns = obj.subheaders.extractColumns();
                obj.column_names = {obj.columns.name}';
            end

            %Hoisting up of relevant info
            %--------------------------------------------
            obj.bytes_per_row = obj.subheaders.row_length;
            obj.n_rows = obj.subheaders.n_rows;

            %Moved this into the page parsing
            obj.has_compression = any([obj.all_pages.has_compressed]);

            %Delete mask checking
            %--------------------------------------------
            %
            %   This is currently a pain point.

            has_delete_mask = [obj.all_pages.has_delete_mask];
            any_delete = any(has_delete_mask);
            if any_delete
                obj.has_deleted_rows = any_delete;
                %all_delete = all(has_delete_mask);

                %Eventually I had hoped to never have to manually do
                %this. I should create a list of deleted files.
                I = find(~has_delete_mask);
                if ~isempty(I)
                    obj.logger.delete_mask_fix = true;
                    for i = 1:length(I)
                        curI = I(i);
                        p = obj.all_pages(curI);
                        p.has_delete_mask = true;
                        if p.has_compressed
                            p.delete_mask = false(1,size(p.comp_data_rows,2));
                        else
                            p.delete_mask = false(1,p.data_block_count);
                        end
                    end
                end
            end

            obj.meta_parse_time = toc(h_tic);

        end
        function output = readRowFilteredData(obj,varargin)
            error('Not yet implemented')
            %plan is to allow retrieving rows based on a callback 
            %
            %e.g. readRowFilteredData(column_to_filter,@(x) x > 100)
        end
        function output = readData(obj,varargin)
            %X Extracts data from the file
            %
            %   output = readData(obj,varargin)
            %
            %   Optional Inputs
            %   ---------------
            %   output_type : default 'table'
            %       - 'table'
            %       - 'struct' - TODO: document
            %   start_stop_rows : default not used
            %       [start_row stop_row] 1-based
            %
            %   
            %   Examples
            %   --------
            %   %1) Read rows 1000 through 2000 as a table
            %   output = f.readData('start_stop_rows',[1000 2000])
            %
            %   

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

