classdef column_text_subheader
    %
    %   sas.column_text_subheader
    %
    %   Contains strings but needs other subheaders to identify which
    %   string is which
    %
    %   n = ???
    %   
    %   How many of these do we have?
    

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

            %https://github.com/epam/parso/blob/3c514e66264f5f3d5b2970bc2509d749065630c0/src/main/java/com/epam/parso/impl/SasFileParser.java#L1526

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

            %JAH: Note somewhere I saw something that said this is all
            %specified somewhere else, maybe in the main header???
            if all(first8 == 0) || all(first8 == 32)
                %No compression
                obj.compression_type = "none";
                if lcp > 0
                    if all(first8 == 32)
                        %do nothing
                    else
                        keyboard
                    end
                end
            elseif char(first8) == "SASYZCRL"
                %example file: rle
                obj.compression_type = "rle";
                I = I + 8;
                obj.creator_proc_name = strtrim(char(bytes(I:I+lcp-1)));
            elseif char(first8) == "SASYZCR2"
                %example file: rdc
                obj.compression_type = "rdc";
                I = I + 8;
                obj.creator_proc_name = strtrim(char(bytes(I:I+lcp-1)));
            elseif lcs > 0
                %cbsatocountycrosswalk.sas7bdat
                obj.compression_type = "none";
                obj.creator_soft_str = strtrim(char(bytes(I:I+lcs-1)));
            else
                %fts0003.sas7bdat
                %
                obj.compression_type = "none";
                obj.creator_soft_str = strtrim(char(bytes(I:I+lcp-1)));
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