// Spindle by lft, http://www.linusakesson.net/software/spindle/

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <err.h>

#include "pefchain.h"

static int blocksize = 256;
static int blockpad = 0;

#define BITS_OFFSET 5
#define BITS_LENGTH 3
#define BITS_LITERAL 3
#define EXTRABITS_LENGTH 5
#define EXTRABITS_OFFSET 7
#define MINLENGTH 2

#define NBITS ((blocksize - 3) * 8)
#define MAXLENGTH (MINLENGTH + (1 << BITS_LENGTH) + (1 << EXTRABITS_LENGTH) - 2)
#define MAXOFFSET (1 + (1 << BITS_OFFSET) - 2 + (1 << EXTRABITS_OFFSET))

enum {
	P_LITERAL,
	P_COPY
};

struct piece {
	uint8_t		kind;
	uint8_t		length;
	uint16_t	offset;
};

static uint8_t shifter;
static int bits_in_shifter;

static int copy_bitcount(int offset, int length) {
	return 8 +
		(offset >= (1 << BITS_OFFSET)) * EXTRABITS_OFFSET +
		(length >= (1 << BITS_LENGTH) - 1 + MINLENGTH) * EXTRABITS_LENGTH;
}

static void putbyte(uint8_t *block, int *blockpos, int *revpos, int b) {
	if(*revpos < *blockpos) errx(1, "Byte collides with bit stream");
	block[(*blockpos)++] = b;
}

static void putbits(uint8_t *block, int *blockpos, int *revpos, int v, int width) {
	int i;

	if(v >= 1 << width) errx(1, "Trying to fit %d into %d bits", v, width);
	for(i = 0; i < width; i++) {
		shifter <<= 1;
		if(v & (1 << (width - 1 - i))) shifter |= 1;
		if(++bits_in_shifter == 8) {
			if(*blockpos > *revpos) errx(1, "Bit stream collides with byte");
			block[(*revpos)--] = shifter;
			bits_in_shifter = 0;
		}
	}
}

void compress(struct blockmap *bm, uint8_t *data, uint16_t loadsize, uint16_t loadaddr, char *fname) {
	uint16_t start = 0;
	struct piece piece[blocksize], *pi;
	int npiece, bitcount, i, j, pos, nblock = 0;
	int offset, length, max, argmax;
	int need_select, blockpos, revpos;
	uint8_t b, block[blocksize + blockpad];

	if(verbose >= 2) {
		fprintf(stderr,
			"Crunching %d bytes at $%04x-$%04x from \"%s\"\n",
			loadsize,
			loadaddr,
			loadaddr + loadsize - 1,
			fname);
	}

	while(start < loadsize) {
		npiece = 0;
		bitcount = 0;
		pos = 0;
		need_select = 0;
		while(start + pos < loadsize) {
			argmax = 0;
			max = 0;
			for(offset = 1; offset <= pos && offset <= MAXOFFSET; offset++) {
				length = 0;
				for(;;) {
					if(start + pos + length >= loadsize
					|| length == MAXLENGTH
					|| data[start + pos + length] != data[start + pos - offset + length]) {
						break;
					} else {
						length++;
					}
				}
				if(length > max) {
					max = length;
					argmax = offset;
				}
			}
			if(max >= MINLENGTH) {
				piece[npiece].kind = P_COPY;
				piece[npiece].offset = argmax;
				piece[npiece].length = max;
				if(need_select) bitcount++;
				bitcount += copy_bitcount(argmax, max);
				if(bitcount > NBITS) break;
				npiece++;
				pos += max;
				need_select = 1;
			} else {
				bitcount += 8;
				if(bitcount > NBITS) break;
				if(npiece
				&& piece[npiece - 1].kind == P_LITERAL
				&& piece[npiece - 1].length < (1 << BITS_LITERAL)) {
					if(++piece[npiece - 1].length == (1 << BITS_LITERAL)) {
						need_select = 1;
					}
				} else {
					if(need_select) bitcount++;
					bitcount += BITS_LITERAL;
					if(bitcount > NBITS) break;
					piece[npiece].kind = P_LITERAL;
					piece[npiece].offset = pos;
					piece[npiece].length = 1;
					npiece++;
					need_select = 0;
				}
				pos++;
			}
		}

		memset(block, 0, sizeof(block));
		block[0] = (loadaddr + start) & 255;
		block[1] = (loadaddr + start) >> 8;
		block[2] = npiece;

		blockpos = 3;
		revpos = blocksize - 1;
		need_select = 0;
		for(i = 0; i < npiece; i++) {
			pi = &piece[i];
			switch(pi->kind) {
				case P_LITERAL:
					if(need_select) {
						putbits(block, &blockpos, &revpos, 1, 1);
					}
					putbits(block, &blockpos, &revpos,
						pi->length - 1,
						BITS_LITERAL);
					for(j = 0; j < pi->length; j++) {
						putbyte(block, &blockpos, &revpos,
							data[start + pi->offset + j]);
					}
					need_select = (pi->length == (1 << BITS_LITERAL));
					break;
				case P_COPY:
					if(need_select) {
						putbits(block, &blockpos, &revpos, 0, 1);
					}
					b = 0;
					if(pi->offset >= (1 << BITS_OFFSET)) {
						putbits(block, &blockpos, &revpos,
							pi->offset - (1 << BITS_OFFSET),
							EXTRABITS_OFFSET);
					} else {
						b |= pi->offset;
					}
					if(pi->length >= (1 << BITS_LENGTH) + MINLENGTH - 1) {
						putbits(block, &blockpos, &revpos,
							pi->length - (1 << BITS_LENGTH) - MINLENGTH + 1,
							EXTRABITS_LENGTH);
					} else {
						b |= (pi->length - MINLENGTH + 1) << BITS_OFFSET;
					}
					putbyte(block, &blockpos, &revpos, b);
					need_select = 1;
					break;
			}
		}
		while(bits_in_shifter) putbits(block, &blockpos, &revpos, 0, 1);

		if(verbose >= 2) {
			fprintf(stderr, "Block at $%04x-$%04x (%4d bytes) in %3d pieces into %3d bytes, effective ratio %d%%\n",
				loadaddr + start,
				loadaddr + start + pos - 1,
				pos,
				npiece,
				blockpos + (blocksize - 1 - revpos),
				blocksize * 100 / pos);
		}

		store_block(bm, block);
		nblock++;
		start += pos;
	}

	if(verbose >= 2) {
		i = (loadsize + 253) / 254;
		fprintf(stderr,
			"Used %d blocks. Original would need %d blocks. Total ratio: %d%%\n",
			nblock,
			i,
			nblock * 100 / i);
	}
}
