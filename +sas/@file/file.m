classdef file < handle
    %
    %   Class:
    %   sas.file
    %
    %   See Also
    %   --------
    %   sas.readFile
    %   sas.file>readDataHelper
    %   sas.file>rowsToData

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
        data_start_per_page %for fseek
        n_rows_per_page

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
            %   Our strategy is to have a single "handle" object that gets
            %   passed from page to page and that gets populated as
            %   file-level information comes in and that is utilized as
            %   required (when new data are encountered). We currently
            %   assume that all relevant population is done prior to any 
            %   utilization that requires that populated info.

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
            %   Current reading approach (may change):
            %   - All subheaders on a page are parsed, this includes
            %   compressed data as well as uncompressed data that is
            %   interleaved with the compressed data.
            %   - Any sections that are just uncompressed data are just
            %   noted as such. In particular the start of the data and the
            %   # of rows are logged.

            obj.n_pages = file_header.page_count;
            all_pages = cell(1,obj.n_pages);

            data_starts = zeros(1,obj.n_pages);
            data_n_rows = zeros(1,obj.n_pages);

            for i = 1:obj.n_pages
                p = sas.page(fid,file_header,i,obj.has_deleted_rows,...
                    obj.logger,obj.subheaders);
                data_starts(i) = p.header.data_block_start;
                data_n_rows(i) = p.header.data_block_count;
                obj.has_deleted_rows = obj.has_deleted_rows || p.has_deleted_rows;
                all_pages{i} = p;
            end

            obj.all_pages = [all_pages{:}];

            obj.data_start_per_page = data_starts;
            obj.n_rows_per_page = data_n_rows;

            %Column extraction
            %------------------------------------------------
            if obj.subheaders.n_columns ~= 0
                obj.columns = obj.subheaders.extractColumns(obj.header);
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
            %   This is currently a pain point. If one page has delete
            %   information but another does not it becomes somewhat
            %   awkward to handle the mix. Thus here if one page has the 
            %   delete info we make sure all pages do.
            %
            %   TODO: I think ideally this would be in the page
            %   methods
            %       - createNullDeleteInfo()
            %
            %   Example files of where this happens?
            %   

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
        function t = head(obj,stop_row)
            %
            %   t = head(obj,*stop_row)
            %
            %   Inputs
            %   ------
            %   stop_row : default 5
            %       By default we show only the first 5 rows
            %
            %   See Also
            %   --------
            %   sas.file>tail

            arguments
                obj
                stop_row = 5;
            end

            if stop_row > obj.n_rows
                stop_row = obj.n_rows;
            end
            if stop_row == 0
                start_row = 0;
            else
                start_row = 1;
            end

            t = obj.readData('start_stop_rows',[start_row stop_row]);
        end
        function t = tail(obj,n_rows_back)
            %
            %   t = tail(obj,*stop_row)
            %
            %   Inputs
            %   ------
            %   n_rows_back : default 5
            %       By default we show only the last 5 rows
            %
            %   See Also
            %   --------
            %   sas.file>head

            arguments
                obj
                n_rows_back = 5;
            end

            stop_row = obj.n_rows;
            start_row = stop_row - n_rows_back + 1;

            if start_row < 1
                if obj.n_rows == 0
                    start_row = 0;
                else
                    start_row = 1;
                end
                stop_row = obj.n_rows;
            end

            t = obj.readData('start_stop_rows',[start_row stop_row]);
        end
        function output = readData(obj,varargin)
            %X Extracts data from the file
            %
            %   output = readData(obj,varargin)
            %
            %   Optional Inputs
            %   ---------------
            %   columns_ignore: cellstr or string array
            %   columns_keep : cellstr or string array
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
            %   f = sas.file(fp);
            %   t = f.readData('start_stop_rows',[1000 2000])
            %
            %   %2) Keeping only certain columns
            %   t = f.readData('columns_keep',["datetime","value"]);
            %       %or equivalently:
            %   t = f.readData('columns_keep',{'datetime','value'});
            %       %or equivalently:
            %   options = sas.read_data_options(); %() is optional
            %   options.columns_keep = ["datetime","value"];
            %   t = f.readData(options);
            %
            %   %3) Removing certain columns
            %   t = f.readData('columns_ignore',["subjectid","facility"]);

            h = tic;

            in = sas.read_data_options();

            % in.columns_ignore = {};
            % in.columns_keep = {};
            % in.start_stop_rows = [];
            % in.output_type = 'table';
            in = sas.sl.in.processVarargin(in,varargin);
            
            if ~any(strcmp(in.output_type,{'table','struct'}))
                error('"output_type" option: %s, not recognized',...
                    in.output_type)
            end

            output = obj.readDataHelper(in);

            obj.last_data_read_parse_time = toc(h);
        end
    end
end

