/* Spindle by lft, http://www.linusakesson.net/software/spindle/
 */

#include <err.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "disk.h"

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

void disk_init(char *name, char *id) {
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

static void take_next_free(int *track, int *sector) {
	int tr = *track, se = *sector, count;

	count = tracksize[tr];
	while(!available[tr][se]) {
		se = (se + 1) % tracksize[tr];
		if(!--count) {
			if(++tr > NTRACK) errx(1, "Disk full");
			// The loader skips track 18, so we do that too.
			if(tr == 18) tr++;
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

static int available_on_track(int tr) {
	int se;
	int n = 0;

	for(se = 0; se < tracksize[tr]; se++) {
		n += available[tr][se];
	}

	return n;
}

void disk_allocblock(
	struct blockfile *bf,
	int newgroup,
	int hint_new_bunch,
	uint8_t **dataptr,
	int *blockpos)
{
	int tr = bf->currtr;
	take_next_free(&bf->currtr, &bf->currse);
	*dataptr = SECTOR(bf->currtr, bf->currse);
	if(bf->currtr != tr || newgroup || (hint_new_bunch && bf->nextptr && available_on_track(tr) > 4)) {
		if(!bf->nextptr) errx(1, "Blank block group not allowed!");
		bf->chainptr = bf->nextptr;
		bf->nextptr = 0;
	}
	if(bf->currtr != tr) {
		bf->chainptr[0] |= 0x20;
	}
	if(newgroup) {
		bf->chainptr[0] |= 0x40;
	}
	if(bf->nextptr) {
		*blockpos = 0;
	} else {
		bf->nextptr = SECTOR(bf->currtr, bf->currse);
		bf->nextptr[0] = 0x80;
		bf->nextptr[1] = 0x00;
		bf->nextptr[2] = 0x00;
		*blockpos = 3;
	}
	if(bf->currse < 5) {
		bf->chainptr[0] |= 0x10 >> bf->currse;
	} else if(bf->currse < 13) {
		bf->chainptr[1] |= 0x80 >> (bf->currse - 5);
	} else {
		bf->chainptr[2] |= 0x80 >> (bf->currse - 13);
	}
	bf->currse = (bf->currse + INTERLEAVE) % tracksize[bf->currtr];
}

void disk_closeside(struct blockfile *bf, int last) {
	if(!bf->nextptr) errx(1, "Blank block group not allowed!");
	bf->nextptr[0] = last? 0xa0 : 0x80;
	bf->nextptr[1] = 0x00;
	bf->nextptr[2] = 0x00;
}

static void running_xor(uint8_t *dest, uint8_t *src) {
	int i, last = 0;

	for(i = 0; i < 256; i++) {
		dest[i] = last ^ src[(i + 1) & 255];
		last ^= dest[i];
	}
}

/*
Track 18 layout:

	 0	bam
	 1	directory (block 1)
	 2	drivecode (block 2, init 2, loaded by DOS)
	 3	(stage 1 block 4, used during development)
	 4	directory (block 2, optional)
	 5
	 6
	 7	directory (block 3, optional)
	 8	stage 1 (block 1)
	 9	stage 1 (block 3)
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

void disk_storeloader(
	struct blockfile *bf,
	uint8_t *dirart,
	int active_dentry,
	uint32_t my_magic,
	uint32_t next_magic)
{
	uint8_t *dir = SECTOR(18, 1), *dentry;
	int i, j, e, last = 0;

	memset(available[18], 1, tracksize[18]);
	available[18][0] = 0;
	available[18][2] = 0;
#ifdef BIG_STAGE1
	available[18][3] = 0;
#endif
	available[18][8] = 0;
	available[18][9] = 0;
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
					dentry[28] = 3;
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

#ifdef BIG_STAGE1
	SECTOR(18, 8)[0] = 18;
	SECTOR(18, 8)[1] = 18;
	memcpy(SECTOR(18, 8) + 2, data_stage1, 254);
	SECTOR(18, 18)[0] = 18;
	SECTOR(18, 18)[1] = 9;
	memcpy(SECTOR(18, 18) + 2, data_stage1 + 254, 254);
	SECTOR(18, 9)[0] = 18;
	SECTOR(18, 9)[1] = 3;
	memcpy(SECTOR(18, 9) + 2, data_stage1 + 2 * 254, 254);
	SECTOR(18, 3)[0] = 0;
	SECTOR(18, 3)[1] = sizeof(data_stage1) - 3 * 254 + 1;
	memcpy(
		SECTOR(18, 3) + 2,
		data_stage1 + 3 * 254,
		sizeof(data_stage1) - 3 * 254);
#else
	SECTOR(18, 8)[0] = 18;
	SECTOR(18, 8)[1] = 18;
	memcpy(SECTOR(18, 8) + 2, data_stage1, 254);
	SECTOR(18, 18)[0] = 18;
	SECTOR(18, 18)[1] = 9;
	memcpy(SECTOR(18, 18) + 2, data_stage1 + 254, 254);
	SECTOR(18, 9)[0] = 0;
	SECTOR(18, 9)[1] = sizeof(data_stage1) - 2 * 254 + 1;
	memcpy(
		SECTOR(18, 9) + 2,
		data_stage1 + 2 * 254,
		sizeof(data_stage1) - 2 * 254);
#endif

	memcpy(SECTOR(18, 12), data_drivecode + 0x000, 256);
	memcpy(SECTOR(18, 2), data_drivecode + 0x100, 256);
	memcpy(SECTOR(18, 11), data_drivecode + 0x200, 256);
	memcpy(SECTOR(18, 17), data_drivecode + 0x300, 256);

	SECTOR(18, 17)[0xf7] = (my_magic >> 16) & 0xff;
	SECTOR(18, 17)[0xf8] = (my_magic >> 8) & 0xff;
	SECTOR(18, 17)[0xf9] = (my_magic >> 0) & 0xff;
	SECTOR(18, 17)[0xfa] = (next_magic >> 16) & 0xff;
	SECTOR(18, 17)[0xfb] = (next_magic >> 8) & 0xff;
	SECTOR(18, 17)[0xfc] = (next_magic >> 0) & 0xff;

	memset(bf, 0, sizeof(*bf));
	bf->currtr = 1;
	bf->currse = 0;
	bf->chainptr = &SECTOR(18, 17)[0xfd];
	bf->nextptr = 0;
}

void disk_write(char *fname) {
	FILE *f;
	int t, s, i, nfree = 0;
	uint8_t bits[4];
	uint8_t buf[256];

	for(t = 1; t <= NTRACK; t++) {
		memset(bits, 0, sizeof(bits));
		for(s = 0; s < tracksize[t]; s++) {
			if(available[t][s]) {
				bits[0]++;
				bits[1 + s / 8] |= 1 << (s & 7);
				if(t != 18) nfree++;
			}
			if(t != 18) {
				memcpy(buf, SECTOR(t, s), 256);
				running_xor(SECTOR(t, s), buf);
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

	fprintf(stderr, "%s: %d blocks free.\n", fname, nfree);
}
