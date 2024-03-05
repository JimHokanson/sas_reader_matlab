classdef header < handle
    %
    %   Class:
    %   sas.header

    properties
        start_position

        %1:32
        magic_number
        
        %33
        a2  % 4 if b33 == 51, else 0
        b33_a2 %byte 33 (from which a2 is derived)
        %computed
        is_u64 %if a2 == 4

        %34:35
        unknown34   
        unknown37  
        unknown39
        unknown41
        unknown72
        unknown125

        %36
        a1
        pad1
        b36_a1

        
        
        %37
        %unknown37
        

        %38
        is_little_endian
        

        %39
        %unknown39

        %40
        %FORM_DOC: renamed from os_type
        file_format

        %41
        %unknown41

        %71
        %https://github.com/WizardMac/ReadStat/blob/887d3a1bbcf79c692923d98f8b584b32a50daebd/src/sas/readstat_sas.c#L45
        %
        %FORM_DOC: WizardMac is saying only 1 byte, not 2
        character_encoding_raw

        %computed
        character_encoding_name

        %72:84
        %unknown72

        %85:92
        file_type %Should = 'SAS FILE'

        %93:124
        table_name

        %125:156
        %unknown125

        %157:164
        file_info

        %Format - 
        creation_time_raw
        modification_time_raw
        creation_time_diff
        modification_time_diff
        creation_time_datenum
        creation_time_datestr
        modification_time_datenum
        modification_time_datestr

        header_length
        page_length
        page_count
        sas_release
        sas_host
        os_version_number
        os_maker
        os_name
    end


    %{
    readstat_error_t sas_read_header(readstat_io_t *io, sas_header_info_t *ctx, readstat_error_handler error_handler, void *user_ctx)

    retval = sas_read_header(io, hinfo, ctx->handle.error, user_ctx)) != READSTAT_OK

    ctx:
    typedef struct sas_header_start_s {
        unsigned char magic[32];           1:32     
        unsigned char a2;                  33
        unsigned char mystery1[2];         34:35
        unsigned char a1;                  36 
        unsigned char mystery2[1];         37 
        unsigned char endian;              38
        unsigned char mystery3[1];         39 
        char          file_format;         40
        unsigned char mystery4[30];        41:70 
        unsigned char encoding;            71     
        unsigned char mystery5[13];        72:84 
        char          file_type[8];        85:92  
        char          table_name[32];      93:124
        unsigned char mystery6[32];        125:156
        char          file_info[8];        157:
    } sas_header_start_t;

    hinfo
    ctx:
        typedef struct sas_header_info_s {
            int      little_endian;
            int      u64;
            int      vendor;
            int      major_version;
            int      minor_version;
            int      revision;
            int      pad1;
            int64_t  page_size;
            int64_t  page_header_size;
            int64_t  subheader_pointer_size;
            int64_t  page_count;
            int64_t  header_size;
            time_t   creation_time;
            time_t   modification_time;
            char     table_name[32];
            char     file_label[256];
            char    *encoding;
        } sas_header_info_t;
    
    %}

    methods
        function obj = header(fid)
            %
            %   h = sas.header(fid)

            %https://github.com/WizardMac/ReadStat/blob/887d3a1bbcf79c692923d98f8b584b32a50daebd/src/sas/readstat_sas.c#L161

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
            bytes = fread(fid,1024,"*uint8")';

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
            if bytes(40) == 1
                obj.file_format = 'unix';
            else
                obj.file_format = 'windows';
            end

            %https://github.com/WizardMac/ReadStat/blob/887d3a1bbcf79c692923d98f8b584b32a50daebd/src/sas/readstat_sas.c#L45
            %obj.character_encoding_raw = typecast(bytes(71:72),'int16');
            obj.character_encoding_raw = bytes(71);

            obj.file_type = char(bytes(85:92));
            obj.table_name = strtrim(char(bytes(93:124)));
            %unknown125
            obj.file_info = strtrim(char(bytes(157:164)));
            

            %Skipping forward by variable amount
            a12 = obj.a1+obj.a2;


            %Processing of the times
            %---------------------------------------------
            obj.creation_time_raw = typecast(bytes(165+a12:172+a12),'double');
            obj.modification_time_raw = typecast(bytes(173+a12:180+a12),'double');
            %FORM_DOC
            %- not sure these are documented ...
            obj.creation_time_diff = typecast(bytes(181+a12:188+a12),'double');
            obj.modification_time_diff = typecast(bytes(189+a12:196+a12),'double');

            
            temp = obj.creation_time_raw - obj.creation_time_diff - (3653 * 86400);
            obj.creation_time_datenum = h__unixToDatenum(temp);
            obj.creation_time_datestr = datestr(obj.creation_time_datenum); %#ok<DATST>

            temp = obj.modification_time_raw - obj.modification_time_diff - (3653 * 86400);
            obj.modification_time_datenum = h__unixToDatenum(temp);
            obj.modification_time_datestr = datestr(obj.modification_time_datenum); %#ok<DATST>

            %------------------------------------------
            obj.header_length = typecast(bytes(197+a12:200+a12),'uint32');
            obj.page_length = typecast(bytes(201+a12:204+a12),'uint32');
            obj.page_count = typecast(bytes(205+a12:208+a12),'uint32');

            %209:216

            %TODO: Lots missing from here ...
            %Haven't copmpared to MacWizard's version ...

            obj.sas_release = char(bytes(217+a12:224+a12));
            obj.sas_host = h_string_clean(char(bytes(225+a12:240+a12)));
            obj.os_version_number = char(bytes(241+a12:256+a12));
            obj.os_maker = char(bytes(257+a12:272+a12));
            obj.os_name = char(bytes(273+a12:288+a12));

            status = fseek(fid,obj.header_length,'bof');
            if status == -1
                oerror('Unexpected error when seeking to first page')
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