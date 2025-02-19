classdef file_reading_options < handle
    %
    %   Class:
    %   sas.file_reading_options

    %{
        
    options = sas.file_reading_options();
    options.read_pages_until_n_exceeds = 10;

    f = sas.file(file_path,options);
    t = f.readData('output_type','table');

    %}

    properties
        read_pages_until_n_exceeds = -1
        pages_to_read = -1

        %If true only the first few pages are read that specify
        %meta data about the file.
        %
        %Unfortunately some files may be buggy and not return
        %all meta data
        read_intro_pages_only = false
    end

    methods
        function obj = file_reading_options
            %
            %   options = sas.file_reading_options
        end
        function [page_indices,read_page,all_pages2,data_starts2,data_n_rows2] = getPageReadingList(obj,next_page,all_pages,data_starts,data_n_rows)
            %
            %   If we keep the 

            n_out = length(obj.pages_to_read);

            data_starts2 = zeros(1,n_out);
            data_n_rows2 = zeros(1,n_out);
            all_pages2 = cell(1,n_out);
            read_page = true(1,n_out);

            [mask,loc] = ismember(1:(next_page-1),obj.pages_to_read);
            data_starts2(loc(mask)) = data_starts(mask);
            data_n_rows2(loc(mask)) = data_n_rows(mask);
            all_pages2(loc(mask)) = all_pages(mask);
            page_indices = obj.pages_to_read;
            read_page(loc(mask)) = false;

        end
    end
end