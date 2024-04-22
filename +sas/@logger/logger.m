classdef logger < handle
    %
    %   Class:
    %       sas.logger

    properties
        name = ''
        has_257 = -1
        has_384 = -1
        has_512 = -1
        has_640 = -1
        has_1024 = -1
        has_16384 = -1
        has_28672 = -1
        fa_page_type = -1
        delayed_compression_initialization = false
        zero_sig = false
        implied_rdc = false
        delete_mask_fix = false
    end

    methods
        function obj = logger()
        end
        function s = getStruct(obj)
            state = warning;
            warning('off','MATLAB:structOnObject');
            s = struct(obj);
            warning(state);
        end
    end
end