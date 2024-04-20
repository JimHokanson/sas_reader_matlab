function b3 = extractRDC(b2,row_length)
%
%   b3 = sas.utils.extractRDC(b2,row_length);
%
%
%   https://web.archive.org/web/20150408232213/https://collaboration.cmc.ec.gc.ca/science/rpn/biblio/ddj/Website/articles/CUJ/1992/9210/ross/ross.htm

%https://github.com/pandas-dev/pandas/blob/b1525c4a3788d161653b04a71a84e44847bedc1b/pandas/_libs/sas.pyx#L159
%https://github.com/WizardMac/ReadStat/blob/887d3a1bbcf79c692923d98f8b584b32a50daebd/src/sas/readstat_sas7bdat_read.c#L506
%https://github.com/epam/parso/blob/3c514e66264f5f3d5b2970bc2509d749065630c0/src/main/java/com/epam/parso/impl/BinDecompressor.java#L59



b3 = extractRDC_mex(b2,row_length)';
% b3 = b4;


% b3 = rdc_decompress(b2, row_length);
% %Must be column vector
% b3 = b3(:);
% b3 = rdc_decompress2(b2,row_length);
%b4 = rdc_parse1(b2, row_length);

end



function outbuff = rdc_decompress2(inbuff,out_len)
    inbuff_len = length(inbuff);
    outbuff = zeros(out_len,1,'uint8');
    
    ctrl_mask = 0;
    ctrl_bits = uint16(0);
    ipos = 1;
    rpos = 1;

    %fprintf('--------------------------------------\n')

    while ipos <= inbuff_len
        % Get new load of control bits if needed
        ctrl_mask = bitshift(ctrl_mask, -1);
        if ctrl_mask == 0
            %ctrl_bits = typecast(uint8(inbuff(inbuff_idx:inbuff_idx+1)), 'uint16');
            %ctrl_bits = uint16(inbuff(inbuff_idx))*256 + uint16(inbuff(inbuff_idx+1));
            ctrl_bits = typecast([inbuff(ipos+1) inbuff(ipos)],'uint16');
            %fprintf('new ctrl: %d, %d\n',ctrl_bits,ipos)
            ipos = ipos + 2;
            ctrl_mask = 32768; % 0x8000
        end

        % Just copy this char if control bit is zero
        if bitand(ctrl_bits, ctrl_mask) == 0
            %fprintf('--%d, %d, %d, %d\n',ctrl_bits,ctrl_mask,ipos,rpos)
            outbuff(rpos) = inbuff(ipos);
            rpos = rpos + 1;
            ipos = ipos + 1;
            continue;
        end

        %fprintf('----------\n%d, %d,',ctrl_bits,ctrl_mask)

        % Undo the compression code
        cmd = bitshift(bitand(uint16(inbuff(ipos)), 240), -4); % Extract command
        cnt = bitand(uint16(inbuff(ipos)), 15); % Extract count
        ipos = ipos + 1;

        %fprintf('%d, %d, %d,%d\n',cmd,cnt,ipos,rpos)

        switch cmd
            case 0 % Short RLE
                cnt = cnt + 3;
                outbuff(rpos:rpos+cnt-1) = inbuff(ipos);
                ipos = ipos + 1;
                rpos = rpos + cnt;

            case 1 % Long RLE
                cnt = cnt + bitshift(uint16(inbuff(ipos)), 4) + 19;
                ipos = ipos + 1;
                outbuff(rpos:rpos+cnt-1) = inbuff(ipos);
                ipos = ipos + 1;
                rpos = rpos + cnt;

            case 2 % Long Pattern
                ofs = cnt + 3 + bitshift(uint16(inbuff(ipos)), 4);
                ipos = ipos + 1;
                cnt = uint16(inbuff(ipos)) + 16;
                ipos = ipos + 1;
                outbuff(rpos:rpos+cnt-1) = outbuff(rpos-ofs:rpos-ofs+cnt-1);
                rpos = rpos + cnt;

            otherwise % Short Pattern
                ofs = cnt + 3 + bitshift(uint16(inbuff(ipos)), 4);
                ipos = ipos + 1;
                outbuff(rpos:rpos+cmd-1) = outbuff(rpos-ofs:rpos-ofs+cmd-1);
                rpos = rpos + cmd;
        end
        
    end
end

%{
static readstat_error_t sas7bdat_parse_subheader_rdc(const char *subheader, size_t len, size_t row_length) {
    int retval = 0;
    const unsigned char *input = (const unsigned char *)subheader;
    char *buffer = malloc(row_length);
    char *output = buffer;
    while (input + 2 <= (const unsigned char *)subheader + len) {
        int i;
        unsigned short prefix = (input[0] << 8) + input[1];
        input += 2;
        for (i=0; i<16; i++) {
            if ((prefix & (1 << (15 - i))) == 0) {
                if (input + 1 > (const unsigned char *)subheader + len) {
                    break;
                }
                if (output + 1 > buffer + row_length) {
                    retval = 1;
                    break;
                }
                *output++ = *input++;
                continue;
            }

            if (input + 2 > (const unsigned char *)subheader + len) {
                retval = 2;
                break;
            }

            unsigned char marker_byte = *input++;
            unsigned char next_byte = *input++;
            size_t insert_len = 0, copy_len = 0;
            unsigned char insert_byte = 0x00;
            size_t back_offset = 0;

            if (marker_byte <= 0x0F) {
                insert_len = 3 + marker_byte;
                insert_byte = next_byte;
            } else if ((marker_byte >> 4) == 1) {
                if (input + 1 > (const unsigned char *)subheader + len) {
                    retval = 2;
                    break;
                }
                insert_len = 19 + (marker_byte & 0x0F) + next_byte * 16;
                insert_byte = *input++;
            } else if ((marker_byte >> 4) == 2) {
                if (input + 1 > (const unsigned char *)subheader + len) {
                    retval = 2;
                    break;
                }
                copy_len = 16 + (*input++);
                back_offset = 3 + (marker_byte & 0x0F) + next_byte * 16;
            } else {
                copy_len = (marker_byte >> 4);
                back_offset = 3 + (marker_byte & 0x0F) + next_byte * 16;
            }

            if (insert_len) {
                if (output + insert_len > buffer + ctx->row_length) {
                    retval = 3;
                    break;
                }
                memset(output, insert_byte, insert_len);
                output += insert_len;
            } else if (copy_len) {
                if (output - buffer < back_offset || copy_len > back_offset) {
                    retval = 2;
                    break;
                }
                if (output + copy_len > buffer + ctx->row_length) {
                    retval = 4;
                    break;
                }
                memcpy(output, output - back_offset, copy_len);
                output += copy_len;
            }
        }
    }
}

%}

 



