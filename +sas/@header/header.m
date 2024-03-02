classdef header < handle
    %
    %   Class:
    %   sas.header

    properties
        start_position
        magic_number
        
        a2
        b33_a2

        a1
        b36_a1

        unknown1
        is_u64
        is_little_endian
        os_type
        character_encoding_raw
        character_encoding_name
        b85 %Should = 'SAS FILE'
        dataset_name
        b157
        time1
        time2
        header_length
        page_length
        page_count
        sas_release
        sas_host
        os_version_number
        os_maker
        os_name
    end

    methods
        function obj = header(fid)
            %
            %   h = sas.header(fid)

            %1:32 : magic number
            %33: a2
            %34:35 unknown1
            %36: a1
            %37: unknown2
            %38: endian-ness
            %   - 0 big
            %   - 1 little
            %   - 
            %39: unknown3
            %40: os_type
            %   - 1 - unix
            %   - 2 - windows - only impacts strings
            %41:48 :: unknown4
            %
            %



            obj.start_position = ftell(fid);
            bytes = fread(fid,1024,"*uint8")';

            obj.magic_number = bytes(1:32);
            
            obj.b33_a2 = bytes(33);
            obj.a2 = 4*(bytes(33) == 51);
            obj.unknown1 = bytes(34:35);

            %I'm seeing 34, not 51, why????
            %obj.a2 = 4*(bytes(33) ~= 0);
            obj.is_u64 = obj.a2 == 4;

            % if obj.is_u64
            %     b2 = fread(fid,8192-1024,"*uint8")';
            %     bytes = [bytes b2];
            % end

            obj.a1 = 4*(bytes(36) == 51);
            obj.b36_a1 = bytes(36);

            obj.is_little_endian = bytes(38) == 1;
            if bytes(40) == 1
                obj.os_type = 'unix';
            else
                obj.os_type = 'windows';
            end

            obj.character_encoding_raw = typecast(bytes(71:72),'int16');

            obj.b85 = char(bytes(85:85+7));
            %TODO: Remove trailing zeros - strtrim doesn't fix ...
            obj.dataset_name = strtrim(char(bytes(93:93+63)));
            obj.b157 = char(bytes(157:157+7));
            
            a12 = obj.a1+obj.a2;


            obj.time1 = bytes(164+a12:164+a12+7);
            obj.time2 = bytes(172+a12:172+a12+7);
            obj.header_length = typecast(bytes(197+a12:197+a12+3),'uint32');
            obj.page_length = typecast(bytes(201+a12:201+a12+3),'uint32');
            obj.page_count = typecast(bytes(205+a12:205+a12+3),'uint32');

            obj.sas_release = char(bytes(217+a12:217+a12+7));
            obj.sas_host = char(bytes(225+a12:225+a12+15));
            obj.os_version_number = char(bytes(241+a12:241+a12+15));
            obj.os_maker = char(bytes(257+a12:257+a12+15));
            obj.os_name = char(bytes(273+a12:273+a12+15));

            status = fseek(fid,obj.header_length,'bof');
            if status == -1
                oerror('Unexpected error when seeking to first page')
            end


% header_length
%         page_size
%         page_length
%         page_count
%         sas_release
%         sas_host
%         os_version_number
%         os_marker
%         os_name

            
        end
    end
end