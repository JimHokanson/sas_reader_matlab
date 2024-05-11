classdef parso < handle
    %
    %   Class:
    %   sas.testing.parso
    %
    %   In order to get this to work you need the following calls
    %   modified for your file paths (haven't added relative imports yet)
    %   
    %   javaaddpath('/Users/jim/Documents/repos/matlab/sas_reader_matlab/java/parso-2.0.14.jar')
    %   javaaddpath('/Users/jim/Documents/repos/matlab/sas_reader_matlab/java/slf4j-api-1.7.5.jar')



    %{
        p = sas.testing.parso();
        [s,f] = p.read_sas(file_path);
    %}

    properties
        
    end

    methods
        function obj = parso()

        end

        function [t,f] = read_sas(obj,file_path)
            stream = java.io.FileInputStream(file_path);
            reader = com.epam.parso.impl.SasFileReaderImpl(stream);
            data = reader.readAll();

            columns = reader.getColumns();

            c_all = cell(1,columns.size);
            t = table;
            for i = 1:columns.size
                c = sas.testing.parso_column(columns.get(i-1));
                c_all{i} = c;
                switch c.type
                    case 'java.lang.Number'

                        
                        if length(data) == 1
                            %if scalar, below would be cell(#)
                            %which could cause large array rather
                            %than expansion of objects
                            temp = {data(:,i)};
                        else
                            temp = cell(data(:,i));
                        end
                        %Might be datetime :/
                        switch c.format_name
                            case {'DATE','MMDDYY','YYMMDD','DATETIME'}
                                mask = cellfun('isempty',temp);
                                temp(mask) = {NaT};
                                temp(~mask) = cellfun(@h__convertDatetime,temp(~mask));
                                value = vertcat(temp{:});
                                %value = cellfun(@(x) h__convertDatetime(x),temp);
                            case {'','TIME','MINGUO','COMMA','Z'}
                                %'MINGUO' is incorrect in parso
                                %should be datetime
                                temp(cellfun('isempty',temp)) = {NaN};
                                value = vertcat(temp{:});
                                %value = cellfun(@(x) h__convertDouble(x),temp);
                            otherwise
                                keyboard
                        end

                        t.(c.name) = value;
                    case 'java.lang.String'
                        value = string(data(:,i));
                        t.(c.name) = value;
                    otherwise
                        keyboard
                end
            end

            if nargout == 2
                columns2 = [c_all{:}];
                p = reader.getSasFileProperties();
                f = sas.testing.parso_file(columns2,p);
            else
                f = [];
            end

            

        end
    end
end

function out = h__convertDouble(in)
    if isempty(in)
        out = NaN;
    else
        out = in;
    end
end

function out = h__convertDatetime(in)
% if isempty(in)
%     out = NaT;
% else
t = in.getTime();
out = datetime(t,'convertFrom','epochtime','TicksPerSecond',1000);
out = {out};
% end
end