function s = rowsToData(obj,temp_data,row_delete_mask,column_keep_mask)
%
%   Inputs
%   ------
%   temp_data
%   delete_mask
%   column_keep_mask
%
%
%   See Also
%   --------
%   sas.file
%   sas.file>readDataHelper

%Data conversion ...
%-------------------------------------------------
c = obj.columns;
if isempty(c)
    s = struct([]);
    return
end

%TODO: Do column filtering here ...


%Extraction of all properties needed for parsing
c_names = {c.name};
c_labels = {c.label};
c_widths_m1 = [c.column_width]-1;
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

        %TODO: custom formats
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
            case 'Z'
                % Writes standard numeric data with leading 0s.
            otherwise

                %error('Unrecognized format: %s',c_formats{i})

        end
    else
        %Transpose makes each row a string
        %
        %**** Ideally we would do this in C and avoid transpose
        %and temporary operations

        %data rows are columns

        %{
        %old code
        column_data_bytes = temp_data(I1:I2,:)';
        temp = string(char(column_data_bytes));
        s(i).values = strtrim(temp);
        %}
        
        %data rows are rows
        %{
            column_data_bytes = temp_data(:,I1:I2);
        %}

        column_data_bytes = temp_data(I1:I2,:);

        encoding = obj.header.character_encoding_name;

        %TODO: Add other single page maps
        if encoding == "WINDOWS-1252"
            bytes = uint8(1:255);
            %Note, windows-1252 is a 1 byte map so it is rather efficient
            %to do a lookup.

            temp = native2unicode(bytes,"windows-1252");
            char_map = uint16(temp);

            fixed_bytes = char_map(column_data_bytes);

            values = string(char(fixed_bytes'));
        else
            temp = cell(n_rows,1);
            for j = 1:n_rows
               temp{j} = native2unicode(column_data_bytes(:,j),encoding)'; 
            end
            values = string(strtrim(temp));
        end

        %row_array = (1:n_rows)';
        %temp = arrayfun(@(x) native2unicode(column_data_bytes(:,x),encoding)',row_array,'un',0);

        values = strip(values,'right');
        
        %TODO: encoding
        %native2unicode
        %TODO: remove trailing spaces ...

        s(i).values = values;
    end
    if has_deleted_rows
        s(i).values(row_delete_mask) = [];
    end
end

end