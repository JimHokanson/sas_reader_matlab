classdef subheaders < handle
    %
    %   Class:
    %   sas.subheaders
    %
    %   This class does two things:
    %   1) processes page subheaders
    %   2) holds onto special subheaders
    %   
    %
    %   See Also
    %   --------
    %   sas.subheader_pointers
    %   sas.page

    properties
        logger sas.logger
        parent sas.file
        is_u64
        fid
        page_length

        file_has_deleted_rows

        row_size sas.row_size_subheader
        col_size sas.column_size_subheader
        signature sas.signature_counts_subheader
        col_format sas.column_format_subheader
        col_text sas.column_text_subheader
        col_name sas.column_name_subheader
        col_attr sas.column_attributes_subheader
        col_list sas.column_list_subheader
        unknowns = {}

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
        function obj = subheaders(file,fid,is_u64,page_length,logger)
            obj.logger = logger;
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
            %   Outputs
            %   -------
            %   sub_headers
            %   comp_data_rows : 
            %       Due to the way the data are stored this is actually
            %       compressed with the occassional 

            %This call is just to remove the nesting ...
            %
            %   Could move it to its own file ...
            [sub_headers, comp_data_rows] = h__processPageSubheaders(obj,s,page,bytes);
        end
        function columns = extractColumns(obj,file_header)
            %Creation of the column entries
            %----------------------------------------------
            %
            %   We should now have enough meta data to be able to creat the
            %   column entries.
            formats = obj.col_format;
            cols = cell(1,obj.n_columns);
            for i = 1:obj.n_columns
                cols{i} = sas.column(i,formats(i),obj.col_name,...
                    obj.col_text,obj.col_attr,file_header);
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

function [sub_headers, uncompressed_data] = h__processPageSubheaders(...
    obj,s,page,bytes)
%
%
%   Inputs
%   ------
%   s : sas.subheader_pointers
%   page : sas.page
%   bytes : uint8 array

sub_offsets = s.offsets;
sub_lengths = s.lengths;
sub_comp_flags = s.comp_flags;

%logger = obj.logger;
%page_type_info = page.page_type_info;


%List
%----------------------------------------------
% 'F6F6F6F6' - 4143380214 - column-size subheader, n=1?
% 'F7F7F7F7' - 4160223223 - row-size subheader, n=1?
% 
% 'FFFFFBFE' - 4294966270 - column-format, n=1 per column
% 'FFFFFC00' - 4294966272 - signature counts
% 'FFFFFFF8' - 4294967288
% 'FFFFFFF9' - 4294967289 - column WTF3 - seen in sigs subheader
% 'FFFFFFFA' - 4294967290 - column WTF2 - seen in sigs subheader
% 
% 'FFFFFFFB' - 4294967291 - column WTF - seen in sigs subheader
% 'FFFFFFFC' - 4294967292 - column attributes
% 'FFFFFFFD' - 4294967293 - column text, n >= 1?
% 'FFFFFFFE' - 4294967294 - column list
% 'FFFFFFFF' - 4294967295 - column name, n = ???

%   #define SAS_SUBHEADER_SIGNATURE_COLUMN_MASK    0xFFFFFFF8
%   /* Seen in the wild: FA (unknown), F8 (locale?) */

n_subs = length(s.offsets);

%Truncation check
%------------------------------------------------------------------
%For whatever reason the last "subheader" is set to be null or "truncated"
%
%   We check for this here so that we don't over allocate and need to
%   delete

I = find(sub_comp_flags == 1);
if length(I) > 1
    error('Expecting only 1 truncated flag')
elseif length(I) == 1
    if I ~= n_subs
        error('Expecting truncated subheader at end of subheaders')
    else
        n_subs = n_subs - 1;
    end
end

%What is this
%------------------------------------------------
%q_del_pandas
if any(sub_comp_flags == 5)
    %keyboard
end

%Compression initialization
%--------------------------------------------------
Ic = 0;
compression_flags_present = false;
if any(sub_comp_flags == 4)
    %
    %   Note currently we store uncompresse with compressed
    %
    %   Hard to tell which entries are data rows ...

    if isempty(obj.row_length)
        %
        compression_flags_present = true;
    else
        uncompressed_data = zeros(obj.row_length,n_subs,'uint8');
    end
else
    uncompressed_data = [];
end


%Other allocation
%-----------------------------------------
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

    try
        b2 = bytes(offset:offset+n_bytes_m1);
    catch
        error('error extracting subheader bytes')
    end

    %Check for an empty last pointer
    %-----------------------------------------
    if isempty(b2)
        error('Unexpected empty subheader')
    end

    %Compressed data in header
    %------------------------------------
    if sub_comp_flags(i) == 4
        Ic = Ic + 1;
        if obj.compression_mode == "rdc"
            %TODO: Fix mex 
            uncompressed_data(:,Ic) = sas.utils.extractRDC(b2,obj.row_length);
        elseif obj.compression_mode == "rle"
            uncompressed_data(:,Ic) = sas.utils.extractRLE(b2,obj.row_length);
        else
            %
            %   Not sure if there is somewhere else to extract the
            %   compression type but it seems like the "default" is binary
            %
            %   files:
            %   - fts0003.sas7bdat
            obj.logger.implied_rdc = true;
            uncompressed_data(:,Ic) = sas.utils.extractRDC(b2,obj.row_length);
        end
        continue
    elseif sub_comp_flags(i) == 5
        %ignore
        continue
    end

    header_signature = typecast(bytes(offset:offset+3),'uint32');
    % if obj.is_u64
    %     h2 = typecast(bytes(offset+4:offset+7),'uint32');
    % else
    %     h2 = -1;
    % end

    sigs(i) = header_signature;
    switch header_signature
        case 0
            page.has_uncompressed2 = true;
            obj.logger.zero_sig = true;
            Ic = Ic + 1;
            uncompressed_data(:,Ic) = b2;
            s.logSectionType(i,'0-sub',0);
        case 4143380214 %column-size subheader, F6F6F6F6
            page.has_meta = true;
            temp = sas.column_size_subheader(b2,obj.is_u64);
            obj.setColSizeSubheader(temp);
            sub_headers{i} = temp;
            s.logSectionType(i,'col-size',header_signature);
        case 4160223223 %row-size subheader, F7F7F7F7
            page.has_meta = true;
            temp = sas.row_size_subheader(b2,obj.is_u64);
            obj.setRowSizeSubheader(temp);
            sub_headers{i} = temp;
            s.logSectionType(i,'row-size',header_signature);
            %
            %   Sometimes we have compressed data on the same page as the
            %   row-size subheader but we can't initialize the output until
            %   we know the final row length. Note that thus far this
            %   subheader has always come before the compressed data.
            %   Coming afterwards would likely indicate an error with the
            %   writer.
            if compression_flags_present
                obj.logger.delayed_compression_initialization = true;
                uncompressed_data = zeros(obj.row_length,n_subs,'uint8');
            end
        case 4294966270  %column-format subheader, FFFFFBFE
            %n = 1 per column
            page.has_meta = true;
            format_I = format_I + 1;
            sub_headers{i} = sas.column_format_subheader(b2,obj.is_u64);
            format_headers(format_I) = sub_headers(i);
            s.logSectionType(i,'col-format',header_signature);
        case 4294967290
            page.has_meta = true;
            %FFFFFFFA - not sure what this is ...
            %
            %   seen with AMD page type
            %   fts0003.sas7bdat

            obj.unknowns{end+1} = b2;
            obj.logger.fa_page_type = page.page_type_info.page_type;

            s.logSectionType(i,'unknown FFFFFFFA',header_signature);
        case 4294966272 %signature counts
            page.has_meta = true;
            %When a particular subheader first and last appears
            temp = sas.signature_counts_subheader(b2,obj.is_u64);
            obj.setSignatureSubheader(temp);
            sub_headers{i} = temp;
            s.logSectionType(i,'sig-counts',header_signature);
        case 4294967292 %-- COLUMN ATTRIBUTES
            page.has_meta = true;
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
            s.logSectionType(i,'col-attr',header_signature);
        case 4294967293 %-- COLUMN TEXT
            page.has_meta = true;
            sub_headers{i} = sas.column_text_subheader(b2,obj.is_u64,obj.row_size);

            %Do we ever have more than 1 of these?
            %Does compression ever differ?

            %text but not linked to any column
            obj.col_text = [obj.col_text sub_headers{i}];
            s.logSectionType(i,'col-text',header_signature);
            obj.compression_mode = sub_headers{i}.compression_type;
        case 4294967294 %-- COLUMN LIST
            page.has_meta = true;
            sub_headers{i} = sas.column_list_subheader(b2,obj.is_u64);
            obj.col_list = [obj.col_list sub_headers{i}];
            %Unclear what this is ...
            s.logSectionType(i,'col-list',header_signature);
        case 4294967295 %-- COLUMN NAME
            page.has_meta = true;
            sub_headers{i} = sas.column_name_subheader(b2,obj.is_u64);
            obj.col_name = [obj.col_name sub_headers{i}];
            s.logSectionType(i,'col-name',header_signature);
        otherwise
            %
            %   Note this tends to come after sections with
            %   a signature of 0 or with compressed data
            %
            %dates_binary.sas7bdat - u64
            %dates_longname_binary.sas7bdat - u64
            %doubles.sas7bdat, doubles2.sas7bdat - not u64
            
            %logger.unrecognized_sigs = [logger.unrecognized_sigs; header_signature; h2];
            
            page.has_uncompressed2 = true;
            s.logSectionType(i,'uncompressed2',header_signature);
            %Note, this is risky as we may have legit header
            %although if that happens we will most likely get an error
            %due to the size mismatch
            Ic = Ic + 1;
            try
                uncompressed_data(:,Ic) = b2;
            catch
                error('Unrecognized signature for subheader')
            end
    end
end

if size(uncompressed_data,2) > Ic
    uncompressed_data(:,Ic+1:end) = [];
end

obj.col_format = [obj.col_format format_headers{1:format_I}];


end