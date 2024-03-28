function b3 = extractCompressed(b2,row_length)
%
%   b3 = sas.utils.extractCompressed(b2);
%
%   TODO: Eventually this would be better in C (too much looping/logic)
%   TODO: Utilize row length to avoid array resizing

%https://github.com/epam/parso/blob/3c514e66264f5f3d5b2970bc2509d749065630c0/src/main/java/com/epam/parso/impl/CharDecompressor.java#L48

b3 = [];
j = 1;
done = false;
all_cmds = [];
while ~done
    next_control = b2(j);
    %upper 4 command, lower 4 length
    cmd = bitshift(next_control,-4);
    all_cmds = [all_cmds cmd];
    len = double(bitand(next_control,15));

    %https://github.com/WizardMac/ReadStat/blob/dev/src/sas/readstat_sas_rle.c#L43
    %https://github.com/pandas-dev/pandas/blob/dc19148bf7197a928a129b1d1679b1445a7ea7c7/pandas/_libs/sas.pyx#L61
    switch cmd
        %{
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
            keyboard
        case 1 %SAS_RLE_COMMAND_COPY64_PLUS_4096
            keyboard
        case 2 %SAS_RLE_COMMAND_COPY96
            keyboard
        case 3
            keyboard
            error('Unrecognized option')
        case 4 %SAS_RLE_COMMAND_INSERT_BYTE18
            %0x40controlbyte.sas7bdat
            n_bytes = 18 + len*256 + double(b2(j+1));
            b3 = [b3 repelem(b2(j+2),1,n_bytes)];
            j = j + 3;
        case 5 %SAS_RLE_COMMAND_INSERT_AT17
            n_bytes = 17 + len*256;
            b3 = [b3 repelem(uint8('@'),1,n_bytes)];
            j = j + 1;
        case 6 %SAS_RLE_COMMAND_INSERT_BLANK17
            n_bytes = 17+len*256;
            b3 = [b3 repelem(uint8(' '),1,n_bytes)];
            j = j + 1;
        case 7 %SAS_RLE_COMMAND_INSERT_ZERO17
            n_bytes = 17+len*256;
            b3 = [b3 repelem(uint8(0),1,n_bytes)];
            j = j + 1;
        case 8 %SAS_RLE_COMMAND_COPY1
            %copy next X
            n_bytes = len + 1;
            b3 = [b3 b2(j+1:j+n_bytes)];
            j = j + n_bytes + 1;
        case 9 %SAS_RLE_COMMAND_COPY17
            n_bytes = len + 17;
            b3 = [b3 b2(j+1:j+n_bytes)];
            j = j + n_bytes + 1;
        case 10 %SAS_RLE_COMMAND_COPY33
            n_bytes = len + 33;
            b3 = [b3 b2(j+1:j+n_bytes)];
            j = j + n_bytes + 1;
        case 11 %SAS_RLE_COMMAND_COPY49
            n_bytes = len + 49;
            b3 = [b3 b2(j+1:j+n_bytes)];
            j = j + n_bytes + 1;
        case 12 %SAS_RLE_COMMAND_INSERT_BYTE3
            n_bytes = len + 3;
            b3 = [b3 repelem(b2(j+1),1,n_bytes)];
            j = j + 1;
        case 13 %SAS_RLE_COMMAND_INSERT_AT2
            n_bytes = len + 2;
            b3 = [b3 repelem(uint8('@'),1,n_bytes)];
            j = j + 1;
        case 14 %SAS_RLE_COMMAND_INSERT_BLANK2
            n_bytes = len + 2;
            b3 = [b3 repelem(uint8(32),1,n_bytes)];
            j = j + 1;
        case 15 %SAS_RLE_COMMAND_INSERT_ZERO2
            n_bytes = len + 2;
            b3 = [b3 repelem(uint8(0),1,n_bytes)];
            j = j + 1;
        otherwise
            error('Unrecognized option')
    end
    done = j > length(b2);
end

b3 = b3';

end