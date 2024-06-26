classdef file_reading_options < handle
    %
    %   Class:
    %   sas.file_reading_options

    properties
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
    end
end