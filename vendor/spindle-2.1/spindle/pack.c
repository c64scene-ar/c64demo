/* Spindle by lft, http://www.linusakesson.net/software/spindle/
 */

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <err.h>

#include "disk.h"
#include "pack.h"

#define MAXOFFSET 256
#define MAXMLENGTH 62
#define MAXLLENGTH 87
#define EOFBITS 8

int histogram_lit[MAXLLENGTH];
int histogram_match[MAXMLENGTH][MAXOFFSET];

struct chain {
	struct chain		*next;
	int			is_literal:1;
	int			offset:15;
	uint16_t		length;
	uint32_t		bits;
};

struct chaincache {
	struct chaincache	*next;
	struct chain		chain;
	uint16_t		pos;
	uint16_t		end;
};

struct arena {
	struct arena		*next;
	void			*data;
	int			pos;
	int			size;
};

struct blockbuilder {
	uint8_t			*blockbuf;
	int			pos;
	int			revpos;
	uint8_t			shifter;
	int			bits_in_shifter;
	int			bitsleft;
	int			is_meta;
};

static void *arena_alloc(struct arena **arena, int size) {
	void *ptr;
	struct arena *a;

	if(!*arena || ((*arena)->size - (*arena)->pos < size)) {
		a = malloc(sizeof(struct arena));
		a->pos = 0;
		a->size = 65536 + size;
		a->data = malloc(a->size);
		a->next = *arena;
		*arena = a;
	}

	ptr = (*arena)->data + (*arena)->pos;
	(*arena)->pos += size;

	return ptr;
}

static void putbyte(struct blockbuilder *bb, int v) {
	//fprintf(stderr, "BYTE %02x\n", v);
	if(bb->revpos < bb->pos) errx(1, "Byte collides with bit stream");
	bb->blockbuf[bb->revpos--] = v;
	bb->bitsleft -= 8;
}

static void putbits(struct blockbuilder *bb, int v, int width) {
	int i;

	//fprintf(stderr, "%4d %02x\n", width, v);
	if(v >= 1 << width) errx(1, "Trying to fit %d into %d bits", v, width);
	for(i = 0; i < width; i++) {
		bb->shifter <<= 1;
		if(v & (1 << (width - 1 - i))) bb->shifter |= 1;
		if(++bb->bits_in_shifter == 8) {
			if(bb->revpos < bb->pos) {
				errx(1, "Bit stream collides with byte");
			}
			bb->blockbuf[bb->pos++] = bb->shifter;
			bb->bits_in_shifter = 0;
		}
	}
	bb->bitsleft -= width;
}

static int bits_litlength(int value) {
	if(value == 0) {
		return 1;
	} else if(value <= 2) {
		return 4;
	} else if(value <= 6) {
		return 5;
	} else if(value <= 22) {
		return 7;
	} else {
		return 9;
	}
}

static int bits_match(int length, int offset) {
	if(length < 3 && offset < 64) {
		return 8;
	} else {
		return 16;
	}
}

static int piece_bits(struct chain *ch) {
	if(ch->is_literal) {
		/* Really long runs will be broken up, but we ignore that here.
		 */
		return bits_litlength(ch->length - 1) + ch->length * 8 + (ch->length == MAXLLENGTH);
	} else {
		return bits_match(ch->length - 2, ch->offset - 1) + 1;
	}
}

static void putlitlength(struct blockbuilder *bb, int v) {
	if(v == 0) {
		putbits(bb, 0, 1);
	} else if(v <= 2) {
		putbits(bb, 1, 1);
		putbits(bb, 0, 2);
		putbits(bb, (v - 1) ^ 0, 1);
	} else if(v <= 6) {
		putbits(bb, 1, 1);
		putbits(bb, 1, 2);
		putbits(bb, (v - 3) ^ 0, 2);
	} else if(v <= 22) {
		putbits(bb, 1, 1);
		putbits(bb, 2, 2);
		putbits(bb, (v - 7) ^ 0, 4);
	} else {
		putbits(bb, 1, 1);
		putbits(bb, 3, 2);
		putbits(bb, (v - 23) ^ 0, 6);
	}
}

static void putend(struct blockbuilder *bb, int more) {
	putbyte(bb, (0x3e + !!more) << 2);
}

static struct blockbuilder *new_blockbuilder(struct blockfile *bf, int newgroup, int hint_new_bunch) {
	struct blockbuilder *bb;
	
	bb = calloc(1, sizeof(*bb));
	disk_allocblock(bf, newgroup, hint_new_bunch, &bb->blockbuf, &bb->pos);
	if(bb->pos) {
		bb->is_meta = 1;
	}
	bb->revpos = 255;
	bb->bitsleft = (bb->revpos - bb->pos + 1) * 8;

	return bb;
}

static int close_blockbuilder(struct blockbuilder *bb) {
	int bytesleft;

	while(bb->bits_in_shifter) putbits(bb, 0, 1);
	bytesleft = bb->revpos - bb->pos + 1;
	free(bb);

	return bytesleft;
}

struct chain *find_best_chain(struct chunk *ch, int pos, int end, int match_allowed) {
	struct chaincache *cc;
	struct chain *tail, best;
	unsigned int bestbits = ~0, tailbits;
	int i, j, h, mybits;

	if(!pos) return 0;

	if(end > pos + MAXOFFSET) end = pos + MAXOFFSET;

	// Look in cache.

	h = pos & 1023;
	for(cc = ch->cache[h]; cc; cc = cc->next) {
		if(cc->pos == pos && cc->end == end) {
			if(cc->chain.is_literal || match_allowed) {
				return &cc->chain;
			}
		}
	}

	if(match_allowed) {
		// See if we can put a match here.

		for(j = 1; j <= MAXOFFSET && pos + j <= end; j++) {
			for(i = 1; i <= MAXMLENGTH; i++) {
				if(pos - i < 0) break;
				if(ch->data[pos - i] != ch->data[pos - i + j]) break;
				if(i >= 2) {
					/* Yes, at offset j is a match
					 * of at least i bytes.
					 */
					mybits = bits_match(i - 2, j - 1) + 1;
					tail = find_best_chain(ch, pos - i, end, 1);
					tailbits = tail? tail->bits : 0;
					if(tailbits + mybits < bestbits) {
						best.next = tail;
						best.is_literal = 0;
						best.length = i;
						best.offset = j;
						best.bits = bestbits = tailbits + mybits;
					}
				}
			}
		}
	}

	// Or we could extend the literal piece or create a new one.

	tail = find_best_chain(ch, pos - 1, end, 1);
	if(tail && tail->is_literal) {
		tailbits = tail->next? tail->next->bits : 0;
		mybits = bits_litlength(tail->length + 1 - 1) + (tail->length + 1) * 8 + ((tail->length + 1) / MAXLLENGTH);
		if(tailbits + mybits <= bestbits) {	// Prefer literal over match.
			best.next = tail->next;
			best.is_literal = 1;
			best.length = tail->length + 1;
			best.offset = 0;
			best.bits = bestbits = tailbits + mybits;
		}
	} else {
		tailbits = tail? tail->bits : 0;
		mybits = bits_litlength(0) + 8;
		if(tailbits + mybits <= bestbits) {
			best.next = tail;
			best.is_literal = 1;
			best.length = 1;
			best.offset = 0;
			best.bits = bestbits = tailbits + mybits;
		}
	}

	cc = arena_alloc(&ch->arena, sizeof(struct chaincache));
	memcpy(&cc->chain, &best, sizeof(best));
	cc->pos = pos;
	cc->end = end;
	cc->next = ch->cache[h];
	ch->cache[h] = cc;
	return &cc->chain;
}

void arena_free(struct arena *arena) {
	struct arena *a, *anext;
	uint64_t total = 0;

	for(a = arena; a; a = anext) {
		anext = a->next;
		total += a->size;
		free(a->data);
		free(a);
	}

	if(verbose >= 3) {
		fprintf(stderr, "Reclaimed %ld kB of arena space.\n", (long int) (total / 1024));
	}
}

void compress_group(
	struct chunk *chlist,
	struct blockfile *bf,
	uint16_t jumpaddr)
{
	struct blockbuilder *block = 0;
	int i, npiece, pos, end, safeend, need_select = 1;
	uint16_t endaddr;
	struct chain *chain;
	int contbit_needed = 0;
	int newgroup = !jumpaddr;
	int length;
	struct chunk *ch, *ch2;
	int totalin = 0, totalblocks = 0;
	struct chunk jumpchunk;
	uint8_t jumpdata[2];
	int unit_overhead, oldbitsleft, shadow;
	int flag;

	if(jumpaddr) {
		ch = &jumpchunk;
		memset(ch, 0, sizeof(*ch));
		ch->loadaddr = 0xc52;
		ch->size = 2;
		ch->data = jumpdata;
		snprintf(ch->name, sizeof(ch->name), "(entrypoint operand)");
		jumpdata[0] = jumpaddr & 0xff;
		jumpdata[1] = jumpaddr >> 8;
		ch->next = chlist;
		chlist = ch;
	}

	if(!chlist) errx(1, "At least one chunk required");

	for(ch = chlist; ch; ch = ch->next) {
		ch->arena = 0;
		ch->end = ch->size;
		ch->synced = 1;
		ch->cache = arena_alloc(
			&ch->arena,
			sizeof(struct chaincache *) * 1024);
		memset(ch->cache, 0, sizeof(struct chaincache *) * 1024);
		totalin += ch->size;
	}

	ch = chlist;
	do {
		flag = 0;
		if(ch->end) {
			//fprintf(stderr, "Considering '%s' at $%04x (end is %d)\n", ch->name, ch->loadaddr, ch->end);
			end = ch->end;
			if(!block) {
				block = new_blockbuilder(bf, newgroup, 0);
				totalblocks++;
				newgroup = 0;
				if(block->is_meta) {
					//fprintf(stderr, "new sector chunk\n");
					for(ch2 = chlist; ch2; ch2 = ch2->next) {
						ch2->synced = 1;
					}
				} else {
					//fprintf(stderr, "new regular block\n");
					putbits(block, 0, 1);
				}
				contbit_needed = 0;
				need_select = 0;
			} else {
				contbit_needed = 1;
			}
			safeend = ch->synced? ch->size : end;
			ch->synced = 0;
			chain = find_best_chain(ch, end, safeend, 0);
			//fprintf(stderr, "bits: %d\n", chain->bits);
			if(!chain) errx(1, "No chain?");
			// Can we fit at least one piece in the current block?
			endaddr = ch->loadaddr + ch->end;
			shadow = ch->loadaddr < 0xe000 && ch->loadaddr + safeend >= 0xd000 && ch->under_io;
			unit_overhead = need_select + (contbit_needed? (EOFBITS + 1) : 0) + 2 * 8;
			if(shadow) unit_overhead += 8;
			if(chain->is_literal) {
				unit_overhead += bits_litlength(0) + 8;
			} else {
				unit_overhead += piece_bits(chain);
			}
			unit_overhead += EOFBITS;
			if(unit_overhead > block->bitsleft) {
				// Close the block
				if(!contbit_needed) {
					errx(1, "Internal error: No units in block!");
				}
				if(need_select) putbits(block, 0, 1);
				putend(block, 0);
				(void) close_blockbuilder(block);
				block = 0;
			} else {
				if(contbit_needed) {
					if(need_select) putbits(block, 0, 1);
					putend(block, 1);
					need_select = 0;
				}
				putbyte(block, endaddr & 0xff);
				if(shadow) {
					//fprintf(stderr, "Emitting Shadow-RAM marker.\n");
					putbyte(block, 0);
				}
				putbyte(block, endaddr >> 8);
				npiece = 0;
				pos = ch->end;
				oldbitsleft = block->bitsleft;
				while(chain) {
					if(chain->is_literal) {
						if(block->bitsleft < need_select + bits_litlength(0) + 8 + EOFBITS) {
							break;
						}
						if(npiece && !need_select) {
							//fprintf(stderr, "no needselect, length is %d\n", chain->length);
							break;
						}
						npiece++;
						if(need_select) putbits(block, 1, 1);
						length = chain->length;
						if(length > MAXLLENGTH) length = MAXLLENGTH;
						if(length > block->bitsleft / 8) length = block->bitsleft / 8;
						while(block->bitsleft < bits_litlength(length - 1) + 8 * length + (length == MAXLLENGTH) + EOFBITS) length--;
						if(length < 1) errx(1, "Internal error: Bad length");
						putlitlength(block, length - 1);
						histogram_lit[length - 1]++;
						for(i = 0; i < length; i++) {
							putbyte(block, ch->data[--pos]);
						}
						//fprintf(stderr, "*L %04x %d\n", ch->loadaddr + pos, length);
						need_select = (length == MAXLLENGTH);
						if(length == chain->length) {
							chain = chain->next;
						} else {
							chain = find_best_chain(ch, pos, safeend, 1);
						}
					} else {
						if(block->bitsleft < need_select + piece_bits(chain) + EOFBITS) {
							// Try to squeeze in a few literal bytes.
							chain = find_best_chain(ch, pos, safeend, 0);
						} else {
							npiece++;
							if(need_select) {
								putbits(block, 0, 1);
							}
							if(chain->length <= 4 && chain->offset <= 64) {
								putbyte(block, ((chain->offset - 1) << 2) | (chain->length - 1));
							} else {
								putbyte(block, (chain->length - 1) << 2);
								putbyte(block, chain->offset - 1);
							}
							histogram_match[chain->length - 2][chain->offset - 1]++;
							pos -= chain->length;
							//fprintf(stderr, "*M %04x %d %d\n", ch->loadaddr + pos, chain->length, chain->offset);
							need_select = 1;
							chain = chain->next;
						}
					}
				}
				if(end == pos) errx(1, "Internal error! No pieces in unit.");
				if(verbose >= 3) {
					fprintf(
						stderr,
						"Crunched %d bits ($%04x-$%04x) "
						"into %d bits (%d%%) using %d "
						"pieces, from \"%s\"\n",
						(end - pos) * 8,
						ch->loadaddr + pos,
						ch->loadaddr + ch->end - 1,
						(oldbitsleft - block->bitsleft),
						(oldbitsleft - block->bitsleft) * 100 / ((ch->end - pos) * 8),
						npiece,
						ch->name);
				}
				ch->end = pos;
				contbit_needed = 1;
			}
			flag = 1;
		}
		ch = ch->next;
		if(!ch) ch = chlist;
		for(ch2 = chlist; ch2 && !flag; ch2 = ch2->next) {
			if(ch2->end) flag = 1;
		}
	} while(flag);

	if(!block) errx(1, "Empty group not allowed.");
	if(!contbit_needed) errx(1, "Empty block not allowed.");
	if(need_select) putbits(block, 0, 1);
	putend(block, 0);
	i = close_blockbuilder(block);
	if(verbose >= 3) {
		fprintf(
			stderr,
			"%d unused bytes in tail block.\n",
			i);
	}
	if(verbose >= 2) {
		fprintf(
			stderr,
			"%d bytes stored in %d blocks, "
			"effective compression ratio %d%%.\n",
			totalin,
			totalblocks,
			totalblocks * 100 / ((totalin + 253) / 254));
	}

	for(ch = chlist; ch; ch = ch->next) {
		arena_free(ch->arena);
	}
}

void report_histogram() {
	int i, j;

	if(verbose >= 3) {
		fprintf(stderr, "LITERAL:\n");
		for(i = 0; i < MAXLLENGTH; i++) {
			if(histogram_lit[i]) fprintf(stderr, "%5d: %5d\n", i + 1, histogram_lit[i]);
		}
		fprintf(stderr, "\n");
		fprintf(stderr, "MATCH:\n     ");
		for(i = 0; i < 28; i++) {
			fprintf(stderr, "%4d ", i + 2);
		}
		fprintf(stderr, "\n");
		for(j = 0; j < MAXOFFSET; j++) {
			fprintf(stderr, "%4d:", j + 1);
			for(i = 0; i < 28; i++) {
				fprintf(stderr, "%4d ", histogram_match[i][j]);
			}
			fprintf(stderr, "\n");
		}
	}
}
