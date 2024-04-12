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
    %   Julia
    %   ------
    %   https://github.com/tk3369/SASLib.jl/blob/b84e18b052fa9a6f7a7283c5685ac987420b0c7e/src/SASLib.jl#L1445
    %
    %   R
    %   ----
    %   https://github.com/BioStatMatt/sas7bdat
    %
    %   C/C++
    %   -----
    %   https://github.com/jonashaag/sas7bdat
    %   https://github.com/WizardMac/ReadStat/blob/dev/src/sas/readstat_sas7bdat_read.c
    %
    %   https://bitbucket.org/jaredhobbs/sas7bdat/src/master/
    %   This bitbucket code can also be found at:
    %   https://github.com/openpharma/sas7bdat
    %
    %   https://github.com/olivia76/cpp-sas7bdat
    %
    %   Python
    %   ------
    %   Pandas version:
    %   https://github.com/pandas-dev/pandas/blob/038976ee29ba7594a38d0729071ba5cb73a98133/pandas/io/sas/sas7bdat.py#L4
    %
    %   Java
    %   ----
    %   Java Impl, Parso:
    %   https://github.com/epam/parso/blob/master/src/main/java/com/epam/parso/impl/SasFileParser.java
    %
    %   Go
    %   --
    %   https://github.com/kshedden/datareader
    %
    %   SAS universal viewer:
    %   https://support.sas.com/downloads/browse.htm?cat=74
    %
    %   Online SAS viewer:
    %   https://welcome.oda.sas.com/

    properties
        file_path
        fid

        %sas.header
        header

        n_pages
        p1
        all_pages
        columns

        %Subheaders
        subheaders sas.subheaders

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
            obj.p1 = p;
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
            if sig_sh.last_meta_page > 1
                max_page = sig_sh.last_meta_page;
                for i = 2:max_page
                    p = sas.page(fid,h,i,obj);
                    all_pages{i} = p;
                    data_starts(i) = p.header.data_block_start;
                    data_n_rows(i) = p.header.data_block_count;
                end
                next_page = max_page + 1;
            else
                next_page = 2;
            end

            %Column extraction
            %-------------------------------------------------
            obj.columns = obj.subheaders.extractColumns();

            %Processing of the remaining pages
            %----------------------------------------------------------
            for i = next_page:obj.n_pages
                p = sas.page(fid,h,i,obj,obj.subheaders);
                data_starts(i) = p.header.data_block_start;
                data_n_rows(i) = p.header.data_block_count;
                all_pages{i} = p;
            end

            obj.all_pages = [all_pages{:}];

            obj.bytes_per_row = obj.subheaders.row_length;
            obj.n_rows = obj.subheaders.n_rows;

            obj.data_starts = data_starts;
            obj.data_n_rows = data_n_rows;

            obj.has_compression = any([obj.all_pages.has_compressed]);

            any_delete = any([obj.all_pages.has_delete_mask]);
            if any_delete
                obj.has_deleted_rows = any_delete;
                all_delete = all([obj.all_pages.has_delete_mask]);
                if ~all_delete
                    error('Unhandled case')
                end
            end

            obj.meta_parse_time = toc(h_tic);

        end
        function output = readAllData(obj,varargin)


            h = tic;

            in.output_type = 'table';
            in = sas.sl.in.processVarargin(in,varargin);

            if ~any(strcmp(in.output_type,{'table','struct'}))
                error('"output_type" option: %s, not recognized',in.output_type)
            end

            has_deleted_rows2 = obj.has_deleted_rows;
            if obj.has_deleted_rows
                delete_mask = false(obj.n_rows,1);
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
                row2 = 0;
                for i = 1:n_reads
                    n_rows_cur_page = data_n_rows2(i);
                    n_bytes_read = n_rows_cur_page*bytes_per_row2;
                    if n_bytes_read == 0
                        continue
                    end
                    fseek(fid2,data_starts2(i),"bof");
                    I1 = I2 + 1;
                    I2 = I2 + n_bytes_read;
                    temp_data(I1:I2) = fread(fid2,n_bytes_read,"*uint8")';
                    if has_deleted_rows2
                        row1 = row2 + 1;
                        row2 = row2 + n_rows_cur_page;
                        delete_mask(row1:row2) = obj.all_pages(i).delete_mask(1:n_rows_cur_page);
                    end
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

                    %https://github.com/epam/parso/pull/86
                    switch c_formats{i}
                        case ''
                        case 'BEST'
                            %
                            %do nothing

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
                        case {'MMDDYY','YYMMDD'}
                            d_origin = datetime(1960,1,1);
                            s(i).values = d_origin + days(s(i).values);
                            %Not correct ...
                            %temp2 = d_origin + seconds(s(i).values);
                        case 'MINGUO'
                            %01/01/01 is January 1, 1912
                            %dates before January 1, 1912 are not valid
                            %{
                                  -17532   01/01/01
                                       0   0049/01/01
                                   20513   0105/02/09
                                  110404   0351/04/11
                            %}
                            %d_origin = datetime(1912,1,1);

                            %https://www.mathworks.com/help/matlab/matlab_oop/built-in-subclasses-with-properties.html
                            d_origin = datetime(1960,1,1);
                            wtf = d_origin + days(s(i).values);
                            %subclasssing datetime not allowed
                            %would need to create a custom datetime class
                            %wtf2 = sas.formats.minguo(wtf);
                            s(i).values = wtf;
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
                if has_deleted_rows2
                    s(i).values(delete_mask) = [];
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

            obj.last_data_read_parse_time = toc(h);

        end
    end
end