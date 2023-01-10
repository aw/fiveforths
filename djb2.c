/*
FiveForths - https://github.com/aw/FiveForths
RISC-V Forth implementation

The MIT License (MIT)
Copyright (c) 2021~ Alexander Williams, https://a1w.ca
*/

#include <stdio.h>
#include <string.h>

// source: http://www.cse.yorku.ca/~oz/hash.html
unsigned long djb2(unsigned char *str)
{
    unsigned long hash = 5381;
    int c;

    while (c = *str++)
        hash = ((hash << 5) + hash) + c; /* hash * 33 + c */

    return hash;
}

int main(int argc, char *argv[]) {
    unsigned char *str = argv[1];
    unsigned long result = djb2(str);

    int length = strlen(str) << 24; // move the length to the last 8 bits (MSG) by shifting length by 24
    result = result & ~0xff000000;  // zero out the 8-bit flags+length by inverting the mask
    result = result | length;       // add the length of the string to the hash by bitwise OR'ing

    printf("djb2_hash: 0x%08x\n", result );

    return 0;
}
