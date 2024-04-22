function t = dateframeToTable(df)
%X converts Pandas dataframe to MATLAB table
%
%   t = sas.utils.dateframeToTable(df)
%
%   Improvements
%   ------------
%   1. Check for valid names
%   2. Check for column overlap
%   3. Suppport dimensions

s = struct;

column_names = string(df.columns.to_list());
for i = 1:length(column_names)
    name = column_names(i);
    ds = df.get(column_names(i));

    switch string(ds.dtype.name)
        case "float64"
            value = double(ds.values)';
        otherwise
            keyboard
    end
    s.(name) = value;
end

t = struct2table(s);

end 