function output = readDataHelper(obj,in)
%
%
%   output = readDataHelper(obj,in)

has_deleted_rows = obj.has_deleted_rows;
if obj.has_deleted_rows
    delete_mask = false(obj.n_rows,1);
end

%Read all data into memory
%-----------------------------------------
if obj.has_compression
    %Currently all pages are already in memory ...
    %
    %   This may change. Maybe push method to pages????
    %
    %   Although below could be a pages thing too ...
    all_p = obj.all_pages;
    temp = [all_p.comp_data_rows];
    temp_data = [temp{:}];

    if ~isempty(in.start_stop_rows)
        keyboard
    end
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
    

    if ~isempty(in.start_stop_rows)
        I1 = in.start_stop_rows(1);
        I2 = in.start_stop_rows(2);
        n_rows_out = I2 - I1 + 1;
        %TODO: Check the range of I1 and I2
        temp_data = zeros(bytes_per_row2,n_rows_out,'uint8');
    else
        I1 = 1;
        I2 = obj.n_rows;
        temp_data = zeros(bytes_per_row2,obj.n_rows,'uint8');
    end

    data_n_rows = obj.data_n_rows;
    data_starts = obj.data_starts;
    keyboard
    fid2 = obj.fid;
    I2 = 0;
    row2 = 0;
    for i = 1:n_reads
        n_rows_cur_page = data_n_rows(i);
        n_bytes_read = n_rows_cur_page*bytes_per_row2;
        if n_bytes_read == 0
            continue
        end
        fseek(fid2,data_starts(i),"bof");
        I1 = I2 + 1;
        I2 = I2 + n_bytes_read;
        temp_data(I1:I2) = fread(fid2,n_bytes_read,"*uint8")';
        if has_deleted_rows
            row1 = row2 + 1;
            row2 = row2 + n_rows_cur_page;
            delete_mask(row1:row2) = obj.all_pages(i).delete_mask(1:n_rows_cur_page);
        end
    end
end

s = obj.rowsToData(temp_data,delete_mask);

output = h__convertToOutputType(s,in);

end

function output = h__convertToOutputType(s,in)

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