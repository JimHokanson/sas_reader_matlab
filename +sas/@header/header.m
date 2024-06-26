classdef header < handle
    %
    %   Class:
    %   sas.header
    %
    %   This is the main header of the file.
    %
    %   See Also
    %   --------
    %   sas.file
    %   sas.row_size_subheader
    %   sas.column_attributes
    %   sas.column_size_subheader
    %   sas.column_format_subheader
    %   sas.signature_counts_subheader
    %

    properties
        bytes
        start_position

        %1:32
        magic_number

        %33
        a2     %4 if b33 == 51, else 0
        b33_a2 %byte 33 (from which a2 is derived)
        is_u64 %if a2 == 4, computed

        unknown34  %34:35
        unknown37
        unknown39
        unknown41  %41:70 Lots of non-zero numbers
        unknown72
        unknown125
        unknown289

        a1  %36
        b36_a1
        %unknown37 %37
        is_little_endian %38
        %unknown39  %39
        file_format %40, %FORM_DOC: renamed from os_type
        %unknown41  %41:70
        %https://github.com/WizardMac/ReadStat/blob/887d3a1bbcf79c692923d98f8b584b32a50daebd/src/sas/readstat_sas.c#L45
        character_encoding_raw  %71, FORM_DOC: WizardMac is saying only 1 byte, not 2
        
        character_encoding_name %computed
        %
        %   See usage in 

        character_encoding_use_lookup

        %unknown72  %72:84

        file_type   %85:92, Should = 'SAS FILE'
        table_name  %93:124
        %unknown125 %125:156
        file_info %157:164

        creation_time_raw       %165+a1:172+a1
        modification_time_raw   %173+a1:180+a1
        creation_time_diff
        modification_time_diff
        creation_time
        modification_time

        header_length
        page_length
        page_count
        sas_release
        sas_host
        os_version_number
        os_maker
        os_name

        %329:336
        timestamp3
    end

    methods
        function obj = header(fid)
            %
            %   h = sas.header(fid)

            %https://github.com/epam/parso/blob/3c514e66264f5f3d5b2970bc2509d749065630c0/src/main/java/com/epam/parso/impl/SasFileParser.java#L318
            %https://github.com/WizardMac/ReadStat/blob/887d3a1bbcf79c692923d98f8b584b32a50daebd/src/sas/readstat_sas.c#L161

            %Offsets vary by a1 and a2, not by u64 vs not
            %---------------------------
            %1:32    : magic number
            %33      : a2
            %34:35     unknown1
            %36      : a1
            %37      : unknown2
            %38      : endian-ness
            %          - 0 big
            %          - 1 little
            %39      : unknown3
            %40      : os_type
            %          - 1 - unix
            %          - 2 - windows - only impacts strings
            %41:70   : unknown4
            %
            %TODO: Finish rest of the documentation ...



            obj.start_position = ftell(fid);
            %ASSUMPTION: Minimum length is 1024
            %*** FREAD ***
            bytes = fread(fid,1024,"*uint8")';

            obj.bytes = bytes;

            obj.magic_number = bytes(1:32);

            obj.b33_a2 = bytes(33);
            %I'm seeing 34, not 51, why????
            obj.a2 = 4*(bytes(33) == 51);
            obj.is_u64 = obj.a2 == 4;

            obj.unknown34 = bytes(34:35);
            obj.unknown37 = bytes(37);
            obj.unknown39 = bytes(39);
            obj.unknown41 = bytes(41:70);
            obj.unknown72 = bytes(72:84);
            obj.unknown125 = bytes(125:156);


            obj.a1 = 4*(bytes(36) == 51);
            obj.b36_a1 = bytes(36);

            obj.is_little_endian = bytes(38) == 1;
            if ~obj.is_little_endian
                error('sas_reader:big_endian','big endian is unsupported')
            end
            if bytes(40) == 1
                obj.file_format = 'unix';
            else
                obj.file_format = 'windows';
            end

            %https://github.com/WizardMac/ReadStat/blob/887d3a1bbcf79c692923d98f8b584b32a50daebd/src/sas/readstat_sas.c#L45
            %obj.character_encoding_raw = typecast(bytes(71:72),'int16');
            obj.character_encoding_raw = bytes(71);
            obj.character_encoding_use_lookup = false;
            switch obj.character_encoding_raw
                case 0
                    name = 'US-ASCII';
                    obj.character_encoding_use_lookup = true;
                    %  chars_ascii = native2unicode(uint8(1:255),"US-ASCII")
                case 20
                    name = "UTF-8";
                case 28
                    name = 'US-ASCII';
                    obj.character_encoding_use_lookup = true;
                    %  chars_ascii = native2unicode(uint8(1:255),"US-ASCII")
                case 29
                    %https://en.wikipedia.org/wiki/ISO/IEC_8859-1
                    name = "ISO-8859-1";
                    obj.character_encoding_use_lookup = true;
                    %  chars_iso_8859_1 = native2unicode(uint8(1:255),"ISO-8859-1")
                case 30
                    %https://en.wikipedia.org/wiki/ISO/IEC_8859-2
                    name = "ISO-8859-2";
                    obj.character_encoding_use_lookup = true;
                    %  chars_iso_8859_2 = native2unicode(uint8(1:255),"ISO-8859-2")
                case 31
                    %https://en.wikipedia.org/wiki/ISO/IEC_8859-3
                    name = "ISO-8859-3";
                    obj.character_encoding_use_lookup = true;
                    %  chars_iso_8859_3 = native2unicode(uint8(1:255),"ISO-8859-3")
                case 32
                    %https://en.wikipedia.org/wiki/ISO/IEC_8859-4
                    name = "ISO-8859-4";
                    obj.character_encoding_use_lookup = true;
                    %  chars_iso_8859_4 = native2unicode(uint8(1:255),"ISO-8859-4")
                case 33
                    %https://en.wikipedia.org/wiki/ISO/IEC_8859-5
                    name = "ISO-8859-5";
                    obj.character_encoding_use_lookup = true;
                    %  chars_iso_8859_5 = native2unicode(uint8(1:255),"ISO-8859-5")
                case 34
                    %https://en.wikipedia.org/wiki/ISO/IEC_8859-6
                    name = "ISO-8859-6";
                    obj.character_encoding_use_lookup = true;
                    %  chars_iso_8859_6 = native2unicode(uint8(1:255),"ISO-8859-6")
                case 35
                    %https://en.wikipedia.org/wiki/ISO/IEC_8859-7
                    name = "ISO-8859-7";
                    obj.character_encoding_use_lookup = true;
                    %  chars_iso_8859_7 = native2unicode(uint8(1:255),"ISO-8859-7")
                case 36
                    %https://en.wikipedia.org/wiki/ISO/IEC_8859-8
                    name = "ISO-8859-8";
                    obj.character_encoding_use_lookup = true;
                    %  chars_iso_8859_8 = native2unicode(uint8(1:255),"ISO-8859-8")
                case 37
                    %https://en.wikipedia.org/wiki/ISO/IEC_8859-9
                    name = "ISO-8859-9";
                    obj.character_encoding_use_lookup = true;
                    %  chars_iso_8859_9 = native2unicode(uint8(1:255),"ISO-8859-9")
                case 39
                    %https://en.wikipedia.org/wiki/ISO/IEC_8859-11
                    name = "ISO-8859-11";
                    obj.character_encoding_use_lookup = true;
                    %  chars_iso_8859_11 = native2unicode(uint8(1:255),"ISO-8859-11")
                case 40
                    %https://en.wikipedia.org/wiki/ISO/IEC_8859-15
                    name = "ISO-8859-15";
                    obj.character_encoding_use_lookup = true;
                    %  chars_iso_8859_15 = native2unicode(uint8(1:255),"ISO-8859-15")
                case 41
                    %https://en.wikipedia.org/wiki/Code_page_437
                    name = "CP437";
                    obj.character_encoding_use_lookup = true;
                case 42
                    %https://en.wikipedia.org/wiki/Code_page_850
                    name = "CP850";
                    obj.character_encoding_use_lookup = true;
                case 43
                    %https://en.wikipedia.org/wiki/Code_page_852
                    name = "CP852";
                    obj.character_encoding_use_lookup = true;
                case 44
                    %https://en.wikipedia.org/wiki/Code_page_857
                    name = "CP857";
                    obj.character_encoding_use_lookup = true;
                case 45
                    %https://en.wikipedia.org/wiki/Code_page_858
                    name = "CP858";
                    obj.character_encoding_use_lookup = true;
                case 46
                    %https://en.wikipedia.org/wiki/Code_page_862
                    name = "CP862";
                    obj.character_encoding_use_lookup = true;
                case 47
                    %https://en.wikipedia.org/wiki/Code_page_864
                    name = "CP864";
                    obj.character_encoding_use_lookup = true;
                case 48
                    %https://en.wikipedia.org/wiki/Code_page_865
                    name = "CP865";
                    obj.character_encoding_use_lookup = true;
                case 49
                    %https://en.wikipedia.org/wiki/Code_page_866
                    name = "CP866";
                    obj.character_encoding_use_lookup = true;
                case 50
                    %https://en.wikipedia.org/wiki/Code_page_869
                    name = "CP869";
                    %  chars_cp869 = native2unicode(uint8(1:255),"CP869")
                case 51
                    %https://en.wikipedia.org/wiki/Code_page_874
                    name = "CP874";
                    obj.character_encoding_use_lookup = true;
                    %  chars_cp874 = native2unicode(uint8(1:255),"CP874")
                case 52
                    %https://en.wikipedia.org/wiki/Code_page_921
                    name = "CP921";
                    obj.character_encoding_use_lookup = true;
                    %  chars_cp921 = native2unicode(uint8(1:255),"CP921")
                case 53
                    name = "CP922";
                    obj.character_encoding_use_lookup = true;
                    %  chars_cp863 = native2unicode(uint8(1:255),"CP922")
                case 54
                    %????? unsupported, can't find
                    name = "CP1129";
                    obj.character_encoding_use_lookup = true;
                    %  chars_cp1129 = native2unicode(uint8(1:255),"CP1129")
                case 55
                    name = "CP720";
                    obj.character_encoding_use_lookup = true;
                    %  chars_cp863 = native2unicode(uint8(1:255),"CP863")
                case 56
                    name = "CP737";
                    obj.character_encoding_use_lookup = true;
                    %  chars_cp863 = native2unicode(uint8(1:255),"CP863")
                case 57
                    name = "CP775";
                    obj.character_encoding_use_lookup = true;
                    %  chars_cp863 = native2unicode(uint8(1:255),"CP863")
                case 58
                    name = "CP860";
                    obj.character_encoding_use_lookup = true;
                    %  chars_cp863 = native2unicode(uint8(1:255),"CP863")
                case 59
                    %https://en.wikipedia.org/wiki/Code_page_863
                    name = "CP863";
                    obj.character_encoding_use_lookup = true;
                    %  chars_cp863 = native2unicode(uint8(1:255),"CP863")
                case 60
                    %https://en.wikipedia.org/wiki/Windows-1250
                    name = "windows-1250";
                    obj.character_encoding_use_lookup = true;
                    %  chars1250 = native2unicode(uint8(1:255),"windows-1250");
                case 61
                    %https://en.wikipedia.org/wiki/Windows-1251
                    name = "windows-1251";
                    obj.character_encoding_use_lookup = true;
                    %  chars1251 = native2unicode(uint8(1:255),"windows-1251");
                case 62
                    %https://en.wikipedia.org/wiki/Windows-1252
                    name = "windows-1252";
                    obj.character_encoding_use_lookup = true;
                    %  chars1252 = native2unicode(uint8(1:255),"windows-1252");
                case 63
                    %https://en.wikipedia.org/wiki/Windows-1253
                    name = "windows-1253";
                    obj.character_encoding_use_lookup = true;
                    %  chars1253 = native2unicode(uint8(1:255),"windows-1253");
                case 64
                    %https://en.wikipedia.org/wiki/Windows-1254
                    name = "windows-1254";
                    obj.character_encoding_use_lookup = true;
                    %  chars1254 = native2unicode(uint8(1:255),"windows-1254");
                case 65
                    %https://en.wikipedia.org/wiki/Windows-1255
                    name = "windows-1255";
                    obj.character_encoding_use_lookup = true;
                    %  chars1255 = native2unicode(uint8(1:255),"windows-1255");
                case 66
                    %https://en.wikipedia.org/wiki/Windows-1256
                    name = "windows-1256";
                    obj.character_encoding_use_lookup = true;
                    %  chars1256 = native2unicode(uint8(1:255),"windows-1256");
                case 67
                    %https://en.wikipedia.org/wiki/Windows-1257
                    name = "windows-1257";
                    obj.character_encoding_use_lookup = true;
                    %  chars1257 = native2unicode(uint8(1:255),"windows-1257");
                case 68
                    %https://en.wikipedia.org/wiki/Windows-1258
                    name = "windows-1258";
                    obj.character_encoding_use_lookup = true;
                    %  chars1258 = native2unicode(uint8(1:255),"windows-1258");
                case 69
                    name = "MACROMAN";
                    %  chars_macroman = native2unicode(uint8(1:255),"macroman");
                case 70
                    %unsupported ...
                    %
                    %   This is tricky as we need to deal with right vs
                    %   left renderings
                    %
                    %   https://en.wikipedia.org/wiki/Right-to-left_mark
                    %
                    name = "MACARABIC";
                    %  chars_macarabic = native2unicode(uint8(1:255),"macarabic");
                case 71
                    name = "MACHEBREW";
                    %  chars_machebrew = native2unicode(uint8(1:255),"machebrew");
                case 72
                    name = "MACGREEK";
                case 73
                    name = "MACTHAI";
                case 75
                    name = "MACTURKISH";
                case 76
                    name = "MACUKRAINE";
                case 118
                    name = "CP950";
                case 119
                    name = "EUC-TW";
                case 123
                    name = "BIG-5";
                case 125
                    name = "GB18030"; % "euc-cn" in SAS
                case 126
                    name = "WINDOWS-936"; % "zwin"
                case 128
                    name = "CP1381"; % "zpce"
                case 134
                    name = "EUC-JP";
                case 136
                    name = "CP949";
                case 137
                    name = "CP942";
                case 138
                    name = "CP932"; % "shift-jis" in SAS
                case 140
                    name = "EUC-KR";
                case 141
                    name = "CP949"; % "kpce"
                case 142
                    name = "CP949"; % "kwin"
                case 163
                    name = "MACICELAND";
                case 167
                    name = "ISO-2022-JP";
                case 168
                    name = "ISO-2022-KR";
                case 169
                    name = "ISO-2022-CN";
                case 172
                    name = "ISO-2022-CN-EXT";
                case 204
                    name = 'US-ASCII'; % "any" in SAS
                case 205
                    name = "GB18030";
                case 227
                    name = "ISO-8859-14";
                case 242
                    name = "ISO-8859-13";
                case 245
                    name = "MACCROATIAN";
                case 246
                    name = "MACCYRILLIC";
                case 247
                    name = "MACROMANIA";
                case 248
                    name = "SHIFT_JISX0213";
                otherwise
                    error('Unrecognized option')
            end

            obj.character_encoding_name = name;


            obj.file_type = char(bytes(85:92));
            obj.table_name = strtrim(char(bytes(93:124)));
            %unknown125
            obj.file_info = strtrim(char(bytes(157:164)));


            %Skipping forward by variable amount


            a1 = obj.a1;

            %Processing of the times
            %---------------------------------------------
            obj.creation_time_raw = typecast(bytes(165+a1:172+a1),'double');
            obj.modification_time_raw = typecast(bytes(173+a1:180+a1),'double');
            %FORM_DOC
            %- not sure these are documented ...
            obj.creation_time_diff = typecast(bytes(181+a1:188+a1),'double');
            obj.modification_time_diff = typecast(bytes(189+a1:196+a1),'double');

            %dates.sas7bdat
            %Aug 23, 2020  , 2:54:47

            temp = obj.creation_time_raw - obj.creation_time_diff;
            obj.creation_time = datetime(1960,1,1) + seconds(temp);
            temp = obj.modification_time_raw - obj.modification_time_diff;
            obj.modification_time = datetime(1960,1,1) + seconds(temp);


            %------------------------------------------
            obj.header_length = double(typecast(bytes(197+a1:200+a1),'uint32'));
            obj.page_length = double(typecast(bytes(201+a1:204+a1),'uint32'));
            if obj.is_u64
                obj.page_count = double(typecast(bytes(205+a1:208+a1+obj.a2),'uint64'));
            else
                obj.page_count = double(typecast(bytes(205+a1:208+a1),'uint32'));
            end


            a12 = obj.a1+obj.a2;
            %209:216

            %TODO: Lots missing from here ...
            %Haven't copmpared to MacWizard's version ...

            obj.sas_release = char(bytes(217+a12:224+a12));
            obj.sas_host = h_string_clean(char(bytes(225+a12:240+a12)));
            obj.os_version_number = char(bytes(241+a12:256+a12));
            obj.os_maker = char(bytes(257+a12:272+a12));
            obj.os_name = char(bytes(273+a12:288+a12));

            %There is a signature
            obj.unknown289 = bytes(289:328);

            obj.timestamp3 = typecast(bytes(329+a12:336+a12),'double');

            %rest seem to be 0


            %*** FSEEK ***
            status = fseek(fid,obj.header_length,'bof');
            if status == -1
                error('Unexpected error when seeking to first page')
            end
        end
    end
end

function out = h_string_clean(str)
out = str;
out(out == 0) = [];
end

function matlab_time = h__unixToDatenum(unix_time)
SECONDS_IN_DAY = 86400;
UNIX_EPOCH = 719529;
matlab_time = unix_time./SECONDS_IN_DAY + UNIX_EPOCH;
end