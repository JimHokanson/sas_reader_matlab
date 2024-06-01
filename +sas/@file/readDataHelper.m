function output = readDataHelper(obj,options)
%
%   This is called by sas.file>readData
%
%   Basically we remove all of the indendation with this approach
%
%   output = readDataHelper(obj,in)
%
%
%   Speed improvements:
%   -------------------
%   1. hoist is_deleted check out
%   2. hoist empty rows check out
%
%   See Also
%   --------
%   sas.file
%   

arguments
    obj sas.file
    options sas.read_data_options
end

has_deleted_rows = obj.has_deleted_rows;
if obj.has_deleted_rows
    delete_mask = false(obj.n_rows,1);
else
    delete_mask = [];
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
    temp_data = [all_p.comp_data_rows];

    if ~isempty(options.start_stop_rows)
        h__startStopRowCheck(obj,options.start_stop_rows)

        keyboard
    end
else
    %Note the "2" at the end of the variables is simply to avoid
    %MATLAB complaining about local variables intead of properties
    bytes_per_row = obj.bytes_per_row;

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
    %   a1  a2  a3   -> a,b,c -> different data columns
    %   a1  a2  a3   -> 1,2,3 -> first row, 2nd row, etc.
    %   b1  b2  b3
    %   b1  b2  b3
    %

    n_rows_per_page = obj.n_rows_per_page;
    
    if ~isempty(options.start_stop_rows)

        h__startStopRowCheck(obj,options.start_stop_rows)

        I1 = options.start_stop_rows(1);
        I2 = options.start_stop_rows(2);
        n_rows_out = I2 - I1 + 1;
        %TODO: Check the range of I1 and I2
        temp_data = zeros(bytes_per_row,n_rows_out,'uint8');

        last_row_each_page = cumsum(n_rows_per_page);
        first_row_each_page = [1 last_row_each_page(1:end-1)+1];


        pageI1 = find(I1 >= first_row_each_page & I1 <= last_row_each_page);
        pageI2 = find(I2 >= first_row_each_page & I2 <= last_row_each_page);

        start_page = (pageI1+1);
        stop_page = pageI2-1;

        if pageI1 == pageI2
            n_rows_page1 = n_rows_per_page(pageI1);

            keep1_startI = I1 - first_row_each_page(pageI1)+1;
            keep1_stopI =  I2 - first_row_each_page(pageI1)+1;

            temp_data1 = zeros(bytes_per_row,n_rows_page1,'uint8');

            delete_mask1 = false(n_rows_page1,1);
        else
            n_rows_page1 = n_rows_per_page(pageI1);
            n_rows_page2 = n_rows_per_page(pageI2);

            keep1_startI = I1 - first_row_each_page(pageI1)+1;
            keep1_stopI =  n_rows_page1;

            keep2_startI = 1;
            keep2_stopI =  I2 - first_row_each_page(pageI2)+1;

            temp_data1 = zeros(bytes_per_row,n_rows_page1,'uint8');
            temp_data2 = zeros(bytes_per_row,n_rows_page2,'uint8');

            delete_mask1 = false(n_rows_page1,1);
            delete_mask2 = false(n_rows_page2,1);
        end

        %First partial page
        %--------------------------------
        last_read_row = 0;
        last_set_byte = 0;
        [temp_data1,delete_mask1] = h__readUncompressedPages(obj,temp_data1,delete_mask1,pageI1,pageI1,last_read_row,last_set_byte);
        
        n1 = keep1_stopI - keep1_startI + 1;
        temp_data(:,1:n1) = temp_data1(:,keep1_startI:keep1_stopI);
        if has_deleted_rows
            delete_mask(1:n1) = delete_mask1(keep1_startI:keep1_stopI);
        end

        %Setup for next section
        %-------------------------------------
        

        %Complete pages
        %--------------------------------
        if stop_page >= start_page
            %Note this only needs to be set here, and is 0 for the others
            %because in the others we take the output and trim to where
            %we need the specific subset to go
            %
            %here we don't take a subset of the output
            last_read_row = n1;
            last_set_byte = bytes_per_row*n1;
            [temp_data,delete_mask] = h__readUncompressedPages(obj,temp_data,delete_mask,start_page,stop_page,last_read_row,last_set_byte);
        end

        %Second partial page
        %----------------------------------------
        if pageI1 ~= pageI2
            last_read_row = 0;
            last_set_byte = 0;
            [temp_data2,delete_mask2] = h__readUncompressedPages(obj,temp_data2,delete_mask2,pageI2,pageI2,last_read_row,last_set_byte);

            n2 = keep2_stopI - keep2_startI + 1;
            temp_data(:,end-n2+1:end) = temp_data2(:,keep2_startI:keep2_stopI);
            if has_deleted_rows
                delete_mask(end-n2+1:end) = delete_mask2(keep2_startI:keep2_stopI);
            end
        end
    else
        I1 = 1;
        I2 = obj.n_pages;
        temp_data = zeros(bytes_per_row,obj.n_rows,'uint8');

        last_read_row = 0;
        last_set_byte = 0;
        [temp_data,delete_mask] = h__readUncompressedPages(obj,temp_data,delete_mask,I1,I2,last_read_row,last_set_byte);
    end
end

%Once we have all of the data we convert to real types
%------------------------------------------------------
s = obj.rowsToData(temp_data,delete_mask,options);

output = options.convertToOutputType(s);

%output = h__convertToOutputType(s,options);

end

function h__startStopRowCheck(obj,start_stop_values)

%TODO

end


% % % % function output = h__convertToOutputType(s,in)
% % % % %
% % % % %   s :
% % % % %   in :
% % % % %   
% % % % 
% % % % %Output processing
% % % % %------------------------------------
% % % % switch in.output_type
% % % %     case 'table'
% % % %         %TODO: Add in labels to output.Properties.VariableDescriptions
% % % %         %Add in column names even if empty table
% % % %         output = table;
% % % %         for i = 1:length(s)
% % % %             name = s(i).name;
% % % %             %This may not be the most efficient ...
% % % %             output.(name) = s(i).values;
% % % %         end
% % % %     case 'struct'
% % % %         output = s;
% % % %         %Nothing to do
% % % %     otherwise
% % % %         %- If we reach this we have an error in the code
% % % %         %  because we do this check as well at the top
% % % %         error('Unhandled exception')
% % % % end
% % % % 
% % % % end

function [temp_data,delete_mask] = h__readUncompressedPages(obj,...
    temp_data,delete_mask,p1,p2,last_read_row,last_set_byte)
%
%
%   Inputs
%   ------
%   temp_data
%   delete_mask :
%       This is a 
%   p1 : 
%       First page to read
%   p2 :
%       Last page to read
%   last_read_row : 
%       
%   last_set_byte

fid2 = obj.fid;
I2 = last_set_byte;
row2 = last_read_row;
has_deleted_rows = obj.has_deleted_rows;
n_rows_per_page = obj.n_rows_per_page;
bytes_per_row = obj.bytes_per_row;
data_starts = obj.data_start_per_page;
for i = p1:p2
    n_rows_cur_page = n_rows_per_page(i);
    if n_rows_cur_page == 0
        continue
    end
    n_bytes_read = n_rows_cur_page*bytes_per_row;
    
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