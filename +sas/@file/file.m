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
    %   https://bitbucket.org/jaredhobbs/sas7bdat/src/master/
    %   This bitbucket code can also be found at:
    %   https://github.com/openpharma/sas7bdat
    %
    %   Pandas version:
    %   https://github.com/pandas-dev/pandas/blob/038976ee29ba7594a38d0729071ba5cb73a98133/pandas/io/sas/sas7bdat.py#L4
    %
    %   Java Impl
    %   https://github.com/epam/parso/blob/master/src/main/java/com/epam/parso/impl/SasFileParser.java
    %
    %
    %   SAS universal viewer:
    %   https://support.sas.com/downloads/browse.htm?cat=74
    %
    %   Online SAS viewer:
    %   https://welcome.oda.sas.com/

    properties
        fid
        header
        n_pages
        first_page
        all_pages
        columns

        %Subheaders
        row_size_sh
        col_size_sh
        sig_info_sh
        format_sh
        signature_sh
        text_sh
        name_sh
        attr_sh
        list_sh

        meta_parse_time
        data_starts %for fseek
        data_n_rows

        n_rows
        bytes_per_row

        has_compression
    end

    methods
        function obj = file(file_path)
            %Open file

            %TODO: Determine file size and switch approach
            %on how to read

            %fid = sas.fid(file_path);

            fid = fopen(file_path,'r');
            if fid == -1
                error('Unable to open the specified file:\n%s\n',file_path)
            end
            obj.fid = fid;

            h_tic = tic;

            %Header parse
            %-------------------------------------------------
            h = sas.header(fid);
            obj.header = h;

            %Meta data parsing (first few pages)
            %-------------------------------------------------
            obj.n_pages = h.page_count;
            all_pages = cell(1,obj.n_pages);

            data_starts = zeros(1,obj.n_pages);
            data_n_rows = zeros(1,obj.n_pages);

            p = sas.page(fid,h,1);
            obj.first_page = p;
            all_pages{1} = p;

            data_starts(1) = p.data_block_start;
            data_n_rows(1) = p.data_block_count;

            %   one_observation.sas7bdat
            %
            %   Good example where format specificatin spans 3 pages
            %   - see the    signature subheader

            %After the first page, we get any additional meta data pages
            %-----------------------------------------------------------
            mp = p; %main_page
            if any(p.signature_subheader.page_last_appear > 1)
                max_page = max(p.signature_subheader.page_last_appear);
                for i = 2:max_page
                    p = sas.page(fid,h,i);
                    all_pages{i} = p;
                    data_starts(i) = p.data_block_start;
                    data_n_rows(i) = p.data_block_count;
                    mp.row_size_subheader = [mp.row_size_subheader p.row_size_subheader];
                    mp.col_size_subheader = [mp.col_size_subheader p.col_size_subheader];
                    mp.signature_subheader = [mp.signature_subheader p.signature_subheader];
                    mp.format_subheaders = [mp.format_subheaders p.format_subheaders];
                    mp.col_text_headers = [mp.col_text_headers p.col_text_headers];

                    %Note, the col_attr_headers has an array as a property
                    %rather than an array of objects. Thus we need to
                    %merge the property arrays, rather than simply
                    %concatenating the objects.
                    mp.col_attr_headers = merge(mp.col_attr_headers,p.col_attr_headers);
                    mp.col_name_headers = [mp.col_name_headers p.col_name_headers];
                    mp.col_list_headers = [mp.col_list_headers p.col_list_headers];
                end

                next_page = max_page + 1;
            else
                next_page = 2;
            end

            obj.row_size_sh = mp.row_size_subheader;
            obj.col_size_sh = mp.col_size_subheader;
            obj.sig_info_sh = mp.signature_subheader;

            obj.format_sh = mp.format_subheaders;
            obj.signature_sh = mp.signature_subheader;
            obj.text_sh = mp.col_text_headers;
            obj.name_sh = mp.col_name_headers;
            obj.attr_sh = mp.col_attr_headers;
            obj.list_sh = mp.col_list_headers;


            %TODO: Verify length assumptions
            %Only 1 row_size_subheader, col_size_subheader, signature_subheader


            %Creation of the column entries
            %----------------------------------------------
            %
            %   We should now have enough meta data to be able to creat the
            %   column entries.
            formats = mp.format_subheaders;
            n_columns = length(formats);
            cols = cell(1,n_columns);
            for i = 1:n_columns
                cols{i} = sas.column(i,formats(i),mp.col_name_headers,...
                    mp.col_text_headers,mp.col_attr_headers);
            end
            obj.columns = [cols{:}];


            %Processing of the remaining pages
            %----------------------------------------------------------
            %- Note, I'm assuming all meta data is done
            %- Is there a file where they add meta data at the end?
            for i = next_page:obj.n_pages
                p = sas.page(fid,h,i);
                data_starts(i) = p.data_block_start;
                data_n_rows(i) = p.data_block_count;
                all_pages{i} = p;
                %TODO: Verify no meta data added here ...
            end

            obj.all_pages = [all_pages{:}];

            obj.bytes_per_row = obj.row_size_sh.row_length;
            obj.n_rows = obj.row_size_sh.total_row_count;

            obj.data_starts = data_starts;
            obj.data_n_rows = data_n_rows;

            obj.has_compression = any([obj.all_pages.has_compressed]);

            obj.meta_parse_time = toc(h_tic);

        end
        function output = readAllData(obj,varargin)


            in.output_type = 'table';
            in = sas.sl.in.processVarargin(in,varargin);

            if ~any(strcmp(in.output_type,{'table','struct'}))
                error('"output_type" option: %s, not recognized',in.output_type)
            end

            %Read all data into memory
            %-----------------------------------------
            if obj.has_compression
                all_p = obj.all_pages;
                temp = [all_p.comp_data_rows];
                temp_data = [temp{:}];
            else
                n_reads = obj.n_pages;
                %Note the "2" at the end of the variables is simply to avoid
                %MATLAB complaining about local variables intead of properties
                bytes_per_row2 = obj.bytes_per_row;

                %Note, this approach will double the memory requirements
                %1) initial data array
                %2) output data
                %
                %Benefits of this approach:
                %1) We do all of the conversion (all rows) in one step
                %rather than per row
                %
                %
                %Storage:
                %
                %   a1  a2  a3   -> a,b,c -> different columns
                %   a1  a2  a3   -> 1,2,3 -> first sample, 2nd sample, etc.
                %   b1  b2  b3
                %   b1  b2  b3
                %
                %   This approach allows us to quickly grab a column's data,
                %   then do a conversion since each column in our temporary
                %   storage contains the bytes for one value
                %
                temp_data = zeros(bytes_per_row2,obj.n_rows,'uint8');

                data_n_rows2 = obj.data_n_rows;
                data_starts2 = obj.data_starts;
                fid2 = obj.fid;
                I2 = 0;
                for i = 1:n_reads
                    n_bytes_read = data_n_rows2(i)*bytes_per_row2;
                    if n_bytes_read == 0
                        continue
                    end
                    fseek(fid2,data_starts2(i),"bof");
                    I1 = I2 + 1;
                    I2 = I2 + n_bytes_read;
                    temp_data(I1:I2) = fread(fid2,n_bytes_read,"*uint8")';
                end
            end

            %Extraction of
            %-------------------------------------------------
            c = obj.columns;
            c_widths_m1 = [c.column_width]-1;
            c_offsets = [c.data_row_offset]+1;
            c_is_numeric = [c.is_numeric];
            c_formats = {c.format};
            n_columns = length(c);
            n_rows2 = obj.n_rows;

            s = struct('id',num2cell(1:n_columns),'name',{c.name},...
                'label',{c.label},'values',[]);

            for i = 1:n_columns
                I1 = c_offsets(i);
                I2 = c_offsets(i)+c_widths_m1(i);
                if c_is_numeric(i)
                    column_data_bytes = zeros(8,n_rows2,'uint8');
                    column_data_bytes(8-c_widths_m1(i):8,:) = temp_data(I1:I2,:);
                    s(i).values = typecast(column_data_bytes(:),'double');
                    switch c_formats{i}
                        case ''
                            %done
                        case 'DATETIME'
                            %
                            %   seconds since 01/01/1960
                            d_origin = datetime(1960,1,1);
                            s(i).values = d_origin + seconds(s(i).values);
                        case 'DATE'
                            %
                            %   days since 01/01/1960

                            d_origin = datetime(1960,1,1);
                            s(i).values = d_origin + days(s(i).values);
                        case 'MMDDYY'
                            d_origin = datetime(1960,1,1);
                            s(i).values = d_origin + days(s(i).values);
                            %Not correct ...
                            %temp2 = d_origin + seconds(s(i).values);


                        case 'TIME'
                            %
                            %   seconds since midnight
                            %
                            %   ?? What to do here?
                        otherwise
                            error('Unrecognized format')

                    end
                else
                    %Transpose makes each row a string
                    %
                    %**** Ideally we would do this in C and avoid transpose
                    %and temporary operations

                    column_data_bytes = temp_data(I1:I2,:)';
                    %TODO: encoding
                    %native2unicode
                    %TODO: remove trailing spaces ...
                    temp = string(char(column_data_bytes));
                    s(i).values = strtrim(temp);
                end
            end

            %Output processing
            %------------------------------------
            switch in.output_type
                case 'table'
                    %TODO: Add in labels to output.Properties.VariableDescriptions
                    %Add in column names even if empty table
                    output = table;
                    for i = 1:length(s)
                        name = s(i).name;
                        output.(name) = s(i).values;
                    end
                case 'struct'
                    output = s;
                    %Nothing to do
                otherwise
                    %- If we reach this we have an error in the code
                    %  because we do this check as well at the top
                    error('Unhandled exception')
            end

        end
    end
end