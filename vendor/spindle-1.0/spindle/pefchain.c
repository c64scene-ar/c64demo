// Spindle by lft, http://www.linusakesson.net/software/spindle/

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
#include "pefchain.h"
#include "commonsetup.h"

#define FIRST_RESERVED_PAGE	0x0c
#define LAST_RESERVED_PAGE	0x0f
#define FIRST_RESERVED_ZP	0xf0
#define LAST_RESERVED_ZP	0xf7
#define LOADER_ORG		0x0c00
#define DECRUNCHER_ORG		0x0e00

#define SPECIAL_REQUEST	(LOADER_ORG + 0x40)
#define BLANK_IRQ	(DECRUNCHER_ORG + 0xc0)
#define BLANK_JSR	(BLANK_IRQ + 0x0c)
#define BLANK_SETUP	(BLANK_IRQ + 0x1b)
#define HANDOVER_ORG	(LOADER_ORG + 0x180)
#define HANDOVER_SIZE	0x80

#define MAXEFFECTS 64

#define MAXACTIONS (MAXEFFECTS * 12)

int verbose;
int handover_page;

struct chunk {
	uint16_t	loadaddr;
	uint16_t	size;
	uint8_t		*data;
	char		name[64];
	int		under_io;
};

enum {
	COND_DROP,
	COND_SPACE,
};

struct effect {
	struct header	header;
	struct chunk	chunk[MAXCHUNKS];
	uint16_t	condaddr;
	uint8_t		condval;
	char		filename[32];
	uint16_t	play_address;
	uint8_t		needs_loading[256];
	int		blocks_loaded;
} effect[MAXEFFECTS];
int neffect;

struct load {
	struct load	*next;
	struct chunk	*chunk;
	uint8_t		pages[256];
};

enum {
	A_LOAD_LITTLE,
	A_LOAD_MUCH,
	A_SETUP_CLI,
	A_CLEANUP_SEI,
	A_PREPARE,
	A_MAIN_ONCE,
	A_MAIN_FOREVER,
	A_MAIN_UNTIL_SPACE,
	A_MAIN_UNTIL_COND,
	A_MAIN_UNTIL_FADED,
};

char *action_descr[] = {
	"load little",
	"load much",
	"call setup, cli",
	"call cleanup, sei",
	"call prepare",
	"main once",
	"main forever",
	"main until space",
	"main until cond",
	"main until faded",
};

struct action {
	int		action;
	int		effect;
	struct load	*loads;
} action[MAXACTIONS];
int naction;

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

static void create_blank_effect(struct effect *e) {
	e->header.flags = EF_SAFE_IO | EF_DONT_LOAD;
	e->header.efo.v_irq[0] = BLANK_IRQ & 255;
	e->header.efo.v_irq[1] = BLANK_IRQ >> 8;
	e->header.efo.v_setup[0] = BLANK_SETUP & 255;
	e->header.efo.v_setup[1] = BLANK_SETUP >> 8;
	e->header.efo.v_jsr[0] = BLANK_JSR & 255;
	e->header.efo.v_jsr[1] = BLANK_JSR >> 8;
	snprintf(e->filename, sizeof(e->filename), "(blank)");
}

static void load_script(char *filename) {
	FILE *f;
	char buf[256], *cond;
	int i, p1, p2;
	uint16_t play_address = 0;
	struct effect *e;

	f = fopen(filename, "r");
	if(!f) err(1, "fopen: %s", filename);

	while(fgets(buf, sizeof(buf), f)) {
		if(strlen(buf) && buf[strlen(buf) - 1] == '\n') {
			buf[strlen(buf) - 1] = 0;
		}
		if(*buf && *buf != '#') {
			for(i = 0; buf[i] && !strchr("\n\r\t ", buf[i]); i++);
			if(!i) errx(1,
				"Unexpected whitespace at beginning of script line '%s'.",
				buf);
			if(buf[i]) buf[i++] = 0;
			while(buf[i] && strchr("\n\r\t ", buf[i])) i++;
			cond = buf + i;
			if(!*cond) errx(1,
				"Expected a condition on script line '%s'.",
				buf);

			if(neffect == MAXEFFECTS) errx(1, "Increase MAXEFFECTS!");
			e = &effect[neffect++];
			e->play_address = play_address;
			if(!strcmp(buf, "-")) {
				create_blank_effect(e);
			} else {
				load_pef(e, buf);
				if(!(e->header.efo.v_irq[0] || e->header.efo.v_irq[1])) {
					e->header.efo.v_irq[0] = BLANK_IRQ & 255;
					e->header.efo.v_irq[1] = BLANK_IRQ >> 8;
					e->header.efo.v_jsr[0] = BLANK_JSR & 255;
					e->header.efo.v_jsr[1] = BLANK_JSR >> 8;
				}
				if(e->header.installs_music[0]
				|| e->header.installs_music[1]) {
					play_address =
						e->header.installs_music[0] |
						(e->header.installs_music[1] << 8);
				}
				for(i = 0; i < 256; i++) {
					if(e->header.pageflags[i] & (PF_LOADED | PF_USED)) {
						if(i >= FIRST_RESERVED_PAGE
						&& i <= LAST_RESERVED_PAGE) {
							errx(1,
								"Effect %s uses page $%02x "
								"which is reserved for the spindle system.",
								e->filename,
								i);
						} else if(handover_page && i == handover_page) {
							errx(1,
								"Effect %s uses page $%02x, "
								"colliding with the handover area.",
								e->filename,
								i);
						}
					}
					if((e->header.pageflags[i] & PF_ZPUSED)
					&& i >= FIRST_RESERVED_ZP
					&& i <= LAST_RESERVED_ZP) {
						errx(1,
							"Effect %s uses zero-page address $%02x "
							"which is reserved for the spindle system.",
							e->filename,
							i);
					}
					e->needs_loading[i] = e->header.pageflags[i] & PF_LOADED;
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

	if(!neffect) errx(1, "No effects in script!");

	fclose(f);
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
					errx(1, "Effect %s is using page $%02x which is already occupied by the music player.",
						e->filename,
						p);
				}
				e->header.pageflags[p] |= PF_INHERIT;
			}
			if(e->header.installs_music[0]
			|| e->header.installs_music[1]) {
				resident[p] = e->header.pageflags[p] & PF_MUSIC;
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

static void generate_main_loops(int i) {
	if(effect[i].condaddr) {
		action[naction].action = A_MAIN_UNTIL_COND;
	} else switch(effect[i].condval) {
		case COND_DROP:
			action[naction].action = A_MAIN_ONCE;
			break;
		case COND_SPACE:
			action[naction].action = A_MAIN_UNTIL_SPACE;
			break;
	}
	action[naction].effect = i;
	naction++;
	action[naction].action = A_MAIN_UNTIL_FADED;
	action[naction].effect = i;
	naction++;
}

static void generate_actions() {
	int i;

	naction = 0;
	action[naction].action = A_LOAD_LITTLE;
	action[naction].effect = 0;	// actually not true since no effect is running yet
	action[naction].loads = 0;
	naction++;
	action[naction].action = A_PREPARE;
	action[naction].effect = 0;
	naction++;
	for(i = 0; i < neffect; i++) {
		action[naction].action = A_SETUP_CLI;
		action[naction].effect = i;
		naction++;
		if(i == neffect - 1) {
			action[naction].action = A_MAIN_FOREVER;
			action[naction].effect = i;
			naction++;
		} else {
			if(effect[i].header.efo.v_main[0]
			|| effect[i].header.efo.v_main[1]) {
				generate_main_loops(i);
				action[naction].action = A_LOAD_LITTLE;
				action[naction].effect = i;
				action[naction].loads = 0;
				naction++;
				action[naction].action = A_PREPARE;
				action[naction].effect = i + 1;
				naction++;
			} else {
				action[naction].action = A_LOAD_MUCH;
				action[naction].effect = i;
				action[naction].loads = 0;
				naction++;
				action[naction].action = A_PREPARE;
				action[naction].effect = i + 1;
				naction++;
				generate_main_loops(i);
			}
			action[naction].action = A_CLEANUP_SEI;
			action[naction].effect = i;
			naction++;
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

static void dump_actions() {
	int i;
	struct load *l;

	for(i = 0; i < naction; i++) {
		if(action[i].action == A_SETUP_CLI) {
			fprintf(stderr, "--------------\n");
		}
		if(action[i].action == A_LOAD_LITTLE
		|| action[i].action == A_LOAD_MUCH) {
			if(action[i].loads) {
				fprintf(stderr, "%-20s",
					action_descr[action[i].action]);
				fprintf(stderr, "        ");
				for(l = action[i].loads; l; l = l->next) {
					fprintf(stderr, "%-30s ", l->chunk->name);
					dump_ranges(l->pages);
					if(l->next) fprintf(stderr, "\n%28s", "");
				}
				fprintf(stderr, "\n");
			}
		} else if(action[i].action == A_PREPARE) {
			if(effect[action[i].effect].header.efo.v_prepare[0]
			|| effect[action[i].effect].header.efo.v_prepare[1]) {
				fprintf(stderr, "%-20s",
					action_descr[action[i].action]);
				fprintf(stderr, "        ");
				fprintf(stderr, "%s\n",
					effect[action[i].effect].filename);
			}
		} else {
			fprintf(stderr, "%-20s", action_descr[action[i].action]);
			if(action[i].action == A_MAIN_UNTIL_COND) {
				fprintf(stderr, "%04x %02x ",
					effect[action[i].effect].condaddr,
					effect[action[i].effect].condval);
			} else {
				fprintf(stderr, "        ");
			}
			fprintf(stderr, "%s\n", effect[action[i].effect].filename);
		}
	}
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
	page[handover_page] = 0;
	for(p = FIRST_RESERVED_PAGE; p <= LAST_RESERVED_PAGE; p++) page[p] = 0;
	zp[0] = zp[1] = 0;
	for(p = FIRST_RESERVED_ZP; p < LAST_RESERVED_ZP; p++) zp[p] = 0;

	fprintf(stderr,
		"Suggestion: Move things around or insert a part that only touches pages ");
	dump_ranges(page);
	fprintf(stderr, " and zero-page locations ");
	dump_ranges(zp);
	fprintf(stderr, ".\n");
}

static void insert_fillers() {
	int i, p = 0, need_filler, pagecoll, zpcoll;
	uint8_t pages[256], zp[256], iopage[16];

	for(i = 0; i < effect[0].header.nchunk; i++) {
		p += (effect[0].chunk[i].size + 255) >> 8;
	}
	// Three tracks is a conservative limit.
	if(p > 3 * 21) {
		fprintf(stderr,
			"Warning: Inserting blank filler before '%s' "
			"because the first part must fit in %d blocks.\n",
			effect[0].filename,
			3 * 21);
		add_filler_before(0);
	}

	if((effect[0].header.pageflags[8] & PF_LOADED)
	|| (effect[0].header.pageflags[9] & PF_LOADED)) {
		fprintf(stderr,
			"Warning: Inserting blank filler before '%s' "
			"because the first part mustn't interfere with "
			"the bootstrap loader at pages 8-9.\n",
			effect[0].filename);
		add_filler_before(0);
	}

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
		}
		if(i < neffect - 1) {
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

static void add_load(int a, struct chunk *c, uint8_t page) {
	struct load *l;

	for(l = action[a].loads; l; l = l->next) {
		if(l->chunk == c) break;
	}
	if(!l) {
		l = calloc(1, sizeof(struct load));
		l->chunk = c;
		l->next = action[a].loads;
		action[a].loads = l;
	}
	l->pages[page] = 1;
}

static int preferred_loading_slot(int later, int earlier) {
	if(later == -1) return earlier;
	if((effect[action[earlier].effect].header.flags & EF_DONT_LOAD)
	&& !(effect[action[later].effect].header.flags & EF_DONT_LOAD)) {
		return later;
	}
	return earlier;
}

static void schedule_loads_for(int fallback, struct effect *target) {
	int i, p, iosafe;
	struct effect *candidate;
	struct chunk *c;

	candidate = &effect[action[fallback].effect];
	iosafe = (candidate->header.flags & EF_SAFE_IO)? fallback : -1;

	for(i = fallback - 1; i >= 0; i--) {
		candidate = &effect[action[i].effect];
		if(action[i].action == A_LOAD_MUCH) {
			fallback = preferred_loading_slot(fallback, i);
			if(candidate->header.flags & EF_SAFE_IO) {
				iosafe = preferred_loading_slot(iosafe, i);
			}
		} else if(action[i].action == A_LOAD_LITTLE) {
			if(iosafe < 0
			&& (candidate->header.flags & EF_SAFE_IO)) {
				iosafe = preferred_loading_slot(iosafe, i);
			}
		} else {
			// This is not a loading action, but
			// perhaps it is an interfering action.
			for(p = 0; p < 256; p++) {
				if(target->needs_loading[p]
				&& (candidate->header.pageflags[p] & (PF_USED | PF_INHERIT))) {
					// Page can't be loaded before this effect.
					c = &target->chunk[target->header.chunkmap[p]];
					if(p >= 0xd0 && p <= 0xdf) {
						if(iosafe < 0) errx(1,
							"Internal error: No i/o safe loading slot found!");
						add_load(iosafe, c, p);
					} else {
						add_load(fallback, c, p);
					}
					target->needs_loading[p] = 0;
				}
			}
		}
	}

	for(p = 0; p < 256; p++) {
		if(target->needs_loading[p]) {
			c = &target->chunk[target->header.chunkmap[p]];
			if(p >= 0xd0 && p <= 0xdf) {
				if(iosafe < 0) errx(1,
					"Internal error: No i/o safe loading slot found!");
				add_load(iosafe, c, p);
			} else {
				add_load(fallback, c, p);
			}
		}
	}
}

static void schedule_loads() {
	int i, j;

	for(i = naction - 1; i >= 0; i--) {
		if(action[i].action == A_PREPARE
		&& effect[action[i].effect].header.nchunk) {
			for(j = i - 1; j >= 0; j--) {
				if(action[j].action == A_LOAD_LITTLE
				|| action[j].action == A_LOAD_MUCH) {
					break;
				}
			}
			if(j < 0) errx(1, "Internal error. No load slot found.");
			// j is the latest possible load slot,
			// but we try to load as early as possible.
			schedule_loads_for(j, &effect[action[i].effect]);
		}
	}
}

static void compress_range(
	struct blockmap *bm,
	struct load *l,
	int firstpage,
	int lastpage)
{
	int firstaddr, endaddr;
	char buf[128];

	firstaddr = firstpage << 8;
	if(firstaddr < l->chunk->loadaddr) {
		firstaddr = l->chunk->loadaddr;
	}
	endaddr = (lastpage + 1) << 8;
	if(endaddr > l->chunk->loadaddr + l->chunk->size) {
		endaddr = l->chunk->loadaddr + l->chunk->size;
	}
	snprintf(buf, sizeof(buf), "%s [%04x-%04x]",
		l->chunk->name,
		firstaddr,
		endaddr - 1);
	compress(
		bm,
		l->chunk->data + firstaddr - l->chunk->loadaddr,
		endaddr - firstaddr,
		firstaddr,
		buf);
}

static void compress_loads(struct blockmap *bm, struct load *loads) {
	struct load *l;
	int p, firstpage;

	for(l = loads; l; l = l->next) {
		firstpage = -1;
		for(p = 0; p < 256; p++) {
			if(l->pages[p]) {
				if(p >= 0xd0 && p <= 0xdf) bm->below_io = 1;
				if(firstpage < 0) firstpage = p;
			} else {
				if(firstpage >= 0) {
					compress_range(
						bm,
						l,
						firstpage,
						p - 1);
					firstpage = -1;
				}
			}
		}
		if(firstpage >= 0) {
			compress_range(bm, l, firstpage, 255);
		}
	}
}

static void compress_handover(struct blockmap *bm, uint8_t *handover, int size) {
	compress(
		bm,
		handover,
		size,
		handover_page? (handover_page << 8) : HANDOVER_ORG,
		"(handover)");
}

static void make_filespec(struct filespec *fs, struct blockmap *bm) {
	int i, j, any;

	memset(fs, 0, sizeof(*fs));
	for(i = 1; i <= NTRACK; i++) {
		any = 0;
		for(j = 0; j < 24; j++) {
			if(bm->map[i - 1][j]) {
				if(!any) {
					fs->ntrack++;
					fs->spec[fs->ntrack - 1][0] = i << 2;
					any = 1;
				}
				fs->spec[fs->ntrack - 1][1 + j / 8] |= 0x80 >> (j % 8);
			}
		}
	}
	fs->below_io = bm->below_io;
}

static int generate_handover(uint8_t *handover, int start, int end, struct blockmap *link) {
	int i, j, delta;
	uint16_t org, specaddr, looporg, addr, startaddr;
	struct action *a;
	struct effect *e;
	struct filespec spec;
	uint8_t involved[MAXEFFECTS];

	startaddr = handover_page? (handover_page << 8) : HANDOVER_ORG;

	org = 0;
	handover[org++] = 0x20;				// jsr
	handover[org++] = LOADER_ORG & 255;
	handover[org++] = LOADER_ORG >> 8;

	// Entry point:
	handover[org++] = 0xa9;				// lda imm
	handover[org++] = link->nblock? 0xfc : 0xf8;	// fc = motor off, f8 = reset
	handover[org++] = 0x20;				// jsr
	handover[org++] = SPECIAL_REQUEST & 255;
	handover[org++] = SPECIAL_REQUEST >> 8;

	if(start == 0) {
		memcpy(handover + org, data_commonsetup, sizeof(data_commonsetup));
		org += sizeof(data_commonsetup);
	}

	for(i = start; i < end; i++) {
		a = &action[i];
		e = &effect[a->effect];
		switch(a->action) {
			case A_LOAD_LITTLE:
			case A_LOAD_MUCH:
				break;
			case A_PREPARE:
				if(e->header.efo.v_prepare[0]
				|| e->header.efo.v_prepare[1]) {
					handover[org++] = 0x20;		// jsr
					handover[org++] = e->header.efo.v_prepare[0];
					handover[org++] = e->header.efo.v_prepare[1];
				}
				break;
			case A_MAIN_ONCE:
				if(e->header.efo.v_main[0]
				|| e->header.efo.v_main[1]) {
					handover[org++] = 0x20;		// jsr
					handover[org++] = e->header.efo.v_main[0];
					handover[org++] = e->header.efo.v_main[1];
				}
				break;
			case A_MAIN_UNTIL_SPACE:
				for(j = 0; j < 2; j++) {
					looporg = org;
					if(e->header.efo.v_main[0]
					|| e->header.efo.v_main[1]) {
						handover[org++] = 0x20;	// jsr
						handover[org++] = e->header.efo.v_main[0];
						handover[org++] = e->header.efo.v_main[1];
					}
					handover[org++] = 0xa9;		// lda imm
					handover[org++] = 0x7f;
					handover[org++] = 0x8d;		// sta abs
					handover[org++] = 0x00;
					handover[org++] = 0xdc;
					handover[org++] = 0xa9;		// lda imm
					handover[org++] = 0x10;
					handover[org++] = 0x2c;		// bit abs
					handover[org++] = 0x01;
					handover[org++] = 0xdc;
					delta = (looporg - (org + 2)) & 0xff;
					handover[org++] = j? 0xd0 : 0xf0;	// bne / beq
					handover[org++] = delta;
				}
				break;
			case A_MAIN_UNTIL_COND:
				looporg = org;
				if(e->header.efo.v_main[0]
				|| e->header.efo.v_main[1]) {
					handover[org++] = 0x20;		// jsr
					handover[org++] = e->header.efo.v_main[0];
					handover[org++] = e->header.efo.v_main[1];
				}
				if(e->condaddr < 0x100) {
					handover[org++] = 0xa5;		// lda zp
					handover[org++] = e->condaddr;
				} else {
					handover[org++] = 0xad;		// lda abs
					handover[org++] = e->condaddr & 255;
					handover[org++] = e->condaddr >> 8;
				}
				handover[org++] = 0xc9;			// cmp imm
				handover[org++] = e->condval;
				delta = (looporg - (org + 2)) & 0xff;
				handover[org++] = 0xd0;			// bne
				handover[org++] = delta;
				break;
			case A_MAIN_UNTIL_FADED:
				if(e->header.efo.v_fadeout[0]
				|| e->header.efo.v_fadeout[1]) {
					looporg = org;
					if(e->header.efo.v_main[0]
					|| e->header.efo.v_main[1]) {
						handover[org++] = 0x20;	// jsr
						handover[org++] = e->header.efo.v_main[0];
						handover[org++] = e->header.efo.v_main[1];
					}
					handover[org++] = 0x20;		// jsr
					handover[org++] = e->header.efo.v_fadeout[0];
					handover[org++] = e->header.efo.v_fadeout[1];
					delta = (looporg - (org + 2)) & 0xff;
					handover[org++] = 0x90;		// bcc
					handover[org++] = delta;
				}
				break;
			case A_MAIN_FOREVER:
				looporg = startaddr + org;
				if(e->header.efo.v_main[0]
				|| e->header.efo.v_main[1]) {
					handover[org++] = 0x20;		// jsr
					handover[org++] = e->header.efo.v_main[0];
					handover[org++] = e->header.efo.v_main[1];
				}
				handover[org++] = 0x4c;			// jmp abs
				handover[org++] = looporg & 0xff;
				handover[org++] = looporg >> 8;
				break;
			case A_CLEANUP_SEI:
				if(e->header.efo.v_cleanup[0]
				|| e->header.efo.v_cleanup[1]) {
					handover[org++] = 0x20;		// jsr
					handover[org++] = e->header.efo.v_cleanup[0];
					handover[org++] = e->header.efo.v_cleanup[1];
				}
				handover[org++] = 0x78;			// sei
				break;
			case A_SETUP_CLI:
				handover[org++] = 0xa9;			// lda imm
				handover[org++] = e->header.efo.v_irq[0];
				handover[org++] = 0x8d;			// sta abs
				handover[org++] = 0xfe;
				handover[org++] = 0xff;
				handover[org++] = 0xa9;			// lda imm
				handover[org++] = e->header.efo.v_irq[1];
				handover[org++] = 0x8d;			// sta abs
				handover[org++] = 0xff;
				handover[org++] = 0xff;
				addr =
					e->header.efo.v_jsr[0] |
					(e->header.efo.v_jsr[1] << 8);
				if(addr && start) {
					handover[org++] = 0xa9;		// lda imm
					if(e->play_address) {
						handover[org++] = 0x20;	// jsr
					} else {
						handover[org++] = 0x2c;	// bit abs
					}
					handover[org++] = 0x8d;		// sta abs
					handover[org++] = addr & 255;
					handover[org++] = addr >> 8;
					addr++;
					handover[org++] = 0xa9;		// lda imm
					handover[org++] = e->play_address & 255;
					handover[org++] = 0x8d;		// sta abs
					handover[org++] = addr & 255;
					handover[org++] = addr >> 8;
					addr++;
					handover[org++] = 0xa9;		// lda imm
					handover[org++] = e->play_address >> 8;
					handover[org++] = 0x8d;		// sta abs
					handover[org++] = addr & 255;
					handover[org++] = addr >> 8;
				}
				if(e->header.efo.v_setup[0]
				|| e->header.efo.v_setup[1]) {
					handover[org++] = 0x20;		// jsr
					handover[org++] = e->header.efo.v_setup[0];
					handover[org++] = e->header.efo.v_setup[1];
				}
				handover[org++] = 0x4e;			// lsr abs
				handover[org++] = 0x19;
				handover[org++] = 0xd0;
				handover[org++] = 0x58;			// cli
				break;
			default:
				errx(1, "Internal error, unimplemented action: %s",
					action_descr[a->action]);
		}
	}

	if(link->nblock) {
		make_filespec(&spec, link);
		specaddr = startaddr + org + 9;
		handover[org++] = 0xa9;		// lda imm
		handover[org++] = (spec.ntrack << 1) | spec.below_io;
		handover[org++] = 0xa2;		// ldx imm
		handover[org++] = specaddr & 255;
		handover[org++] = 0xa0;		// ldy imm
		handover[org++] = specaddr >> 8;
		handover[org++] = 0x4c;		// jmp abs
		handover[org++] = startaddr & 255;
		handover[org++] = startaddr >> 8;
		for(i = 0; i < spec.ntrack; i++) {
			for(j = 0; j < 4; j++) {
				handover[org++] = spec.spec[i][j];
			}
		}
	}

	if(org > (handover_page? 256 : HANDOVER_SIZE)) {
		memset(involved, 0, sizeof(involved));
		for(i = start; i < end; i++) involved[action[i].effect] = 1;

		fprintf(stderr, "Handover code overflow (%d bytes).\n", org);
		if(!handover_page && org < 256) {
			fprintf(stderr, "Suggestion: Use the -H option.\n");
		} else {
			fprintf(stderr,
				"Suggestion: Add a phony page-in-use declaration "
				"to force loading inside the sequence.\n");
		}
		fprintf(stderr, "Effects involved:");
		for(i = 0; i < neffect; i++) {
			if(involved[i] && strcmp(effect[i].filename, "(blank)")) {
				fprintf(stderr, " %s", effect[i].filename);
			}
		}
		fprintf(stderr, "\n");
		exit(1);
	}

	if(verbose >= 2) {
		fprintf(stderr, "Handover code:\n  ");
		for(i = 0; i < org; i++) {
			fprintf(stderr, " %02x", handover[i]);
		}
		fprintf(stderr, "\n");
	}

	return org;
}

static void generate_code(struct filespec *firstfs) {
	int start, end;
	struct blockmap firstbm, bm;
	uint8_t handover[512];	// plenty of safety margin
	int size;

	// Locate the first part near the middle of the disk.
	memset(&firstbm, 0, sizeof(firstbm));
	seek_to_middle(&firstbm, 0);
	compress_loads(&firstbm, action[0].loads);
	action[0].loads = 0;

	memset(&bm, 0, sizeof(bm));
	seek_to_end(&bm);
	end = naction;
	for(start = naction - 1; start > 0; start--) {
		if(action[start].loads) {
			size = generate_handover(handover, start, end, &bm);
			memset(&bm, 0, sizeof(bm));
			seek_to_end(&bm);
			// Write handover first, otherwise it may overwrite the
			// current filespec during load.
			compress_handover(&bm, handover, size);
			compress_loads(&bm, action[start].loads);
			effect[action[start].effect].blocks_loaded += bm.nblock;
			end = start;
		}
	}

	// Sneak in the first handover page in a previously reserved sector
	// near the middle of the disk.
	size = generate_handover(handover, 0, end, &bm);
	seek_to_middle(&firstbm, 1);
	compress_handover(&firstbm, handover, size);
	make_filespec(firstfs, &firstbm);
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
				&& p + j <= LAST_RESERVED_PAGE) {
					flags |= PF_RESERVED;
				}
				if(handover_page && (p + j == handover_page)) {
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
				ch = '.';
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

static void usage(char *prgname) {
	fprintf(stderr, "%s\n\n", SPINDLE_VERSION);
	fprintf(stderr, "Usage: %s [options] script\n", prgname);
	fprintf(stderr, "Options:\n");
	fprintf(stderr, "  -h --help        Display this text.\n");
	fprintf(stderr, "  -V --version     Display version information.\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "  -o --output      Output filename. Default: disk.d64\n");
	fprintf(stderr, "  -a --dirart      Name of file containing directory art.\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "  -H --handover    Reserve a given page for handover use.\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "  -t --title       Name of disk.\n");
	fprintf(stderr, "  -d --dir-entry   Which directory entry is the PRG. Default: 0.\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "  -v --verbose     Be verbose. Can be given twice.\n");
	fprintf(stderr, "  -w --wide        Make memory chart wider. Can be given twice.\n");
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
		{"handover", 1, 0, 'H'},
		{0, 0, 0, 0}
	};
	char *outname = "disk.d64", *dirart_fname = 0;
	uint8_t dirart[DIRARTBLOCKS * 8 * 16];
	int opt, dir_entry = 0, visualisation_width = 4;
	char *disk_title = "SPINDLE DISK", *disk_id = "uk";
	struct filespec firstspec;

	do {
		opt = getopt_long(argc, argv, "?hVvo:wQa:d:t:H:", longopts, 0);
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
			case 'H':
				handover_page = strtol(optarg, 0, 16);
				if(handover_page < 2 || handover_page > 255) {
					errx(1,
						"Invalid handover option. "
						"Expected a hexadecimal page number.");
				}
				if(handover_page >= FIRST_RESERVED_PAGE
				&& handover_page <= LAST_RESERVED_PAGE) {
					errx(1,
						"Invalid handover option. That "
						"page is reserved for the spindle system.");
				}
				if(handover_page >= 0xd0 && handover_page <= 0xdf) {
					errx(1,
						"Invalid handover option. The "
						"handover page can't be in the I/O area.");
				}
				if(handover_page == 255) {
					errx(1,
						"Invalid handover option. Page "
						"$ff collides with the "
						"interrupt vectors. Seriously.");
				}
				break;
		}
	} while(opt >= 0);

	if(argc != optind + 1) usage(argv[0]);

	init_disk(disk_title, disk_id);

	load_script(argv[optind]);
	make_dirart(dirart, dirart_fname);

	insert_fillers();
	patch_effects();
	generate_actions();
	schedule_loads();
	if(verbose) dump_actions();

	generate_code(&firstspec);

	visualise_mem(visualisation_width);

	store_loader(
		&firstspec,
		(handover_page? (handover_page << 8) : HANDOVER_ORG) + 3,
		dirart,
		dir_entry);
	write_disk(outname);

	return 0;
}
