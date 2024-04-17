function s = rowsToData(obj,temp_data,delete_mask)
%
%   Inputs
%   ------
%   temp_data

%Data conversion ...
%-------------------------------------------------
c = obj.columns;
c_widths_m1 = [c.column_width]-1;
c_offsets = [c.data_row_offset]+1;
c_is_numeric = [c.is_numeric];
c_formats = {c.format};
n_columns = length(c);
n_rows = size(temp_data,2);

s = struct('id',num2cell(1:n_columns),'name',{c.name},...
    'label',{c.label},'values',[]);

has_deleted_rows = obj.has_deleted_rows;

for i = 1:n_columns
    I1 = c_offsets(i);
    I2 = c_offsets(i)+c_widths_m1(i);
    if c_is_numeric(i)
        column_data_bytes = zeros(8,n_rows,'uint8');
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
    if has_deleted_rows
        s(i).values(delete_mask) = [];
    end
end

end