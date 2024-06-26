classdef parso_column
    %
    %   Class:
    %   sas.testing.parso_column

    properties
        format_name
        format_precision
        format_width
        id
        label
        name
        type
    end

    methods
        function obj = parso_column(h)
            f = h.getFormat();
            obj.format_name = char(f.getName());
            obj.format_precision = f.getPrecision();
            obj.format_width = f.getWidth();
            obj.id = h.getId();
            obj.label = char(h.getLabel());
            obj.name = char(h.getName());
            %'class java.lang.Number'
            temp = char(h.getType());
            obj.type = temp(7:end);
        end
    end
end