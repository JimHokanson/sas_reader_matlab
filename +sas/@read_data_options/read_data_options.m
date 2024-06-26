classdef read_data_options
    %
    %   Class:
    %   sas.read_data_options


    %{
    f = sas.file(fp);
    t = f.readData('columns_ignore',{'facility','facilityid'});  
    t = f.readData('columns_keep',{'subjectid','datetime','value'});
    %}

    properties
        columns_keep = -1 %-1 means unset ...
        %{} means keep nothing
        columns_ignore = {}
        start_stop_rows
        output_type = 'table'
    end

    methods
        function validateOptions(obj)
            if ~any(strcmp(in.output_type,{'table','struct'}))
                error('"output_type" option: %s, not recognized',...
                    in.output_type)
            end
            if ~isequal(obj.columns_keep,-1) && ~isempty(obj.columns_ignore)
                error('Can''t specify both columns_keep and columns_ignore')
            end
            %TODO: Verify if not empty columns_keep or columns_ignore they
            %are string arrays or cell array
        end
        function c_out = filterColumns(obj,c_in)
            if isequal(obj.columns_keep,-1)
                if isempty(obj.columns_ignore)
                    c_out = c_in;
                else
                    names = {c_in.name};
                    mask = ismember(names,obj.columns_ignore);
                    c_out = c_in(~mask);
                end
            else
                %process columns_keep
                names = {c_in.name};
                mask = ismember(names,obj.columns_keep);
                c_out = c_in(mask);
            end
        end
        function output = convertToOutputType(obj,s)
            %
            %
            %   Uses property .output_type
            %
            %   See Also
            %   --------
            %   sas.file>readDataHelper

            switch obj.output_type
                case 'table'
                    %TODO: Add in labels to output.Properties.VariableDescriptions
                    %Add in column names even if empty table
                    output = table;
                    for i = 1:length(s)
                        name = s(i).name;
                        %This may not be the most efficient ...
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
    end
end