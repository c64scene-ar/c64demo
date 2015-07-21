/* Spindle by lft, http://www.linusakesson.net/software/spindle/
 */

#include <err.h>
#include <getopt.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "common.h"
#include "disk.h"
#include "pack.h"

struct group {
	struct chunk	*chunk;
	struct group	*next;
};

struct group *script;
int verbose = 0;

static uint16_t load_script(char *filename, int entry) {
	FILE *f, *cf;
	char buf[256], *ptr, *name;
	int bang, newgroup = 1, firstchunk = 1;
	long int loadaddr, offset, length;
	struct chunk *chunk, **cdest = 0;
	struct group *group = 0, **gdest = &script;

	f = fopen(filename, "r");
	if(!f) err(1, "fopen: %s", filename);

	while(fgets(buf, sizeof(buf), f)) {
		if(strlen(buf) && buf[strlen(buf) - 1] == '\n') {
			buf[strlen(buf) - 1] = 0;
		}
		if(strlen(buf) && buf[strlen(buf) - 1] == '\r') {
			buf[strlen(buf) - 1] = 0;
		}
		ptr = buf;
		while(*ptr == ' ' || *ptr == '\t') ptr++;
		if(!*ptr) {
			newgroup = 1;
		} else if(*ptr != ';' && *ptr != '#') {
			if(*ptr == '"') {
				name = ++ptr;
				while(*ptr && *ptr != '"') ptr++;
			} else {
				name = ptr;
				while(*ptr && *ptr != ' ' && *ptr != '\t') {
					ptr++;
				}
			}
			if(*ptr) *ptr++ = 0;
			loadaddr = strtol(ptr, &ptr, 16);
			while(*ptr == ' ' || *ptr == '\t') ptr++;
			if(*ptr == '!') {
				bang = 1;
				ptr++;
			} else {
				bang = 0;
			}
			offset = strtol(ptr, &ptr, 16);
			length = strtol(ptr, &ptr, 16);
			while(*ptr == ' ' || *ptr == '\t') ptr++;
			if(*ptr) {
				errx(
					1,
					"Unexpected characters at end "
					"of script line (%s).",
					ptr);
			}

			if(loadaddr < 0 || loadaddr > 0xffff) {
				errx(1, "Invalid load address ($%lx)", loadaddr);
			}
			if(length < 0 || length > 0xffff) {
				errx(1, "Invalid load length ($%lx)", length);
			}
			if(offset < 0) {
				errx(1, "Invalid load offset ($%lx)", offset);
			}

			if(newgroup) {
				group = malloc(sizeof(struct group));
				cdest = &group->chunk;
				*gdest = group;
				gdest = &group->next;
				newgroup = 0;
			}

			if(length == 0) length = 0xffff;

			chunk = calloc(1, sizeof(struct chunk));
			chunk->data = malloc(length);
			cf = fopen(name, "rb");
			if(!cf) err(1, "fopen: %s", name);
			if(fseek(cf, offset, SEEK_SET) < 0) {
				err(1, "fseek: %s, $%lx", name, offset);
			}
			if(!loadaddr) {
				loadaddr = fgetc(cf);
				loadaddr |= fgetc(cf) << 8;
				if(loadaddr < 0 || loadaddr >= 0xffff) {
					errx(
						1,
						"Error obtaining load "
						"address from file: %s",
						name);
				}
			}
			length = fread(chunk->data, 1, length, cf);
			if(!length) err(1, "fread: %s", name);
			fclose(cf);
			if(firstchunk) {
				if(entry < 0) entry = loadaddr;
				firstchunk = 0;
			}
			chunk->loadaddr = loadaddr;
			chunk->size = length;
			snprintf(chunk->name, sizeof(chunk->name), "%s", name);
			chunk->under_io =
				(!bang) &&
				(chunk->loadaddr < 0xe000) &&
				((chunk->loadaddr + chunk->size) > 0xd000);
			*cdest = chunk;
			cdest = &chunk->next;
		}
	}
	*gdest = 0;

	if(!script) errx(1, "Empty script!");

	fclose(f);

	return (uint16_t) entry;
}

void dump_script(uint16_t jaddr) {
	struct group *g;
	struct chunk *c;
	int ncall = 0;
	int i;

	for(g = script; g; g = g->next) {
		if(!ncall) {
			fprintf(
				stderr,
				"At startup (with entry at $%04x):\n",
				jaddr);
		} else {
			fprintf(stderr, "Loader call #%d:\n", ncall);
		}
		for(c = g->chunk; c; c = c->next) {
			fprintf(
				stderr,
				" * $%04x-$%04x (",
				c->loadaddr,
				c->loadaddr + c->size - 1);
			for(i = 0; i < 8 && i < c->size; i++) {
				if(i) fprintf(stderr, " ");
				fprintf(stderr, "%02x", c->data[i]);
			}
			if(i < c->size) fprintf(stderr, " ...");
			fprintf(stderr, ") from \"%s\"", c->name);
			if(c->under_io) {
				fprintf(stderr, " (into shadow RAM)");
			}
			fprintf(stderr, "\n");
		}
		ncall++;
	}
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
	exit(1);
}

int main(int argc, char **argv) {
	struct option longopts[] = {
		{"help", 0, 0, 'h'},
		{"version", 0, 0, 'V'},
		{"verbose", 0, 0, 'v'},
		{"output", 1, 0, 'o'},
		{"dirart", 1, 0, 'a'},
		{"dir-entry", 1, 0, 'd'},
		{"entry", 1, 0, 'e'},
		{"title", 1, 0, 't'},
		{"my-magic", 1, 0, 'm'},
		{"next-magic", 1, 0, 'n'},
		{0, 0, 0, 0}
	};
	char *outname = "disk.d64", *dirart_fname = 0;
	uint8_t dirart[DIRARTBLOCKS * 8 * 16];
	int opt, dir_entry = 0;
	long int entry = -1;
	char *disk_title = "SPINDLE DISK", *disk_id = "uk";
	uint16_t jumpaddr;
	struct blockfile bf;
	struct group *g;
	int first;
	uint32_t my_magic = 0x4c4654, next_magic = 0;

	do {
		opt = getopt_long(
			argc,
			argv,
			"?hVvo:a:d:e:t:m:n:",
			longopts,
			0);
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
			case 'o':
				outname = strdup(optarg);
				break;
			case 'a':
				dirart_fname = strdup(optarg);
				break;
			case 'd':
				dir_entry = strtol(optarg, 0, 10);
				break;
			case 'e':
				entry = strtol(optarg, 0, 16);
				if(entry < 0 || entry > 0xffff) {
					errx(
						1,
						"Invalid entry point ($%lx)",
						entry);
				}
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

	jumpaddr = load_script(argv[optind], entry);
	make_dirart(dirart, dirart_fname);

	disk_init(disk_title, disk_id);
	disk_storeloader(
		&bf,
		dirart,
		dir_entry,
		my_magic,
		next_magic);

	first = 1;
	for(g = script; g; g = g->next) {
		compress_group(g->chunk, &bf, first? jumpaddr : 0);
		first = 0;
	}
	disk_closeside(&bf, !next_magic);

	if(verbose) dump_script(jumpaddr);

	disk_write(outname);

	report_histogram();

	return 0;
}
