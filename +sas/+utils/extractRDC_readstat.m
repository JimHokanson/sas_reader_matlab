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