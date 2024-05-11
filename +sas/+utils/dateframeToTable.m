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
        case "object"
            %https://pandas.pydata.org/docs/user_guide/text.html
            %value = string(ds.values)';
            n_rows = double(ds.shape);
            rows = 1:n_rows;
            value = arrayfun(@(x) h__toBytes(ds.get(x)),rows,'un',0)';
        case "datetime64[s]"
            n_rows = double(ds.shape);
            rows = 1:n_rows;
            value = arrayfun(@(x) h__toDatetime(ds.get(x)),rows)';
        case "datetime64[ms]"
            n_rows = double(ds.shape);
            rows = 1:n_rows;
            value = arrayfun(@(x) h__toDatetime(ds.get(x)),rows)';
        otherwise
            keyboard
    end
    s.(name) = value;
end

t = struct2table(s);

end 

function v2 = h__toDatetime(v1)

if isa(v1,'datetime')
    v2 = v1;
elseif isa(v1,'py.NoneType')
    v2 = NaT;
else
    error('unsupported type: %s',class(v1))
end

end

function v2 = h__toBytes(v1)

if isa(v1,'py.bytes')
    v2 = uint8(v1);
elseif isa(v1,'py.NoneType')
    v2 = [];
else
    error('unsupported type: %s',class(v1))
end

end