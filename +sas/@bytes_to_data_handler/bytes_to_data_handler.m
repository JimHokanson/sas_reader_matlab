classdef bytes_to_data_handler < handle
    %
    %   Class:
    %   sas.bytes_to_data_handler
    %
    %
    %   TODO: I wanted to move some of the logic in here
    %   Low priority
    %
    %
    %   Data formatting notes
    %   ---------------------
    %
    %   Option 1
    %   --------
    %   dim 1: n_rows
    %   dim 2: n_columns*n_bytes_per_column
    %
    %   Option 2
    %   --------
    %   dim 1: n_columns*n_bytes_per_column
    %   dim 2: n_rows
    %   
    %   When typecasting you can do a direct translation if
    %   the format is:
    %   dim 1 - n_columns*n_bytes_per_column
    %   dim 2 - n_rows
    %
    %   Example data for option 2 layout
    %   - a,b,c are different columns
    %   - repeats by row are the bytes of that column, e.g. 'a
    %     has 3 bytes in this example
    %   - 1,2,3 are the row #s
    %   
    %   a1  a2  a3
    %   a1  a2  a3
    %   a1  a2  a3
    %   b1  b2  b3
    %   b1  b2  b3
    %   c1  c2  c3
    %   c1  c2  c3
    %   c1  c2  c3
    %
    %   When converting if we grab the a's we can then typecast directly
    %
    %   If we instead store flipped, we need to transpose before
    %   typecasting

    properties
        
    end

    methods
        function obj = bytes_to_data_handler()
        end
    end
end