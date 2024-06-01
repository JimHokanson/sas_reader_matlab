function s = rowsToData(obj,temp_data,row_delete_mask,options)
%
%
%   This function converts rows of uncompressed binary data into
%   columns values (in retrospect this function could have a better name)
%  
%   Inputs
%   ------
%   temp_data : [n_row_bytes x n_rows]
%       This contains the uncompressed binary data that needs to be
%       translated to values.
%   row_delete_mask : [] or [n_rows]
%       If not empty specifies which rows should be deleted after the data
%       have been processed.
%   options : 
%       
%
%
%   See Also
%   --------
%   sas.file
%   sas.file>readDataHelper
%
%   Improvements
%   ------------
%   1) rename file to: binaryToValues()
%   2) improve type parsing support for datetime and time
%   3) finish encoding checks
%
%   File Name
%   ---------
%   sas.file>rowsToData

arguments
    obj sas.file
    temp_data
    row_delete_mask
    options sas.read_data_options
end

c = options.filterColumns(obj.columns);

%Data conversion ...
%-------------------------------------------------
if isempty(c)
    s = struct([]);
    return
end

%Extraction of all properties needed for parsing
c_names = {c.name};
c_labels = {c.label};
c_widths_m1 = [c.column_width]-1; %note _m1 means minus 1
c_offsets = [c.data_row_offset]+1;
c_is_numeric = [c.is_numeric];
c_formats = {c.format};
n_columns = length(c);
n_rows = size(temp_data,2);

s = struct('id',num2cell(1:n_columns),'name',c_names,...
    'label',c_labels,'values',[]);

has_deleted_rows = obj.has_deleted_rows;

for i = 1:n_columns
    I1 = c_offsets(i);
    I2 = c_offsets(i)+c_widths_m1(i);
    if c_is_numeric(i)
        %Note numeric could include dates or times
        %or could just be a number
        
        %data_rows are columns
        %note m1 is minus 1 so this is checking for a width of 8
        if c_widths_m1(i) == 7
            column_data_bytes = temp_data(I1:I2,:);
        else
            column_data_bytes = zeros(8,n_rows,'uint8');
            column_data_bytes(8-c_widths_m1(i):8,:) = temp_data(I1:I2,:);
        end
        
        s(i).values = typecast(column_data_bytes(:),'double');
        
    
        %data rows are rows
        %{
        column_data_bytes = zeros(n_rows,8,'uint8');
        column_data_bytes(:,8-c_widths_m1(i):8) = temp_data(:,I1:I2);
        column_data_bytes = column_data_bytes';
        s(i).values = typecast(column_data_bytes(:),'double');
        %}

        %TODO: custom formats, are these in the file somewhere?
        %https://www.restore.ac.uk/PEAS/ex6datafiles/program_code/ex6formats.sas
        %ALC
        %DRGCODE
        %ETHGP
        %GENDER

        %{
            %enumerated types
            {0×0 char}    {'ALC'}    {'BEST'}    {'DRGCODE'}    {'ETHGP'}    {'GENDER'}
            {'SECTOR'}    {'SM'}    {'SZINDEP'}    {'YESNO'}    {'YZLEAVE'}

        %}

        %https://github.com/epam/parso/pull/86
        switch c_formats{i}
            case ''

            case 'COMMA'
                %numeric that uses commas to separate digits
                %   
                % e.g.,   23,451.54

            case 'COMMAX'
                %
                %   23.451,54 - European style ...

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
            case 'HHMM'
                %
                %   'julian_hhmm.sas7bdat'
                %
                %Let's look at as hours
                s(i).values = hours(seconds(s(i).values));
            case 'JULIAN'
                %
                %   Display off but data are interpreted correctly
                %
                %   'julian_hhmm.sas7bdat'
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
            case {'TIME'}
                %
                %   seconds since midnight

                s(i).values = seconds(s(i).values);
            case 'Z'
                % Writes standard numeric data with leading 0s.
            otherwise

                %error('Unrecognized format: %s',c_formats{i})

        end
    else

        % temp_data format:
        %   columns of temp_data : row entries
        %   rows of temp_data : bytes of the string, padded with spaces (I
        %   think)
        column_data_bytes = temp_data(I1:I2,:);

        encoding = obj.header.character_encoding_name;

        %JAH: 2024-05-31, this variable 'character_encoding_use_lookup'
        %is currently not checked for all encodings, so some encodings may
        %run slower than they need to
 
        if obj.header.character_encoding_use_lookup

            %Algorithm:
            %   - take all possible "raw" values, 1:255 (note 0 is also a 
            %   possible value but causes problems - if we have 0s this
            %   method will fail)
            %   - use native2unicode() to figure out the new values
            %   - do a lookup function where:
            %       - original binary is used as indices
            %       - these values index into the "new values" resulting
            %       in a conversion of that original value to the correct
            %       new value
            %
            %Why not:
            %   fixed_bytes = native2unicode(column_data_bytes,encoding)
            %
            %   Because column_data_bytes is a matrix, and native2unicode
            %   expects a row or column vector.
            %
            %   %Confirming this fails
            %   temp = uint8(40*ones(10,10000));
            %   temp2 = native2unicode(temp,'ASCII');
            %
            %   Note, this approach only works if we are doing a 1:1
            %   mapping. It fails when the order of the bytes matters, such
            %   as for UTF-8 data, or for character maps that introduce 
            %   characters like certain Arabic values which introduce not
            %   only a character but also a left-to-right or right-to-left
            %   instruction in the string (if that doesn't make any sense
            %   consider yourself lucky to have not spent sufficient time
            %   looking at unicode that it causes your head to nearly
            %   explode)

            %This must be 1:n otherwise the indexing step of
            %   char_map(column_data_bytes)
            %doesn't make sense
            bytes = uint8(1:255);

            temp = native2unicode(bytes,encoding);
            char_map = uint16(temp);

            fixed_bytes = char_map(column_data_bytes);

            values = string(char(fixed_bytes'));
        else
            %This is the slow route, one row at a time :/
            temp = cell(n_rows,1);
            for j = 1:n_rows
               temp{j} = native2unicode(column_data_bytes(:,j),encoding)'; 
            end
            values = string(strtrim(temp));
        end

        %I think this was slower ...
        %row_array = (1:n_rows)';
        %temp = arrayfun(@(x) native2unicode(column_data_bytes(:,x),encoding)',row_array,'un',0);

        values = strip(values,'right');

        s(i).values = values;
    end
    if has_deleted_rows
        s(i).values(row_delete_mask) = [];
    end
end

end