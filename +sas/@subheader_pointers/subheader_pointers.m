classdef subheader_pointers < handle
    %
    %   Class:
    %   sas.subheader_pointers
    %
    %   See Also
    %   --------
    %   sas.subheaders


    properties
        % - 0b pulled directly from file
        % - needs to be shifted by 1 for reading
        % - this is relative to page start, not the file ...
        offsets
        lengths

        %1) truncated - ignore rest
        %4) compressed
        comp_flags
        
        %TODO: Add documentation here
        %0 - Row Size, Column Size, Subheader Counts, Column Format and Label, in Uncompressed file
        %1 - Column Text, Column Names, Column Attributes, Column List
        %1 - all subheaders (including row data), in Compressed file.
        type

        section_type

        signature

        hex_signature
    end

    properties (Dependent)
        t
    end

    methods
        function value = get.t(obj)
            offset = obj.offsets;
            i = 1:numel(obj.offsets);
            i = i';
            %Ugh, overriding length, be careful ...
            length = obj.lengths;
            flag = obj.comp_flags;
            type = obj.type; %#ok<PROP>
            section_type = obj.section_type; %#ok<PROP>
            sig = obj.signature;
            hex_sig = obj.hex_signature;

            value = table(i,offset,length,flag,type,section_type,sig,hex_sig); %#ok<PROP>
        end
    end

    methods
        function obj = subheader_pointers(is_u64,n_subs,bytes)
            %
            %   
            %   s = sas.subheader_pointers(is_u64,n_subs,bytes)
            %
            %
            %   See Also
            %   --------
            %   sas.page

            %Pointer info:
            %1:4 or 1:8  - offset from page start to subheader
            %5:8 or 9:16 - length of subheader - QL
            %               - if zero the subheader can be ignored
            %9   or 17   - compression flag
            %                0 - no compression
            %                1 - truncated (ignore data)
            %                4 - RLE with control byte
            %10  or 18 - subheader type (ST)
            %                0 - Row Size, Column Size, Subheader Counts, Column Format and Label, in Uncompressed file
            %                1 - Column Text, Column Names, Column Attributes, Column List
            %                1 - all subheaders (including row data), in Compressed file.
            %11:12 or 19:24 - zeros - why?? - to flush to 4|8 boundary?


            %TODO: This is not a hot path, combine and use variable for
            %offsets
            if is_u64
                I = 1;
                sub_offsets = zeros(n_subs,1);
                sub_lengths  = zeros(n_subs,1);
                sub_comp_flags = zeros(n_subs,1);
                sub_types = zeros(n_subs,1);
                for i = 1:n_subs
                    sub_offsets(i) = typecast(bytes(I:I+7),'uint64');
                    sub_lengths(i) = typecast(bytes(I+8:I+15),'uint64');
                    sub_comp_flags(i) = bytes(I+16);
                    sub_types(i) = bytes(I+17);
                    I = I + 24;
                end
            else
                I = 1;
                sub_offsets = zeros(n_subs,1);
                sub_lengths  = zeros(n_subs,1);
                sub_comp_flags = zeros(n_subs,1);
                sub_types = zeros(n_subs,1);
                for i = 1:n_subs
                    sub_offsets(i) = double(typecast(bytes(I:I+3),'uint32'));
                    sub_lengths(i) = double(typecast(bytes(I+4:I+7),'uint32'));
                    sub_comp_flags(i) = bytes(I+8);
                    %TODO: check this and throw error if not 0
                    sub_types(i) = bytes(I+9);
                    I = I + 12;

                    %The final subheader on a page is usually COMP=1, 
                    %which indicates a truncated row to be ignored; the
                    %complete data row appears on the next page.
                end
            end

            obj.offsets = sub_offsets;
            obj.lengths = sub_lengths;
            obj.comp_flags = sub_comp_flags;
            obj.type = sub_types;
            n_subs = length(sub_types);
            obj.section_type = cell(n_subs,1);
            obj.signature = zeros(n_subs,1);
            obj.hex_signature = cell(n_subs,1);
        end
        function logSectionType(obj,i,value,sig_value)
            obj.section_type{i} = value;
            obj.signature(i) = sig_value;
            obj.hex_signature{i} = dec2hex(sig_value,8);
        end
    end
end