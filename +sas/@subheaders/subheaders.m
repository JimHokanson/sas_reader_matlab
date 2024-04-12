classdef subheaders < handle
    %
    %   Class:
    %   sas.subheaders
    %
    %   See Also
    %   --------
    %   sas.subheader_pointers
    %   sas.page

    properties
        parent
        is_u64
        fid
        page_length

        row_size sas.row_size_subheader
        col_size sas.column_size_subheader
        signature sas.signature_counts_subheader
        col_format sas.column_format_subheader
        col_text sas.column_text_subheader
        col_name sas.column_name_subheader
        col_attr sas.column_attributes_subheader
        col_list sas.column_list_subheader

        row_length
        n_rows
        n_columns
        compression_mode = ""
    end

    properties (Constant)
       d = '------- important properties -------'
    end

    properties

    end

    methods
        function obj = subheaders(file,fid,is_u64,page_length)
            obj.parent = file;
            obj.is_u64 = is_u64;
            obj.fid = fid;
            obj.page_length = page_length;
        end
        function [sub_headers, comp_data_rows] = processPageSubheaders(obj,s,page,bytes)
            %
            %
            %   Utilizing the pointer info, process each sub-header. This
            %   includes information about the row size, column size, as
            %   well as information about the columns. It may also contain
            %   compresssed data.
            %
            %   Inputs
            %   ------
            %   s : sas.subheader_pointers
            %   page : sas.page
            %   bytes : uint8 array
            %
            %   

            sub_offsets = s.offsets;
            sub_lengths = s.lengths;
            sub_comp_flags = s.comp_flags;

            %TODO: preallocate
            comp_data_rows = {};

            %sub_types = s.type;

            %     'F6F6F6F6' - 4143380214 - column-size subheader, n=1?
            %     'F7F7F7F7' - 4160223223 - row-size subheader, n=1?
            %   
            %     'FFFFFBFE' - 4294966270 - column-format
            %     'FFFFFC00' - 4294966272 - signature counts
            %     'FFFFFFF9' - 4294967289 - column WTF3 - seen in sigs subheader
            %     'FFFFFFFA' - 4294967290 - column WTF2 - seen in sigs subheader
            %                  
            %     'FFFFFFFB' - 4294967291 - column WTF - seen in sigs subheader
            %     'FFFFFFFC' - 4294967292 - column attributes
            %     'FFFFFFFD' - 4294967293 - column text, n >= 1?
            %     'FFFFFFFE' - 4294967294 - column list
            %     'FFFFFFFF' - 4294967295 - column name, n = ???

            %   #define SAS_SUBHEADER_SIGNATURE_COLUMN_MASK    0xFFFFFFF8
            %   /* Seen in the wild: FA (unknown), F8 (locale?) */

            %This 100 is arbitrary

            n_subs = length(s.offsets);

            truncated = false;
            I = find(s.comp_flags == 1);
            if length(I) > 1
                error('Expecting only 1 truncated flag')
            elseif length(I) == 1
                if I ~= n_subs
                    error('Expecting truncated subheader at end of subheaders')
                else
                    n_subs = n_subs - 1;
                    truncated = true;
                end
            end

            %Note, this is an over-allocation but that's probably fine
            format_headers = cell(1,n_subs);
            format_I = 0;

            %Logic for readstat:
            %https://github.com/WizardMac/ReadStat/blob/887d3a1bbcf79c692923d98f8b584b32a50daebd/src/sas/readstat_sas7bdat_read.c#L875

            
            sub_headers = cell(1,n_subs);
            sigs = zeros(1,n_subs);
            for i = 1:n_subs
                offset = sub_offsets(i)+1;
                n_bytes_m1 = sub_lengths(i)-1;
                b2 = bytes(offset:offset+n_bytes_m1);

                %Check for an empty last pointer
                %-----------------------------------------
                if isempty(b2)
                    %seems to happen when sub_comp_flags(i) is 1
                    %and only at the end. If present, ignore data
                    %although BC is 0
                    %Not sure why this is happening
                    if i == n_subs
                        break
                    else
                        error('Unhandled case')
                    end
                end
                
                % if i >= 17
                %     disp(i)
                %     keyboard
                % end

                %Compressed data in header
                %------------------------------------
                if sub_comp_flags(i) == 4
                    if obj.compression_mode == "rdc"
                        comp_data_rows{end+1} = sas.utils.extractRDC(b2,obj.row_length);
                    elseif obj.compression_mode == "rle"
                        comp_data_rows{end+1} = sas.utils.extractRLE(b2,obj.row_length);
                    else
                        keyboard
                    end
                    continue
                end

                %Parso suggests that the first 4 bytes for u64 might be 
                %0 followed by the signature ...
                header_signature = typecast(bytes(offset:offset+3),'uint32');
            

                sigs(i) = header_signature;
                %https://github.com/WizardMac/ReadStat/blob/887d3a1bbcf79c692923d98f8b584b32a50daebd/src/sas/readstat_sas7bdat_read.c#L626
                %https://github.com/epam/parso/blob/3c514e66264f5f3d5b2970bc2509d749065630c0/src/main/java/com/epam/parso/impl/SasFileParser.java#L87
                switch header_signature
                    case 0
                        %see in dates_binary.sas7bdat
                        %- even after skipping ending 1
                        
                        %Where does this logic coem from? parso?
                        % % % if (sasFileProperties.isCompressed() && subheaderIndex == null && ...
                        %               (compression == COMPRESSED_SUBHEADER_ID || compression == 0) 
                        %                   && type == COMPRESSED_SUBHEADER_TYPE) {
                        % % %          subheaderIndex = SubheaderIndexes.DATA_SUBHEADER_INDEX;
                        % % %      }

                        %SASYZCRL
                        %dates_binary.sas7bdat
                        %
                        %   obj.compression_mode = 'rdc'

                        if obj.compression_mode == "rdc"
                            %Apparently this is just non-compressed data
                            comp_data_rows{end+1} = b2';
                        else
                            keyboard
                        end
                        %obj.sub_count_short = true;
                        %obj.n_subheaders = i - 1;
                        %sub_headers(i:end) = [];
                        
                        %error('Unhandled case')
                    case 4143380214 %column-size subheader
                        temp = sas.column_size_subheader(b2,obj.is_u64);
                        obj.setColSizeSubheader(temp);
                        sub_headers{i} = temp;
                        s.logSectionType(i,'col-size');
                    case 4160223223 %row-size subheader
                        temp = sas.row_size_subheader(b2,obj.is_u64);
                        obj.setRowSizeSubheader(temp);
                        sub_headers{i} = temp;
                        s.logSectionType(i,'row-size');
                    case 4294966270  %column-format subheader
                        %n = 1 per column
                        format_I = format_I + 1;
                        sub_headers{i} = sas.column_format_subheader(b2,obj.is_u64);
                        format_headers(format_I) = sub_headers(i);
                        %- format
                        %- label
                        s.logSectionType(i,'col-format');
                    case 4294966272 %signature counts
                        %When a particular subheader first and last appears
                        temp = sas.signature_counts_subheader(b2,obj.is_u64);
                        obj.setSignatureSubheader(temp);
                        sub_headers{i} = temp;
                        s.logSectionType(i,'sig-counts');
                    case 4294967292 %-- COLUMN ATTRIBUTES
                        %-----------------------------------------
                        sub_headers{i} = sas.column_attributes_subheader(b2,obj.is_u64);
                        %Note, the col_attr_headers has an array as a property
                        %rather than an array of objects. Thus we need to
                        %merge the property arrays, rather than simply
                        %concatenating the objects.
                        obj.col_attr = merge(obj.col_attr,sub_headers{i});


                        %The column attribute subheader holds
                        %information regarding the column offsets
                        %within a data row, the column widths, and the
                        %column types (either numeric or character).
                        s.logSectionType(i,'col-attr');
                    case 4294967293 %-- COLUMN TEXT
                        sub_headers{i} = sas.column_text_subheader(b2,obj.is_u64,obj.row_size);
                        
                        %Do we ever have more than 1 of these?
                        %Does compression ever differ?
                        
                        %text but not linked to any column
                        obj.col_text = [obj.col_text sub_headers{i}];
                        s.logSectionType(i,'col-text');
                        obj.compression_mode = sub_headers{i}.compression_type;
                    case 4294967294 %-- COLUMN LIST
                        sub_headers{i} = sas.column_list_subheader(b2,obj.is_u64);
                        obj.col_list = [obj.col_list sub_headers{i}];
                        %Unclear what this is ...
                        s.logSectionType(i,'col-list');
                    case 4294967295 %-- COLUMN NAME
                        sub_headers{i} = sas.column_name_subheader(b2,obj.is_u64);
                        obj.col_name = [obj.col_name sub_headers{i}];
                        s.logSectionType(i,'col-name');
                    otherwise
                        if obj.compression_mode == "rdc"
                            comp_data_rows{end+1} = b2';
                            continue
                        else
                            keyboard
                        end
                        error('Unrecognized header')
                end
            end

            obj.col_format = [obj.col_format format_headers{1:format_I}];

            
            
            
            

        end
        function columns = extractColumns(obj)
            %Creation of the column entries
            %----------------------------------------------
            %
            %   We should now have enough meta data to be able to creat the
            %   column entries.
            formats = obj.col_format;
            cols = cell(1,obj.n_columns);
            for i = 1:obj.n_columns
                cols{i} = sas.column(i,formats(i),obj.col_name,...
                    obj.col_text,obj.col_attr);
            end
            columns = [cols{:}];
        end
        function setSignatureSubheader(obj,value)
            if isempty(obj.signature)
                obj.signature = value;
            else
                error('sas_reader:signature_header_not_unique',...
                    'assumption violated, expecting single signature header')
            end
        end
        function setRowSizeSubheader(obj,value)
            %
            %   sas.row_size_subheader
            if isempty(obj.row_size)
                obj.row_size = value;
                obj.row_length = value.row_length;
                obj.n_rows = value.total_row_count;
            else
                error('sas_reader:row_size_header_not_unique',...
                    'assumption violated, expecting single row-size header')
            end
        end
        function setColSizeSubheader(obj,value)
            if isempty(obj.col_size)
                obj.col_size = value;
                obj.n_columns = value.n_columns;
            else
                error('sas_reader:col_size_header_not_unique',...
                    'assumption violated, expecting single col-size header')
            end
        end
    end
end