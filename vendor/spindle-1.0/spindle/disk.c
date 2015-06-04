// Spindle by lft, http://www.linusakesson.net/software/spindle/

#include <err.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "pefchain.h"
#include "datatables.h"

static int tracksize[NTRACK + 1] = {
	0,
	21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21,
	19, 19, 19, 19, 19, 19, 19,
	18, 18, 18, 18, 18, 18,
	17, 17, 17, 17, 17
};

static int trackstart[NTRACK + 1];

static uint8_t available[NTRACK + 1][21];
static uint8_t image[NSECTOR * 256];

#define SECTOR(tr, se) (&image[(trackstart[tr] + (se)) * 256])

void init_disk(char *name, char *id) {
	int i, pos = 0;
	uint8_t *bam;

	for(i = 1; i <= NTRACK; i++) {
		trackstart[i] = pos;
		pos += tracksize[i];
	}
	if(pos != NSECTOR) errx(1, "Internal error: NSECTOR should be %d", pos);

	bam = SECTOR(18, 0);
	bam[0] = 18;	// First dir block
	bam[1] = 1;
	bam[2] = 0x41;	// 1541

	memset(bam + 144, 0xa0, 27);
	for(i = 0; name[i]; i++) bam[144 + i] = name[i];
	bam[162] = id[0];
	bam[163] = id[1];
	bam[165] = 0x32;
	bam[166] = 0x41;

	for(i = 1; i <= NTRACK; i++) {
		if(i != 18) memset(available[i], 1, tracksize[i]);
	}
}

void seek_to_end(struct blockmap *bm) {
	bm->currtr = NTRACK;
	bm->currse = 0;
}

void seek_to_middle(struct blockmap *bm, int first_sector_available) {
	bm->currtr = 17;
	bm->currse = 0;
	available[17][0] = first_sector_available;
}

static void take_next_free(int *track, int *sector) {
	int tr = *track, se = *sector, count;

	count = tracksize[tr];
	while(!available[tr][se]) {
		se = (se + 1) % tracksize[tr];
		if(!--count) {
			if(!--tr) errx(1, "Disk full");
			// Compensate for time lost by stepping and
			// adapt to new track size.
			se = (se + 3) % tracksize[tr];
			count = tracksize[tr];
		}
	}
	available[tr][se] = 0;
	*track = tr;
	*sector = se;
}

static void running_xor(uint8_t *dest, uint8_t *src) {
	int i, last = 0;

	for(i = 0; i < 256; i++) {
		dest[i] = last ^ src[(i + 1) & 255];
		last ^= dest[i];
	}
}

void store_block(struct blockmap *bm, uint8_t *data) {
	take_next_free(&bm->currtr, &bm->currse);
	bm->nblock++;
	bm->map[bm->currtr - 1][bm->currse] = 1;
	running_xor(SECTOR(bm->currtr, bm->currse), data);
	bm->currse = (bm->currse + INTERLEAVE) % tracksize[bm->currtr];
}

/*
Track 18 layout:

	 0	bam
	 1	directory (block 1)
	 2	drivecode (block 2, init 2, loaded by DOS)
	 3	decruncher & filespec (prefetched by drivecode, executes on c64)
	 4	directory (block 2, optional)
	 5
	 6
	 7	directory (block 3, optional)
	 8	stage 1 (block 1)
	 9
	 10	directory (block 4, optional)
	 11	drivecode (block 3, fetch, loaded by DOS)
	 12	drivecode (block 1, init 1, loaded by DOS via M-E)
	 13	directory (block 5, optional)
	 14
	 15
	 16	directory (block 6, optional)
	 17	drivecode (block 4, communicate, loaded by drivecode)
	 18	stage 1 (block 2)
*/

void store_loader(struct filespec *fs, uint16_t jumpaddr, uint8_t *dirart, int active_dentry) {
	uint8_t *dir = SECTOR(18, 1), *dentry;
	uint8_t buffer[256];
	int i, j, e, last = 0;

	memset(available[18], 1, tracksize[18]);
	available[18][0] = 0;
	available[18][2] = 0;
	available[18][3] = 0;
	available[18][8] = 0;
	available[18][11] = 0;
	available[18][12] = 0;
	available[18][17] = 0;
	available[18][18] = 0;

	for(i = 0; i < DIRARTBLOCKS * 8; i++) {
		if(dirart[i * 16] != 0xa0) last = i;
	}
	if(active_dentry > last) active_dentry = last;

	for(i = 0; i < DIRARTBLOCKS; i++) {
		available[18][1 + 3 * i] = 0;
		dir = SECTOR(18, 1 + 3 * i);
		memset(dir, 0, 256);
		for(j = 0; j < 8; j++) {
			dentry = dir + j * 32 + 2;
			e = i * 8 + j;
			if(e <= last) {
				if(e == active_dentry) {
					dentry[0] = 0x82;
					dentry[1] = 18;
					dentry[2] = 8;
					dentry[28] = 2;
				} else {
					dentry[0] = 0x80;
				}
				memcpy(dentry + 3, dirart + e * 16, 16);
			}
		}
		if(last >= (i + 1) * 8) {
			dir[0] = 18;
			dir[1] = 1 + 3 * (i + 1);
		} else {
			dir[0] = 0;
			dir[1] = 0xff;
			break;
		}
	}

	SECTOR(18, 8)[0] = 18;
	SECTOR(18, 8)[1] = 18;
	memcpy(SECTOR(18, 8) + 2, data_stage1, 254);
	SECTOR(18, 18)[0] = 0;
	SECTOR(18, 18)[1] = sizeof(data_stage1) - 254 + 1;
	memcpy(SECTOR(18, 18) + 2, data_stage1 + 254, sizeof(data_stage1) - 254);

	memcpy(SECTOR(18, 12), data_drivecode + 0x000, 256);
	memcpy(SECTOR(18, 2), data_drivecode + 0x100, 256);
	memcpy(SECTOR(18, 11), data_drivecode + 0x200, 256);
	memcpy(SECTOR(18, 17), data_drivecode + 0x300, 256);

	if(fs->ntrack * 4 > 256 - sizeof(data_decruncher) - 3) {
		errx(1, "The first effect must fit on %d tracks!",
			(int) (256 - sizeof(data_decruncher) - 3) / 4);
	}

	memset(buffer, 0, sizeof(buffer));
	memcpy(buffer, data_decruncher, sizeof(data_decruncher));
	buffer[sizeof(data_decruncher) + 0] = jumpaddr & 0xff;
	buffer[sizeof(data_decruncher) + 1] = jumpaddr >> 8;
	buffer[sizeof(data_decruncher) + 2] = (fs->ntrack << 1) | fs->below_io;
	memcpy(buffer + sizeof(data_decruncher) + 3, fs->spec, 4 * fs->ntrack);
	running_xor(SECTOR(18, 3), buffer);
}

void write_disk(char *fname) {
	FILE *f;
	int t, s, i, nfree = 0;
	uint8_t bits[4];

	for(t = 1; t <= NTRACK; t++) {
		memset(bits, 0, sizeof(bits));
		for(s = 0; s < tracksize[t]; s++) {
			if(available[t][s]) {
				bits[0]++;
				bits[1 + s / 8] |= 1 << (s & 7);
				if(t != 18) nfree++;
			}
		}
		for(i = 0; i < 4; i++) {
			SECTOR(18, 0)[4 * t + i] = bits[i];
		}
	}

	f = fopen(fname, "wb");
	if(!f) err(1, "%s", fname);
	fwrite(image, 1, sizeof(image), f);
	fclose(f);

	fprintf(stderr, "%s: %d blocks free.", fname, nfree);
}
