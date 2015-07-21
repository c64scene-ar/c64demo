/* Spindle by lft, http://www.linusakesson.net/software/spindle/
 */

#include <err.h>
#include <getopt.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "common.h"
#include "pef.h"
#include "commonsetup.h"
#include "disk.h"
#include "pack.h"

#define FIRST_RESERVED_PAGE	0x0c
#define LAST_RESERVED_PAGE	0x0e
#define FIRST_RESERVED_ZP	0xf4
#define LAST_RESERVED_ZP	0xf7
#define ADDR_LOAD		0x0c90
#define ADDR_IRQ		0x0c10
#define ADDR_RTS		(ADDR_IRQ + 18)
#define ADDR_NEXTSIDE		0x0c50

#define MAXEFFECTS 64

#define MAXACTIONS (MAXEFFECTS * 12)

int verbose;

struct load {
	struct load	*next;
	struct chunk	*chunk;
	uint8_t		pages[256];
};

enum {
	COND_DROP,
	COND_SPACE,
};

struct effect {
	struct header	header;
	struct chunk	chunk[MAXCHUNKS + 1];
	uint16_t	condaddr;
	uint8_t		condval;
	char		filename[32];
	uint16_t	play_address;
	uint8_t		needs_loading[256];
	int		blocks_loaded;
	struct load	*loads;
	int		loadingPreferable;
	uint8_t		*driver_code;
	uint16_t	driver_org;
	int		driver_size;
	int		driver_loadcall;
	int		driver_nextlsb;
	int		driver_nextmsb;
	int		driver_nextm1;
} effect[MAXEFFECTS];
int neffect;

static void load_pef(struct effect *e, char *filename) {
	FILE *f;
	int i;
	char buf[32];
	struct chunk *c;

	f = fopen(filename, "rb");
	if(!f) err(1, "fopen: %s", filename);
	
	fread(&e->header, sizeof(e->header), 1, f);
	if(strncmp((char *) e->header.magic, "PEF3", 4)) {
		errx(1, "Invalid pef header: %s", filename);
	}

	if(rindex(filename, '/')) filename = rindex(filename, '/') + 1;
	snprintf(e->filename, sizeof(e->filename), "%s", filename);
	e->filename[sizeof(e->filename) - 1] = 0;

	for(i = 0; i < e->header.nchunk; i++) {
		c = &e->chunk[i];
		c->size = fgetc(f);
		c->size |= fgetc(f) << 8;
		c->data = malloc(c->size);
		c->loadaddr = fgetc(f);
		c->loadaddr |= fgetc(f) << 8;
		fread(buf, 32, 1, f);
		snprintf(c->name, sizeof(c->name), "%s:%s", filename, buf);
		c->name[sizeof(c->name) - 1] = 0;
		fread(c->data, c->size, 1, f);
		c->under_io =
			c->loadaddr <= 0xdfff &&
			(c->loadaddr + c->size) > 0xd000;
	}

	fclose(f);
}

static void create_init_effect(struct effect *e) {
	int i;

	e->header.flags = EF_SAFE_IO;
	for(i = 0x04; i <= 0x07; i++) {
		e->header.pageflags[i] = PF_INHERIT;
	}
	snprintf(e->filename, sizeof(e->filename), "(loader stage 2)");
}

static void create_blank_effect(struct effect *e) {
	e->header.flags = EF_SAFE_IO | EF_DONT_LOAD | EF_BLANK;
	snprintf(e->filename, sizeof(e->filename), "(blank)");
}

static void load_script(char *filename) {
	FILE *f;
	char buf[256], *cond;
	int i, p1, p2, page;
	uint16_t play_address = 0;
	struct effect *e;

	create_init_effect(&effect[neffect]);
	neffect++;

	f = fopen(filename, "r");
	if(!f) err(1, "fopen: %s", filename);

	while(fgets(buf, sizeof(buf), f)) {
		if(strlen(buf) && buf[strlen(buf) - 1] == '\n') {
			buf[strlen(buf) - 1] = 0;
		}
		if(*buf && *buf != '#') {
			for(i = 0; buf[i] && !strchr("\n\r\t ", buf[i]); i++);
			if(!i) errx(1,
				"Unexpected whitespace at beginning of "
				"script line '%s'.",
				buf);
			if(buf[i]) buf[i++] = 0;
			while(buf[i] && strchr("\n\r\t ", buf[i])) i++;
			cond = buf + i;
			if(!*cond) errx(1,
				"Expected a condition on script line '%s'.",
				buf);

			if(neffect == MAXEFFECTS) {
				errx(1, "Increase MAXEFFECTS!");
			}
			e = &effect[neffect++];
			e->play_address = play_address;
			if(!strcmp(buf, "-")) {
				create_blank_effect(e);
				e->header.flags &= ~(EF_BLANK | EF_DONT_LOAD);
				e->header.flags |= EF_SCRIPTBLANK;
			} else {
				load_pef(e, buf);
				if(e->header.installs_music[0]
				|| e->header.installs_music[1]) {
					play_address =
						e->header.installs_music[0] |
						(e->header.installs_music[1] << 8);
				}
				for(i = 0; i < 256; i++) {
					if(e->header.pageflags[i] & (PF_LOADED | PF_USED)
					&& i >= FIRST_RESERVED_PAGE
					&& i < LAST_RESERVED_PAGE) {
						errx(1,
							"Effect %s uses page "
							"$%02x which is reserved "
							"for the spindle system.",
							e->filename,
							i);
					} else if(i == LAST_RESERVED_PAGE) {
						if(e->header.pageflags[i] & PF_LOADED) {
							errx(1,
								"Effect %s wants to "
								"load to page $%02x, "
								"but this page is "
								"reserved during loading.",
								e->filename,
								i);
						}
						if(e->header.pageflags[i] & PF_USED) {
							if(!(e->header.flags & EF_DONT_LOAD)) {
								warnx(
									"Loading is disabled "
									"during effect %s, "
									"because it uses page "
									"$%02x. Use X tag to "
									"hide this warning.",
									e->filename,
									i);
								e->header.flags |= EF_DONT_LOAD;
							}
						}
					}
					if((e->header.pageflags[i] & PF_ZPUSED)
					&& i >= FIRST_RESERVED_ZP
					&& i <= LAST_RESERVED_ZP) {
						if(!(e->header.flags & EF_DONT_LOAD)) {
							warnx(
								"Loading is disabled "
								"during effect %s, "
								"because it uses "
								"zero-page address $%02x. "
								"Use X tag to hide "
								"this warning.",
								e->filename,
								i);
							e->header.flags |= EF_DONT_LOAD;
						}
					}
					e->needs_loading[i] = !!(e->header.pageflags[i] & PF_LOADED);
				}
			}

			if(!strcmp(cond, "space")) {
				e->condaddr = 0;
				e->condval = COND_SPACE;
			} else if(!strcmp(cond, "-")) {
				e->condaddr = 0;
				e->condval = COND_DROP;
			} else if(2 == sscanf(cond, "%x = %x", &p1, &p2)) {
				e->condaddr = p1;
				e->condval = p2;
			} else errx(1, "Invalid condition: '%s'", cond);
		}
	}

	if(neffect < 2) errx(1, "No effects in script!");

	fclose(f);

	for(i = 1; i < neffect; i++) {
		if(!effect[i].header.nchunk) {
			// Scripted blank effect needs a page for the driver.
			page = LAST_RESERVED_PAGE + 1;
			while(
				page < 2
				|| (page >= 0xd0 && page <= 0xdf)
				|| page == 0xff
				|| (effect[i - 1].header.pageflags[page] & (PF_LOADED | PF_USED | PF_INHERIT))
				|| (effect[i].header.pageflags[page] & (PF_LOADED | PF_USED | PF_INHERIT))
				|| (i < neffect - 1 && effect[i + 1].header.pageflags[page] & (PF_LOADED | PF_USED | PF_INHERIT)))
			{
				page = (page + 1) & 0xff;
				if(page == FIRST_RESERVED_PAGE) {
					errx(
						1,
						"Couldn't find a free page for the "
						"driver of the blank effect (\"-\")");
				}
			}
			effect[i].header.nchunk = 1;
			effect[i].chunk[0].size = 0;
			effect[i].chunk[0].loadaddr = page << 8;
			effect[i].chunk[0].data = 0;
			snprintf(
				effect[i].chunk[0].name,
				sizeof(effect[i].chunk[0].name),
				"(blank):(driver)");
		}
	}
}

static void patch_effects() {
	int i, offs, p;
	uint16_t jsr;
	uint8_t resident[256];
	struct effect *e;

	memset(resident, 0, sizeof(resident));

	for(i = 0; i < neffect; i++) {
		e = &effect[i];
		for(p = 0; p < 256; p++) {
			if(resident[p]) {
				if(e->header.pageflags[p] & (PF_LOADED | PF_USED)) {
					errx(
						1,
						"Effect %s is using page $%02x "
						"which is already occupied by "
						"the music player.",
						e->filename,
						p);
				}
				e->header.pageflags[p] |= PF_INHERIT;
			}
			if(e->header.installs_music[0]
			|| e->header.installs_music[1]) {
				resident[p] = !!(e->header.pageflags[p] & PF_MUSIC);
			}
		}

		jsr = e->header.efo.v_jsr[0] | (e->header.efo.v_jsr[1] << 8);
		if(jsr
		&& jsr >= e->chunk[0].loadaddr
		&& jsr < e->chunk[0].loadaddr + e->chunk[0].size) {
			offs = jsr - e->chunk[0].loadaddr;
			if(e->play_address) {
				e->chunk[0].data[offs + 0] = 0x20;	// jsr
				e->chunk[0].data[offs + 1] = e->play_address & 255;
				e->chunk[0].data[offs + 2] = e->play_address >> 8;
				e->header.efo.v_jsr[0] = 0;
				e->header.efo.v_jsr[1] = 0;
			} else {
				e->chunk[0].data[offs + 0] = 0x2c;	// bit abs
			}
		}
	}
}

static void dump_range(uint8_t a, uint8_t b, int *first) {
	if(*first) {
		*first = 0;
	} else {
		fprintf(stderr, ",");
	}
	if(a == b) {
		fprintf(stderr, "%02x", a);
	} else {
		fprintf(stderr, "%02x-%02x", a, b);
	}
}

static void dump_ranges(uint8_t *table) {
	int i, start = -1, first = 1;

	for(i = 0; i < 256; i++) {
		if(table[i]) {
			if(start < 0) start = i;
		} else {
			if(start >= 0) {
				dump_range(start, i - 1, &first);
				start = -1;
			}
		}
	}
	if(start >= 0) dump_range(start, 255, &first);
}

static void add_filler_before(int i) {
	if(neffect == MAXEFFECTS) errx(1, "Increase MAXEFFECTS!");
	memmove(&effect[i + 1], &effect[i], sizeof(struct effect) * (neffect - i));
	neffect++;
	memset(&effect[i], 0, sizeof(struct effect));
	create_blank_effect(&effect[i]);
	effect[i].play_address = effect[i + 1].play_address;
}

static void suggest_filler(struct effect *e1, struct effect *e2) {
	uint8_t page[256], zp[256];
	int p;

	for(p = 0; p < 256; p++) {
		page[p] = !((e1->header.pageflags[p] | e2->header.pageflags[p]) & PF_USED);
		zp[p] = !((e1->header.pageflags[p] | e2->header.pageflags[p]) & PF_ZPUSED);
	}

	page[0] = page[1] = 0;
	for(p = FIRST_RESERVED_PAGE; p <= LAST_RESERVED_PAGE; p++) page[p] = 0;
	zp[0] = zp[1] = 0;
	for(p = FIRST_RESERVED_ZP; p < LAST_RESERVED_ZP; p++) zp[p] = 0;

	fprintf(
		stderr,
		"Suggestion: Move things around or "
		"insert a part that only touches pages ");
	dump_ranges(page);
	fprintf(stderr, " and zero-page locations ");
	dump_ranges(zp);
	fprintf(stderr, ".\n");
}

static void insert_fillers() {
	int i, p = 0, need_filler, pagecoll, zpcoll;
	uint8_t pages[256], zp[256], iopage[16];

	memset(iopage, 0, sizeof(iopage));
	for(i = 0; i < neffect; i++) {
		need_filler = 0;
		for(p = 0; p < 16; p++) {
			if(effect[i].header.pageflags[0xd0 + p] & PF_LOADED) {
				if(!iopage[p]) need_filler = 1;
			}
			if(effect[i].header.pageflags[0xd0 + p] & PF_USED) {
				iopage[p] = 0;
			} else if(effect[i].header.flags & EF_SAFE_IO) {
				iopage[p] = 1;
			}
		}
		if(need_filler) {
			fprintf(stderr,
				"Warning: Inserting blank filler before '%s' "
				"to be able to load underneath the I/O area.\n",
				effect[i].filename);
			add_filler_before(i);
			i++;
			for(p = 0; p < 16; p++) {
				iopage[p] = !(effect[i].header.pageflags[0xd0 + p] & PF_USED);
			}
		}
		if(i < neffect - 1) {
			if((effect[i + 1].header.flags & EF_UNSAFE)
			&& !(effect[i].header.flags & EF_SAFE_IO)) {
				fprintf(stderr,
					"Warning: Inserting blank filler "
					"because '%s' is declared unsafe and "
					"'%s' is not declared safe.\n",
					effect[i + 1].filename,
					effect[i].filename);
				add_filler_before(i + 1);
				for(p = 0; p < 16; p++) {
					iopage[p] = !(effect[i].header.pageflags[0xd0 + p] & PF_USED);
				}
			} else {
				pagecoll = zpcoll = 0;
				for(p = 0; p < 256; p++) {
					zp[p] =
						effect[i].header.pageflags[p] &
						effect[i + 1].header.pageflags[p] &
						PF_ZPUSED;
					pages[p] =
						(effect[i].header.pageflags[p] & (PF_USED | PF_INHERIT)) &&
						(effect[i + 1].header.pageflags[p] & PF_USED);
					if(zp[p]) zpcoll = 1;
					if(pages[p]) pagecoll = 1;
				}
				if(pagecoll || zpcoll) {
					fprintf(stderr,
						"Warning: Inserting blank filler "
						"because '%s' and '%s' share ",
						effect[i].filename,
						effect[i + 1].filename);
					if(pagecoll) {
						fprintf(stderr, "pages ");
						dump_ranges(pages);
						if(zpcoll) fprintf(stderr, " and ");
					}
					if(zpcoll) {
						fprintf(stderr, "zero-page locations ");
						dump_ranges(zp);
					}
					fprintf(stderr, ".\n");
					suggest_filler(&effect[i], &effect[i + 1]);
					add_filler_before(i + 1);
					for(p = 0; p < 16; p++) {
						iopage[p] = !(effect[i].header.pageflags[0xd0 + p] & PF_USED);
					}
				}
			}
		}
	}
}

static void add_load(int eid, struct chunk *c, uint8_t page) {
	struct load *l;
	struct effect *e;

	if(eid < 0) errx(1, "Internal error! Trying to add load to null effect.");

	e = &effect[eid];

	if(!(e->header.flags & EF_SAFE_IO) && page >= 0xd0 && page <= 0xdf) {
		errx(
			1,
			"Internal error! Trying to add load "
			"under i/o area during unsafe effect.");
	}

	for(l = e->loads; l; l = l->next) {
		if(l->chunk == c) break;
	}
	if(!l) {
		l = calloc(1, sizeof(struct load));
		l->chunk = c;
		l->next = e->loads;
		e->loads = l;
	}
	l->pages[page] = 1;
}

static int preferred_loading_slot(int later, int earlier) {
	if(later < 0) return earlier;
	if((effect[earlier].header.flags & EF_DONT_LOAD)
	&& !(effect[later].header.flags & EF_DONT_LOAD)) return later;
	return earlier;
}

static void schedule_loads_for(int fallback, struct effect *target) {
	int i, p, iosafe;
	struct effect *candidate;
	struct chunk *c;

	candidate = &effect[fallback];
	iosafe = (candidate->header.flags & EF_SAFE_IO)? fallback : -1;

	for(i = fallback - 1; i >= 0; i--) {
		candidate = &effect[i];
		for(p = 0; p < 256; p++) {
			if(target->needs_loading[p]
			&& (candidate->header.pageflags[p] & (PF_USED | PF_INHERIT))) {
				// Page can't be loaded during or before the candidate.
				c = &target->chunk[target->header.chunkmap[p]];
				if(p >= 0xd0 && p <= 0xdf) {
					add_load(iosafe, c, p);
				} else {
					add_load(fallback, c, p);
				}
				target->needs_loading[p] = 0;
			}
		}
		if(candidate->loadingPreferable) {
			fallback = preferred_loading_slot(fallback, i);
			if(candidate->header.flags & EF_SAFE_IO) {
				iosafe = preferred_loading_slot(iosafe, i);
			}
		} else {
			if(iosafe < 0
			&& (candidate->header.flags & EF_SAFE_IO)) {
				iosafe = preferred_loading_slot(iosafe, i);
			}
		}
	}

	for(p = 0; p < 256; p++) {
		if(target->needs_loading[p]) {
			c = &target->chunk[target->header.chunkmap[p]];
			if(p >= 0xd0 && p <= 0xdf) {
				add_load(iosafe, c, p);
			} else {
				add_load(fallback, c, p);
			}
		}
	}
}

static void schedule_loads() {
	int i;

	for(i = 1; i < neffect; i++) {
		effect[i].loadingPreferable =
			!(effect[i].header.efo.v_main[0] | effect[i].header.efo.v_main[1]);
	}

	for(i = neffect - 1; i > 0; i--) {
		if(!(effect[i].header.flags & EF_BLANK)) {
			schedule_loads_for(i - 1, &effect[i]);
		}
	}
}

static void generate_main_and_fadeout(
	uint8_t *driver,
	int *pos,
	struct effect *e)
{
	int mainpos, j;

	if(!e->condaddr && e->condval == COND_SPACE) {
		for(j = 0; j < 2; j++) {
			mainpos = *pos;
			if(e->header.efo.v_main[0]
			|| e->header.efo.v_main[1]) {
				driver[(*pos)++] = 0x20;
				driver[(*pos)++] = e->header.efo.v_main[0];
				driver[(*pos)++] = e->header.efo.v_main[1];
			}
			driver[(*pos)++] = 0xa9;		// lda imm
			driver[(*pos)++] = 0x7f;
			driver[(*pos)++] = 0x8d;		// sta abs
			driver[(*pos)++] = 0x00;
			driver[(*pos)++] = 0xdc;
			driver[(*pos)++] = 0xa9;		// lda imm
			driver[(*pos)++] = 0x10;
			driver[(*pos)++] = 0x2c;		// bit abs
			driver[(*pos)++] = 0x01;
			driver[(*pos)++] = 0xdc;
			driver[(*pos)++] = j? 0xd0 : 0xf0;	// bne / beq
			driver[*pos] = (mainpos - *pos - 1) & 0xff;
			(*pos)++;
		}
	} else {
		mainpos = *pos;
		if(e->header.efo.v_main[0]
		|| e->header.efo.v_main[1]) {
			driver[(*pos)++] = 0x20;
			driver[(*pos)++] = e->header.efo.v_main[0];
			driver[(*pos)++] = e->header.efo.v_main[1];
		}
		if(e->condaddr) {
			if(e->condaddr < 0x100) {
				driver[(*pos)++] = 0xa5;	// lda zp
				driver[(*pos)++] = e->condaddr;
			} else {
				driver[(*pos)++] = 0xad;	// lda abs
				driver[(*pos)++] = e->condaddr & 255;
				driver[(*pos)++] = e->condaddr >> 8;
			}
			driver[(*pos)++] = 0xc9;		// cmp imm
			driver[(*pos)++] = e->condval;
			driver[(*pos)++] = 0xd0;		// bne
			driver[*pos] = (mainpos - *pos - 1) & 0xff;
			(*pos)++;
		} else if(e->condval != COND_DROP) {
			errx(1, "Internal error: Bad condval");
		}
	}

	if(e->header.efo.v_fadeout[0]
	|| e->header.efo.v_fadeout[1]) {
		mainpos = *pos;
		if(e->header.efo.v_main[0]
		|| e->header.efo.v_main[1]) {
			driver[(*pos)++] = 0x20;
			driver[(*pos)++] = e->header.efo.v_main[0];
			driver[(*pos)++] = e->header.efo.v_main[1];
		}
		driver[(*pos)++] = 0x20;
		driver[(*pos)++] = e->header.efo.v_fadeout[0];
		driver[(*pos)++] = e->header.efo.v_fadeout[1];
		driver[(*pos)++] = 0x90;	// bcc
		driver[*pos] = (mainpos - *pos - 1) & 0xff;
		(*pos)++;
	}
}

static void generate_drivers(int lastside) {
	int need_prepare = 1, need_cia = 1;
	int i;
	uint8_t page;
	uint8_t driver[512];
	int pos, mainpos, size;

	for(i = 1; i < neffect; i++) {
		if(effect[i].header.flags & EF_BLANK) {
			errx(1, "Internal error: Unexpected blank effect.");
		}
		pos = 0;
		if(need_cia) {
			driver[pos++] = 0xb0;	// bcs
			driver[pos++] = sizeof(data_commonsetup) + 1;
			memcpy(
				driver + pos,
				data_commonsetup,
				sizeof(data_commonsetup));
			pos += sizeof(data_commonsetup);
			driver[pos++] = 0x18;	// clc
		}
		if(need_prepare) {
			if(effect[i].header.efo.v_prepare[0]
			|| effect[i].header.efo.v_prepare[1]) {
				if(i == 1
				&& (effect[i].header.efo.v_setup[0]
				|| effect[i].header.efo.v_setup[1])) {
					driver[pos++] = 0x08;	// php
					driver[pos++] = 0x20;
					driver[pos++] = effect[i].header.efo.v_prepare[0];
					driver[pos++] = effect[i].header.efo.v_prepare[1];
					driver[pos++] = 0x28;	// plp
				} else {
					driver[pos++] = 0x20;
					driver[pos++] = effect[i].header.efo.v_prepare[0];
					driver[pos++] = effect[i].header.efo.v_prepare[1];
				}
			}
		}
		if(effect[i].header.flags & EF_SCRIPTBLANK) {
			if(effect[i].play_address) {
				driver[pos++] = 0xa2;	// ldx imm
				driver[pos++] = effect[i].play_address & 0xff;
				driver[pos++] = 0xa0;	// ldy imm
				driver[pos++] = effect[i].play_address >> 8;
				driver[pos++] = 0x20;
				driver[pos++] = ADDR_IRQ & 0xff;
				driver[pos++] = ADDR_IRQ >> 8;
			} else {
				driver[pos++] = 0x78;	// sei
			}
			driver[pos++] = 0xa9;
			driver[pos++] = 0;
			driver[pos++] = 0x8d;
			driver[pos++] = 0x20;
			driver[pos++] = 0xd0;
			driver[pos++] = 0x8d;
			driver[pos++] = 0x11;
			driver[pos++] = 0xd0;
			driver[pos++] = 0x8d;
			driver[pos++] = 0x15;
			driver[pos++] = 0xd0;
			driver[pos++] = 0xa9;
			driver[pos++] = 0xf0;
			driver[pos++] = 0x8d;
			driver[pos++] = 0x12;
			driver[pos++] = 0xd0;
		} else if(effect[i].header.efo.v_irq[0]
		|| effect[i].header.efo.v_irq[1]) {
			driver[pos++] = 0xa9;	// lda imm
			driver[pos++] = effect[i].header.efo.v_irq[0];
			driver[pos++] = 0x8d;	// sta abs
			driver[pos++] = 0xfe;
			driver[pos++] = 0xff;
			driver[pos++] = 0xa9;	// lda imm
			driver[pos++] = effect[i].header.efo.v_irq[1];
			driver[pos++] = 0x8d;	// sta abs
			driver[pos++] = 0xff;
			driver[pos++] = 0xff;
			if(effect[i].header.efo.v_setup[0]
			|| effect[i].header.efo.v_setup[1]) {
				driver[pos++] = 0x20;
				driver[pos++] = effect[i].header.efo.v_setup[0];
				driver[pos++] = effect[i].header.efo.v_setup[1];
			}
			driver[pos++] = 0x4e;	// lsr abs
			driver[pos++] = 0x19;
			driver[pos++] = 0xd0;
			driver[pos++] = 0x58;	// cli
		} else if(effect[i].header.efo.v_setup[0] || effect[i].header.efo.v_setup[1]) {
			driver[pos++] = 0x20;
			driver[pos++] = effect[i].header.efo.v_setup[0];
			driver[pos++] = effect[i].header.efo.v_setup[1];
		}
		if(i == neffect - 1) {
			if(lastside) {
				mainpos = pos;
				if(effect[i].header.efo.v_main[0]
				|| effect[i].header.efo.v_main[1]) {
					driver[pos++] = 0x20;
					driver[pos++] = effect[i].header.efo.v_main[0];
					driver[pos++] = effect[i].header.efo.v_main[1];
				}
				driver[pos++] = 0x18;	// clc
				driver[pos++] = 0x90;	// bcc
				driver[pos] = (mainpos - pos - 1) & 0xff;
				pos++;
			} else {
				// We've already checked that there's no main routine.
				// Wait for the new disk.
				driver[pos++] = 0x20;
				driver[pos++] = ADDR_LOAD & 0xff;
				driver[pos++] = ADDR_LOAD >> 8;
				if(effect[i].header.efo.v_fadeout[0]
				|| effect[i].header.efo.v_fadeout[1]) {
					mainpos = pos;
					driver[pos++] = 0x20;
					driver[pos++] = effect[i].header.efo.v_fadeout[0];
					driver[pos++] = effect[i].header.efo.v_fadeout[1];
					driver[pos++] = 0x90;	// bcc
					driver[pos] = (mainpos - pos - 1) & 0xff;
					pos++;
				}
				// Load first part from new disk.
				driver[pos++] = 0x20;
				driver[pos++] = ADDR_LOAD & 0xff;
				driver[pos++] = ADDR_LOAD >> 8;
				if(effect[i].header.efo.v_cleanup[0]
				|| effect[i].header.efo.v_cleanup[1]) {
					driver[pos++] = 0x20;
					driver[pos++] = effect[i].header.efo.v_cleanup[0];
					driver[pos++] = effect[i].header.efo.v_cleanup[1];
				}
				driver[pos++] = 0x78;	// sei
				driver[pos++] = 0x4c;
				driver[pos++] = ADDR_NEXTSIDE & 0xff;
				driver[pos++] = ADDR_NEXTSIDE >> 8;
			}
		} else {
			if(effect[i].header.efo.v_main[0]
			|| effect[i].header.efo.v_main[1]) {
				generate_main_and_fadeout(driver, &pos, &effect[i]);
				effect[i].driver_loadcall = pos;
				driver[pos++] = 0x20;
				driver[pos++] = ADDR_LOAD & 0xff;
				driver[pos++] = ADDR_LOAD >> 8;
				if(effect[i + 1].header.efo.v_prepare[0]
				|| effect[i + 1].header.efo.v_prepare[1]) {
					driver[pos++] = 0x20;
					driver[pos++] = effect[i + 1].header.efo.v_prepare[0];
					driver[pos++] = effect[i + 1].header.efo.v_prepare[1];
				}
			} else {
				effect[i].driver_loadcall = pos;
				driver[pos++] = 0x20;
				driver[pos++] = ADDR_LOAD & 0xff;
				driver[pos++] = ADDR_LOAD >> 8;
				if(effect[i + 1].header.efo.v_prepare[0]
				|| effect[i + 1].header.efo.v_prepare[1]) {
					driver[pos++] = 0x20;
					driver[pos++] = effect[i + 1].header.efo.v_prepare[0];
					driver[pos++] = effect[i + 1].header.efo.v_prepare[1];
				}
				generate_main_and_fadeout(driver, &pos, &effect[i]);
			}
			if(effect[i].header.efo.v_cleanup[0]
			|| effect[i].header.efo.v_cleanup[1]) {
				driver[pos++] = 0x20;
				driver[pos++] = effect[i].header.efo.v_cleanup[0];
				driver[pos++] = effect[i].header.efo.v_cleanup[1];
			}
			if(effect[i + 1].header.flags & EF_BLANK) {
				if(effect[i + 1].play_address) {
					driver[pos++] = 0xa2;	// ldx imm
					driver[pos++] = effect[i + 1].play_address & 0xff;
					driver[pos++] = 0xa0;	// ldy imm
					driver[pos++] = effect[i + 1].play_address >> 8;
					driver[pos++] = 0x20;
					driver[pos++] = ADDR_IRQ & 0xff;
					driver[pos++] = ADDR_IRQ >> 8;
				} else {
					driver[pos++] = 0x78;	// sei
				}
				driver[pos++] = 0xa9;
				driver[pos++] = 0;
				driver[pos++] = 0x8d;
				driver[pos++] = 0x20;
				driver[pos++] = 0xd0;
				driver[pos++] = 0x8d;
				driver[pos++] = 0x11;
				driver[pos++] = 0xd0;
				driver[pos++] = 0x8d;
				driver[pos++] = 0x15;
				driver[pos++] = 0xd0;
				driver[pos++] = 0xa9;
				driver[pos++] = 0xf0;
				driver[pos++] = 0x8d;
				driver[pos++] = 0x12;
				driver[pos++] = 0xd0;
				driver[pos++] = 0xa9;
				effect[i].driver_nextmsb = pos;
				driver[pos++] = 0;
				driver[pos++] = 0x48;	// pha
				driver[pos++] = 0xa9;
				effect[i].driver_nextlsb = pos;
				driver[pos++] = 0;
				driver[pos++] = 0x48;	// pha
				effect[i + 1].driver_loadcall = pos;
				driver[pos++] = 0x4c;
				driver[pos++] = ADDR_LOAD & 0xff;
				driver[pos++] = ADDR_LOAD >> 8;
				effect[i].driver_nextm1 = 1;
				need_prepare = 1;
			} else {
				driver[pos++] = 0x78;	// sei
				driver[pos++] = 0x4c;
				effect[i].driver_nextlsb = pos;
				driver[pos++] = 0;
				effect[i].driver_nextmsb = pos;
				driver[pos++] = 0;
				need_prepare = 0;
			}
		}
		if(pos > 256) errx(1, "Driver too large!");
		effect[i].driver_org =
			effect[i].chunk[0].loadaddr +
			effect[i].chunk[0].size;
		if(need_cia) {
			// The timer setup code mustn't cross a page boundary.
			size =
				((effect[i].driver_org + 0xff) & 0xff00) -
				effect[i].driver_org;
			if(size < sizeof(data_commonsetup)) {
				effect[i].chunk[0].data = realloc(
					effect[i].chunk[0].data,
					effect[i].chunk[0].size + size);
				memset(
					effect[i].chunk[0].data + effect[i].chunk[0].size,
					0,
					size);
				effect[i].chunk[0].size += size;
				effect[i].driver_org += size;
			}
		}
		effect[i].driver_size = pos;
		effect[i].chunk[0].data = realloc(
			effect[i].chunk[0].data,
			effect[i].chunk[0].size + pos);
		effect[i].driver_code = effect[i].chunk[0].data + effect[i].chunk[0].size;
		memcpy(effect[i].driver_code, driver, pos);
		effect[i].chunk[0].size += pos;
		if(((effect[i].driver_org - 1) & 0xff00)
		!= ((effect[i].driver_org + pos - 1) & 0xff00)) {
			// Driver crosses into a new page. Check that it's free.
			page = (effect[i].driver_org + pos - 1) >> 8;
			if(page == 0xd0) {
				errx(1, "Driver for effect '%s' (%d bytes at $%04x) collides with I/O range",
					effect[i].filename,
					effect[i].driver_size,
					effect[i].driver_org);
			} else if(effect[i].header.pageflags[page] & PF_LOADED) {
				errx(1, "Driver for effect '%s' (%d bytes at $%04x) collides with chunk '%s'",
					effect[i].filename,
					effect[i].driver_size,
					effect[i].driver_org,
					effect[i].chunk[effect[i].header.chunkmap[page]].name);
			} else if(effect[i].header.pageflags[page] & (PF_USED | PF_INHERIT)) {
				errx(1, "Driver for effect '%s' (%d bytes at $%04x) collides with used/inherited page %02x",
					effect[i].filename,
					effect[i].driver_size,
					effect[i].driver_org,
					page);
			}
			effect[i].header.pageflags[page] |= PF_LOADED | PF_USED;
			effect[i].needs_loading[page] = 1;
		}
		if(effect[i + 1].header.flags & EF_BLANK) {
			i++;
		}
		need_cia = 0;
	}
}

static uint16_t patch_drivers() {
	int i, j;
	uint8_t firstlsb, firstmsb;
	uint8_t *prevlsb = &firstlsb, *prevmsb = &firstmsb;
	uint16_t prevm1 = 0;
	uint8_t *driver;
	uint16_t drv_addr, drv_length;

	for(i = 1; i < neffect; i++) {
		if(effect[i].header.flags & EF_BLANK) {
			if(!effect[i].loads && effect[i].driver_loadcall) {
				driver = effect[i - 1].driver_code;
				driver[effect[i].driver_loadcall + 1] = ADDR_RTS & 0xff;
				driver[effect[i].driver_loadcall + 2] = ADDR_RTS >> 8;
			}
		} else {
			*prevlsb = (effect[i].driver_org - prevm1) & 0xff;
			*prevmsb = (effect[i].driver_org - prevm1) >> 8;
			if(!effect[i].loads && effect[i].driver_loadcall) {
				effect[i].driver_code[effect[i].driver_loadcall] = 0x2c; // bit abs
			}
			prevlsb = effect[i].driver_code + effect[i].driver_nextlsb;
			prevmsb = effect[i].driver_code + effect[i].driver_nextmsb;
			prevm1 = !!effect[i].driver_nextm1;
		}
	}

	if(verbose) {
		for(i = 1; i < neffect; i++) {
			if(!(effect[i].header.flags & EF_BLANK)) {
				drv_addr = effect[i].driver_org;
				if(verbose == 1) {
					fprintf(
						stderr,
						"Driver for '%s' at $%04x.\n",
						effect[i].filename,
						drv_addr);
				} else {
					driver = effect[i].driver_code;
					drv_length = effect[i].driver_size;
					fprintf(
						stderr,
						"Driver for '%s' at $%04x:",
						effect[i].filename,
						drv_addr);
					for(j = 0; j < drv_length; j++) {
						fprintf(
							stderr,
							" %02x",
							driver[j]);
					}
					fprintf(stderr, "\n");
				}
			}
		}
	}

	return firstlsb | (firstmsb << 8);
}

static void make_dirart(uint8_t *dirart, char *fname) {
	int i, n = 0;
	FILE *f;
	char buf[64];

	memset(dirart, 0xa0, DIRARTBLOCKS * 8 * 16);
	if(fname) {
		f = fopen(fname, "r");
		if(!f) err(1, "%s", fname);
		while(fgets(buf, sizeof(buf), f)) {
			if(strlen(buf) && buf[strlen(buf) - 1] == '\n') {
				buf[strlen(buf) - 1] = 0;
			}
			if(strlen(buf) && buf[strlen(buf) - 1] == '\r') {
				buf[strlen(buf) - 1] = 0;
			}
			if(n >= DIRARTBLOCKS * 8) {
				errx(1, "Too many directory art lines.");
			}
			for(i = 0; i < 16 && buf[i]; i++) {
				dirart[n * 16 + i] = buf[i];
			}
			n++;
		}
		fclose(f);
	} else {
		dirart[0] = 'D';
		dirart[1] = 'E';
		dirart[2] = 'M';
		dirart[3] = 'O';
	}
}

static void visualise_mem(int ppc) {
	int i, j, p, flags, chunks;
	char ch;
	struct load *ld;

	for(p = 0, i = -1; p < 256; p += ppc) {
		if(p >> 4 != i) {
			fprintf(stderr, "%x", p >> 4);
			i = p >> 4;
		} else fprintf(stderr, " ");
	}
	fprintf(stderr, "\n");

	for(i = 0; i < neffect; i++) {
		for(p = 0; p < 256; p += ppc) {
			flags = 0;
			chunks = 0;
			for(j = 0; j < ppc; j++) {
				flags |= effect[i].header.pageflags[p + j];
				chunks |= effect[i].header.chunkmap[p + j];
				if(p + j >= FIRST_RESERVED_PAGE
				&& p + j < LAST_RESERVED_PAGE) {
					flags |= PF_RESERVED;
				}
			}
			if(flags & PF_INHERIT) {
				ch = '|';
			} else if(flags & PF_LOADED) {
				ch = chunks? 'L' : 'c';
			} else if(flags & PF_USED) {
				ch = 'U';
			} else if(flags & PF_RESERVED) {
				ch = 'r';
			} else {
				int loaded = 0;
				for(ld = effect[i].loads; ld && !loaded; ld = ld->next) {
					for(j = 0; j < ppc; j++) {
						if(ld->pages[p + j]) {
							loaded = 1;
							break;
						}
					}
				}
				ch = loaded? '*' : '.';
			}
			fprintf(stderr, "%c", ch);
		}
		if(effect[i].blocks_loaded) {
			fprintf(stderr, " %3d %s\n",
				effect[i].blocks_loaded,
				effect[i].filename);
		} else {
			fprintf(stderr, "     %s\n",
				effect[i].filename);
		}
	}
}

static struct chunk *rebuild_chunks(struct load *ld) {
	struct chunk *list = 0, *ch, *ch2, **ptr;
	int p;
	uint32_t start, end;

	while(ld) {
		for(p = 0; p < 256; p++) {
			if(ld->pages[p]) {
				start = p << 8;
				end = start + 0x100;
				if(start < ld->chunk->loadaddr) {
					start = ld->chunk->loadaddr;
				}
				if(end > ld->chunk->loadaddr + ld->chunk->size) {
					end = ld->chunk->loadaddr + ld->chunk->size;
				}
				ch = calloc(1, sizeof(*ch));
				ch->loadaddr = start;
				ch->size = end - start;
				ch->data = malloc(ch->size);
				ch->under_io = (start <= 0xdfff && end > 0xd000);
				memcpy(
					ch->data,
					ld->chunk->data + (start - ld->chunk->loadaddr),
					ch->size);
				memcpy(
					ch->name,
					ld->chunk->name,
					sizeof(ch->name));
				for(ptr = &list; *ptr; ptr = &(*ptr)->next) {
					if((*ptr)->loadaddr > start) break;
				}
				ch->next = *ptr;
				*ptr = ch;
			}
		}
		ld = ld->next;
	}

	for(ch = list; ch; ch = ch2) {
		ch2 = ch->next;
		if(ch2 && ch->loadaddr + ch->size == ch->next->loadaddr) {
			ch->data = realloc(
				ch->data,
				ch->size + ch->next->size);
			memcpy(
				ch->data + ch->size,
				ch->next->data,
				ch->next->size);
			ch->under_io |= ch->next->under_io;
			if(strcmp(ch->name, ch->next->name)) {
				snprintf(
					ch->name,
					sizeof(ch->name),
					"(combined)");
			}
			ch->size += ch2->size;
			ch->next = ch->next->next;
			free(ch2->data);
			free(ch2);
			ch2 = ch;
		}
	}

	if(verbose >= 2) {
		fprintf(stderr, "Chunks to compress:\n");
		for(ch = list; ch; ch = ch->next) {
			fprintf(
				stderr,
				"$%04x-$%04x %s\n",
				ch->loadaddr,
				ch->loadaddr + ch->size - 1,
				ch->name);
		}
	}

	return list;
}

static void usage(char *prgname) {
	fprintf(stderr, "%s\n\n", SPINDLE_VERSION);
	fprintf(stderr, "Usage: %s [options] script\n", prgname);
	fprintf(stderr, "Options:\n");
	fprintf(stderr, "  -h --help        Display this text.\n");
	fprintf(stderr, "  -V --version     Display version information.\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "  -o --output      Output filename. Default: disk.d64\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "  -a --dirart      Name of file containing directory art.\n");
	fprintf(stderr, "  -t --title       Name of disk.\n");
	fprintf(stderr, "  -d --dir-entry   Which directory entry is the PRG. Default: 0.\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "  -n --next-magic  24-bit code to identify the next disk side.\n");
	fprintf(stderr, "  -m --my-magic    24-bit code required to enter this side.\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "  -v --verbose     Be verbose. Can be specified multiple times.\n");
	fprintf(stderr, "  -w --wide        Make memory chart wider. Can be specified twice.\n");
	exit(1);
}

int main(int argc, char **argv) {
	struct option longopts[] = {
		{"help", 0, 0, 'h'},
		{"version", 0, 0, 'V'},
		{"verbose", 0, 0, 'v'},
		{"output", 1, 0, 'o'},
		{"wide", 0, 0, 'w'},
		{"dirart", 1, 0, 'a'},
		{"dir-entry", 1, 0, 'd'},
		{"title", 1, 0, 't'},
		{"my-magic", 1, 0, 'm'},
		{"next-magic", 1, 0, 'n'},
		{0, 0, 0, 0}
	};
	char *outname = "disk.d64", *dirart_fname = 0;
	uint8_t dirart[DIRARTBLOCKS * 8 * 16];
	int opt, dir_entry = 0, visualisation_width = 4;
	char *disk_title = "SPINDLE DISK", *disk_id = "uk";
	struct blockfile bf;
	uint16_t jumpaddr;
	int i;
	struct chunk *ch;
	uint32_t my_magic = 0x4c4654, next_magic = 0;

	do {
		opt = getopt_long(argc, argv, "?hVvo:wQa:d:t:m:n:", longopts, 0);
		switch(opt) {
			case 0:
			case '?':
			case 'h':
				usage(argv[0]);
				break;
			case 'V':
				fprintf(stderr, "%s\n", SPINDLE_VERSION);
				return 0;
			case 'v':
				verbose++;
				break;
			case 'w':
				if(visualisation_width > 1) {
					visualisation_width /= 2;
				}
				break;
			case 'o':
				outname = strdup(optarg);
				break;
			case 'a':
				dirart_fname = strdup(optarg);
				break;
			case 'd':
				dir_entry = atoi(optarg);
				break;
			case 't':
				disk_title = strdup(optarg);
				break;
			case 'm':
				my_magic = strtol(optarg, 0, 0) & 0xffffff;
				break;
			case 'n':
				next_magic = strtol(optarg, 0, 0) & 0xffffff;
				break;
		}
	} while(opt >= 0);

	if(argc != optind + 1) usage(argv[0]);

	load_script(argv[optind]);
	if(next_magic
	&& (effect[neffect - 1].header.efo.v_main[0]
	|| effect[neffect - 1].header.efo.v_main[1])) {
		errx(
			1,
			"A flip-disk part (last effect on non-last side) "
			"cannot have a main routine.");
	}
	make_dirart(dirart, dirart_fname);

	insert_fillers();
	patch_effects();
	generate_drivers(!next_magic);
	schedule_loads();
	jumpaddr = patch_drivers();

	visualise_mem(visualisation_width);

	disk_init(disk_title, disk_id);
	disk_storeloader(
		&bf,
		dirart,
		dir_entry,
		my_magic,
		next_magic);
	for(i = 0; i < neffect; i++) {
		if(effect[i].loads) {
			ch = rebuild_chunks(effect[i].loads);
			compress_group(ch, &bf, i? 0 : jumpaddr);
			// could free the chunks
		}
	}
	disk_closeside(&bf, !next_magic);
	disk_write(outname);

	return 0;
}
