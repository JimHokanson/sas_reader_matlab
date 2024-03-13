classdef column_text_subheader
    %
    %   sas.column_text_subheader
    %
    %   Contains strings but needs other subheaders to identify which
    %   string is which
    

    properties
        size_text_block
        unknown7
        unknown9
        unknown11
        unknown13
        unknown15
        bytes
        compression_type
        creator_soft_str
        creator_proc_name
        %- 'none'
        %- 'rle'
        %- 'binary'
    end

    methods
        function obj = column_text_subheader(bytes,is_u64,row_size_sh)
            %
            %

            %   1:4 - signature
            %   5:6 - size of block
            %   7:8
            %   9:10
            %   11:12
            %   13:14
            %   15:16
            %
            %   17: 

            obj.size_text_block = double(typecast(bytes(5:6),'uint16'));

            obj.unknown7 = bytes(7:8);
            obj.unknown9 = bytes(9:10);
            obj.unknown11 = bytes(11:12);
            obj.unknown13 = bytes(13:14);
            obj.unknown15 = bytes(15:16);

            if is_u64
                I = 21;
            else
                I = 17;
            end

            first8 = bytes(I:I+7);

            lcs = row_size_sh.length_creator_software_string;
            lcp = row_size_sh.length_creator_PROC_step_name;

            if all(first8 == 0)
                %No compression
                obj.compression_type = 'none';
            elseif lcs > 0
                obj.compression_type = 'none';
                keyboard
            elseif char(first8) == "SASYZCRL"
                obj.compression_type = 'rle';
                I = I + 8;
                obj.creator_proc_name = strtrim(char(bytes(I:I+lcp-1)));
            else
                obj.compression_type = 'binary';
            end

            %{
                1. If the first 8 bytes of the field are blank, file is not compressed, and set LCS=0. The Creator PROC step
                name is the LCP bytes starting at offset 16.
                2. If LCS > 0 (still), the file is not compressed, the first LCS bytes are the Creator Software string (padded
                with nulls). Set LCP=0. Stat/Transfer files use this pattern.
                3. If the first 8 bytes of the field are SASYZCRL, the file is compressed with Run Length Encoding. The
                Creator PROC step name is the LCP bytes starting at offset 24.
                4. If the first 8 bytes are nonblank and options 2 or 3 above are not used, this probably indicates COMPRESS=
                BINARY. We need test files to confirm this, though.
            %}

            %??? Need LCS/LCP from row_size_subheader
            obj.bytes = bytes(:)';
        end
    end
end