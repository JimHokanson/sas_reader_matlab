#include "mex.h"
#include <stdint.h>
#include <string.h>



int sas7bdat_parse_subheader_rdc(const char *in_buffer, size_t len, char *buffer, size_t row_length) {
    int retval = 0;
    const unsigned char *input = (const unsigned char *)in_buffer;
    char *output = buffer;
    while (input + 2 <= (const unsigned char *)in_buffer + len) {
        int i;
        unsigned short prefix = (input[0] << 8) + input[1];
        input += 2;
        for (i=0; i<16; i++) {
            if ((prefix & (1 << (15 - i))) == 0) {
                if (input + 1 > (const unsigned char *)in_buffer + len) {
                    break;
                }
                if (output + 1 > buffer + row_length) {
                    retval = 1;
                    break;
                }
                *output++ = *input++;
                continue;
            }

            if (input + 2 > (const unsigned char *)in_buffer + len) {
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
                if (input + 1 > (const unsigned char *)in_buffer + len) {
                    retval = 3;
                    break;
                }
                insert_len = 19 + (marker_byte & 0x0F) + next_byte * 16;
                insert_byte = *input++;
            } else if ((marker_byte >> 4) == 2) {
                if (input + 1 > (const unsigned char *)in_buffer + len) {
                    retval = 4;
                    break;
                }
                copy_len = 16 + (*input++);
                back_offset = 3 + (marker_byte & 0x0F) + next_byte * 16;
            } else {
                copy_len = (marker_byte >> 4);
                back_offset = 3 + (marker_byte & 0x0F) + next_byte * 16;
            }

            if (insert_len) {
                if (output + insert_len > buffer + row_length) {
                    retval = 5;
                    break;
                }
                memset(output, insert_byte, insert_len);
                output += insert_len;
            } else if (copy_len) {
                if (output - buffer < back_offset || copy_len > back_offset) {
                    retval = 6;
                    break;
                }
                if (output + copy_len > buffer + row_length) {
                    retval = 7;
                    break;
                }
                memcpy(output, output - back_offset, copy_len);
                output += copy_len;
            }
        }
    }

    return retval;
}


void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // Check input and output arguments
    if (nrhs != 2) {
        mexErrMsgIdAndTxt("MATLAB:fill_array:nrhs", "Two inputs required.");
    }
    if (!mxIsUint8(prhs[0]) || mxGetNumberOfElements(prhs[0]) < 1) {
        mexErrMsgIdAndTxt("MATLAB:fill_array:notUint8Array", "Input must be a non-empty uint8 array.");
    }
    if (!mxIsDouble(prhs[1]) || mxIsComplex(prhs[1]) || mxGetNumberOfElements(prhs[1]) != 1) {
        mexErrMsgIdAndTxt("MATLAB:fill_array:notDoubleScalar", "Input must be a noncomplex double scalar.");
    }
    
    // Get input data
    uint8_t *inputArray = (uint8_t *) mxGetData(prhs[0]);
    uint32_t inbuff_len = (uint32_t) mxGetNumberOfElements(prhs[0]);
    uint32_t row_length = (uint32_t) mxGetScalar(prhs[1]);
    
    // Create output array
    plhs[0] = mxCreateNumericMatrix(1, (mwSize)row_length, mxUINT8_CLASS, mxREAL);
    uint8_t *outputArray = (uint8_t *) mxGetData(plhs[0]);

    sas7bdat_parse_subheader_rdc(inputArray,inbuff_len,outputArray,row_length);

}

