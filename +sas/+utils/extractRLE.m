function b3 = extractRLE(b2,row_length,c_count)
%
%   b3 = sas.utils.extractRLE(b2,row_length);
%
%   TODO: Eventually this would be better in C (too much looping/logic)
%   TODO: Utilize row length to avoid array resizing
%
%   Outputs
%   -------
%   b3 : [n 1]
%
%
%   See Also
%   --------
%   sas.subheaders
%   sas.subheaders>processPageSubheaders


%https://github.com/pandas-dev/pandas/blob/b1525c4a3788d161653b04a71a84e44847bedc1b/pandas/_libs/sas.pyx#L61
%https://github.com/epam/parso/blob/3c514e66264f5f3d5b2970bc2509d749065630c0/src/main/java/com/epam/parso/impl/CharDecompressor.java#L48

%TODO: Why am I adding +1 to all the j values?

% if c_count == 5
%     keyboard
% end

cmds = {};
b3 = zeros(row_length,1,'uint8');
i = 0;
j = 1;
done = false;
%all_cmds = [];
while ~done
    next_control = b2(j);
    %upper 4 command, lower 4 length
    cmd = bitshift(next_control,-4);
    %all_cmds = [all_cmds cmd];
    len = double(bitand(next_control,15));

    cmds = [cmds {cmd}];

    %https://github.com/WizardMac/ReadStat/blob/dev/src/sas/readstat_sas_rle.c#L43
    %https://github.com/pandas-dev/pandas/blob/dc19148bf7197a928a129b1d1679b1445a7ea7c7/pandas/_libs/sas.pyx#L61
    switch cmd
        %{
            %https://github.com/epam/parso/blob/master/src/main/java/com/epam/parso/impl/CharDecompressor.java
            switch (controlByte) {
                case 0x30://intentional fall through
                case 0x20://intentional fall through
                case 0x10://intentional fall through
                case 0x00:
                    if (currentByteIndex != length - 1) {
                        countOfBytesToCopy = (page[offset + currentByteIndex + 1] & 0xFF) + 64
                           + page[offset + currentByteIndex] * 256;
                        System.arraycopy(page, offset + currentByteIndex + 2, resultByteArray,
                                currentResultArrayIndex, countOfBytesToCopy);
                        currentByteIndex += countOfBytesToCopy + 1;
                        currentResultArrayIndex += countOfBytesToCopy;
                    }
                    break;
        %}


        case 0 %SAS_RLE_COMMAND_COPY64
            copy_len = double(b2(j+1)) + 64 + len * 256;
            b3(i+1:i+copy_len) = b2(j+2:j+1+copy_len);
            j = j + copy_len + 2;
            i = i + copy_len;
        case 1 %SAS_RLE_COMMAND_COPY64_PLUS_4096
            %copy_len = (*input++) + 64 + length * 256 + 4096;
            copy_len = double(b2(j+1)) + 64 + len * 256 + 4096;
            keyboard
        case 2 %SAS_RLE_COMMAND_COPY96
            copy_len = len + 96;
            keyboard
        case 3
            keyboard
            error('Unrecognized option')
        case 4 %SAS_RLE_COMMAND_INSERT_BYTE18
            %0x40controlbyte.sas7bdat
            n_bytes = 18 + len*256 + double(b2(j+1));
            %b3(i+1:i+n_bytes) = repelem(b2(j+2),1,n_bytes);
            b3(i+1:i+n_bytes) = b2(j+2);
            i = i + n_bytes;
            %b3 = [b3 repelem(b2(j+2),1,n_bytes)];
            j = j + 3;
        case 5 %SAS_RLE_COMMAND_INSERT_AT17
            n_bytes = 17+len*256+double(b2(j+1));
            %b3(i+1:i+n_bytes) = repelem(uint8('@'),1,n_bytes);
            b3(i+1:i+n_bytes) = uint8('@');
            i = i + n_bytes;
            %b3 = [b3 repelem(uint8('@'),1,n_bytes)];
            j = j + 2;
        case 6 %SAS_RLE_COMMAND_INSERT_BLANK17
            n_bytes = 17+len*256+double(b2(j+1));
            %b3(i+1:i+n_bytes) = repelem(uint8(' '),1,n_bytes);
            b3(i+1:i+n_bytes) = uint8(' ');
            i = i + n_bytes;
            %b3 = [b3 repelem(uint8(' '),1,n_bytes)];
            j = j + 2;
        case 7 %SAS_RLE_COMMAND_INSERT_ZERO17
            n_bytes = 17+len*256+double(b2(j+1));
            %b3(i+1:i+n_bytes) = repelem(uint8(0),1,n_bytes);
            b3(i+1:i+n_bytes) = uint8(0);
            i = i + n_bytes;
            %b3 = [b3 repelem(uint8(0),1,n_bytes)];
            j = j + 2;
        case 8 %SAS_RLE_COMMAND_COPY1
            %copy next X
            n_bytes = len + 1;
            b3(i+1:i+n_bytes) = b2(j+1:j+n_bytes);
            i = i + n_bytes;
            %b3 = [b3 b2(j+1:j+n_bytes)];
            j = j + n_bytes + 1;
        case 9 %SAS_RLE_COMMAND_COPY17
            n_bytes = len + 17;
            b3(i+1:i+n_bytes) = b2(j+1:j+n_bytes);
            i = i + n_bytes;
            %b3 = [b3 b2(j+1:j+n_bytes)];
            j = j + n_bytes + 1;
        case 10 %SAS_RLE_COMMAND_COPY33
            n_bytes = len + 33;
            b3(i+1:i+n_bytes) = b2(j+1:j+n_bytes);
            i = i + n_bytes;
            %b3 = [b3 b2(j+1:j+n_bytes)];
            j = j + n_bytes + 1;
        case 11 %SAS_RLE_COMMAND_COPY49
            n_bytes = len + 49;
            b3(i+1:i+n_bytes) = b2(j+1:j+n_bytes);
            i = i + n_bytes;
            %b3 = [b3 b2(j+1:j+n_bytes)];
            j = j + n_bytes + 1;
        case 12 %SAS_RLE_COMMAND_INSERT_BYTE3
            n_bytes = len + 3;
            %b3(i+1:i+n_bytes) = repelem(b2(j+1),1,n_bytes);
            b3(i+1:i+n_bytes) = b2(j+1);
            i = i + n_bytes;
            %b3 = [b3 repelem(b2(j+1),1,n_bytes)];
            j = j + 2;
        case 13 %SAS_RLE_COMMAND_INSERT_AT2
            n_bytes = len + 2;
            %b3(i+1:i+n_bytes) = repelem(uint8('@'),1,n_bytes);
            b3(i+1:i+n_bytes) = uint8('@');
            i = i + n_bytes;
            %b3 = [b3 repelem(uint8('@'),1,n_bytes)];
            j = j + 1;
        case 14 %SAS_RLE_COMMAND_INSERT_BLANK2
            n_bytes = len + 2;
            %b3(i+1:i+n_bytes) = repelem(uint8(32),1,n_bytes);
            b3(i+1:i+n_bytes) = uint8(32);
            i = i + n_bytes;
            %b3 = [b3 repelem(uint8(32),1,n_bytes)];
            j = j + 1;
        case 15 %SAS_RLE_COMMAND_INSERT_ZERO2
            n_bytes = len + 2;
            %b3(i+1:i+n_bytes) = repelem(uint8(0),1,n_bytes);
            b3(i+1:i+n_bytes) = uint8(0);
            i = i + n_bytes;
            %b3 = [b3 repelem(uint8(0),1,n_bytes)];
            j = j + 1;
        otherwise
            error('Unrecognized option')
    end
    done = j > length(b2);
end

%b3 = b3';

end