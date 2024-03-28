classdef minguo < datetime
    %
    %
    %   sas.formats.minguo
    %
    %   The goal here would be to keep datetime and on display change
    %   any reference to the year to being off by 1911 years
    %
    %   i.e. if Y_orig = 1912
    %   Y_new = 1912 - 1911 = 1 (first year)
    %
    %   Note it is not possible to subtract 1911 years and work with a 
    %   normal datetime because the days and months won't align. Instead
    %   we are talking about only changing the display at the last minute.
    %   

    properties
        
    end

    methods
        function obj = minguo(varargin)
            keyboard
        end
    end
end