classdef signature_counts_subheader < handle
    %
    %   Class:
    %   sas.signature_counts_subheader
    %
    %   ???? How many of these?
    %   - just 1?

    properties
        signatures
        page_first_appear
        page_first_pointer
        page_last_appear
        page_last_pointer
        is_multi_page
    end

    methods
        function obj = signature_counts_subheader(bytes,is_u64)
            %
            %   bytes(57) => 12 - 12 things - TODO: Update document
            %
            %   ???? Why in my file are there only 4 entries but
            %   7 non-zero signatures (out of the 12)
            %
            %   The page itself has 7 pages
            %   
            %   
            %
            %65 - start of subheader count vectors

            %1:4 - signature
            %5:8 - first appear
            %9:10 - pointer
            %13:16 - last appear
            %17:18 - pointer
            %
            
            sigs = zeros(12,1);
            p_first_appear = zeros(12,1);
            p_first_pointer = zeros(12,1);
            p_last_appear = zeros(12,1);
            p_last_pointer = zeros(12,1);

            I = 64;
            for i = 1:12
                sigs(i) = typecast(bytes(I+1:I+4),'uint32');
                p_first_appear(i) = typecast(bytes(I+5:I+8),'uint32');
                p_first_pointer(i) = typecast(bytes(I+9:I+10),'uint16');
                p_last_appear(i) = typecast(bytes(I+13:I+16),'uint32');
                p_last_pointer(i) = typecast(bytes(I+17:I+18),'uint16');
                I = I + 20;
            end

            obj.signatures = sigs;
            obj.page_first_appear = p_first_appear;
            obj.page_first_pointer = p_first_pointer;
            obj.page_last_appear = p_last_appear;
            obj.page_last_pointer = p_last_pointer;
            obj.is_multi_page = p_first_appear ~= p_last_appear;
        end
    end
end