#include "mex.h"
#include <stdint.h>
#include <string.h>


// mex extractRDC_mex.c
//
//  b3 = extractRDC_mex(b2,len_val);




/* DECOMPRS.C - Ross Data Compression (RDC)
 *              decompress function
 *
 * Written by Ed Ross, 1/92
 *
 * decompress inbuff_len bytes of inbuff into outbuff.
   return length of outbuff.                        */




int rdc_decompress(uint8_t *inbuff, uint16_t inbuff_len, uint8_t *outbuff)
{
uint16_t   ctrl_bits;
uint16_t   ctrl_mask = 0;
uint8_t  *inbuff_idx = inbuff;
uint8_t  *outbuff_idx = outbuff;
uint8_t  *inbuff_end = inbuff + inbuff_len;
uint16_t   cmd;
uint16_t   cnt;
uint16_t   ofs;
uint16_t   len;

/* process each item in inbuff */
  
  while (inbuff_idx < inbuff_end)
  {
    /* get new load of control bits if needed */

    if ((ctrl_mask >>= 1) == 0)
    {
      //This may be problematic and read past boundary - I think ...
      //ctrl_bits = * (uint16_t *) inbuff_idx;
      ctrl_bits = ((uint16_t) *inbuff_idx) << 8;
      inbuff_idx++;
      ctrl_bits += (uint16_t) *inbuff_idx;
      inbuff_idx++;
      ctrl_mask = 0x8000;
    }

    /* just copy this char if control bit is zero */

    if ((ctrl_bits & ctrl_mask) == 0)
    {
      //JAH FIX *outbuff_idx++ == *inbuff_idx++;

      *outbuff_idx = *inbuff_idx;
      outbuff_idx++;
      inbuff_idx++;
      continue;
    }

    /* undo the compression code */

    cmd = (*inbuff_idx >> 4) & 0x00F;
    cnt = *inbuff_idx++ & 0x00F;

    switch (cmd)
    {
    case 0:     /* short rle */
        cnt += 3;
        memset(outbuff_idx, *inbuff_idx++, cnt);
        outbuff_idx += cnt;
        break;

    case 1:     /* long /rle */
        cnt += (*inbuff_idx++ << 4);
        cnt += 19;
        memset(outbuff_idx, *inbuff_idx++, cnt);
        outbuff_idx += cnt;
        break;

    case 2:     /* long pattern */
        ofs = cnt + 3;
        ofs += (*inbuff_idx++ << 4);
        cnt = *inbuff_idx++;
        cnt += 16;
        memcpy(outbuff_idx, outbuff_idx - ofs, cnt);
        outbuff_idx += cnt;
        break;

    default:    /* short pattern */
        ofs = cnt + 3;
        ofs += (*inbuff_idx++ << 4);
        memcpy(outbuff_idx, outbuff_idx - ofs, cmd);
        outbuff_idx += cmd;
        break;
    }
  }

  /* return length of decompressed buffer */

  return outbuff_idx - outbuff;
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
    uint16_t inbuff_len = (uint16_t) mxGetScalar(prhs[1]);
    
    // Create output array
    plhs[0] = mxCreateNumericMatrix(1, (mwSize)inbuff_len, mxUINT8_CLASS, mxREAL);
    uint8_t *outputArray = (uint8_t *) mxGetData(plhs[0]);

    //rdc_decompress(inputArray,inbuff_len,outputArray);

}




//https://github.com/WizardMac/ReadStat/blob/dev/src/sas/readstat_sas7bdat_read.c

//TODO: Use this instead so we can avoid crashes
/*
static readstat_error_t sas7bdat_parse_subheader_rdc(const char *subheader, size_t len, sas7bdat_ctx_t *ctx) {
    int retval = 0;
    const unsigned char *input = (const unsigned char *)subheader;
    char *buffer = malloc(ctx->row_length);
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
                if (output + 1 > buffer + ctx->row_length) {
                    retval = -1;
                    break
                }
                *output++ = *input++;
                continue;
            }

            if (input + 2 > (const unsigned char *)subheader + len) {
                retval = READSTAT_ERROR_PARSE;
                goto cleanup;
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
                    retval = READSTAT_ERROR_PARSE;
                    goto cleanup;
                }
                insert_len = 19 + (marker_byte & 0x0F) + next_byte * 16;
                insert_byte = *input++;
            } else if ((marker_byte >> 4) == 2) {
                if (input + 1 > (const unsigned char *)subheader + len) {
                    retval = READSTAT_ERROR_PARSE;
                    goto cleanup;
                }
                copy_len = 16 + (*input++);
                back_offset = 3 + (marker_byte & 0x0F) + next_byte * 16;
            } else {
                copy_len = (marker_byte >> 4);
                back_offset = 3 + (marker_byte & 0x0F) + next_byte * 16;
            }

            if (insert_len) {
                if (output + insert_len > buffer + ctx->row_length) {
                    retval = READSTAT_ERROR_ROW_WIDTH_MISMATCH;
                    goto cleanup;
                }
                memset(output, insert_byte, insert_len);
                output += insert_len;
            } else if (copy_len) {
                if (output - buffer < back_offset || copy_len > back_offset) {
                    retval = READSTAT_ERROR_PARSE;
                    goto cleanup;
                }
                if (output + copy_len > buffer + ctx->row_length) {
                    retval = READSTAT_ERROR_ROW_WIDTH_MISMATCH;
                    goto cleanup;
                }
                memcpy(output, output - back_offset, copy_len);
                output += copy_len;
            }
        }
    }

    if (output - buffer != ctx->row_length) {
        retval = READSTAT_ERROR_ROW_WIDTH_MISMATCH;
    }

    return retval;
}

*/