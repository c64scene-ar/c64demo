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
#include "pef.h"
#include "prgloader.h"

struct chunk {
	uint16_t	loadaddr;
	uint16_t	size;
	uint16_t	offset;
	uint8_t		*data;
	char		filename[32];
} chunk[MAXCHUNKS];

struct header header;

void load_pef(char *filename) {
	FILE *f;
	int i;
	struct chunk *c;

	f = fopen(filename, "rb");
	if(!f) err(1, "fopen: %s", filename);
	
	fread(&header, sizeof(header), 1, f);
	if(strncmp((char *) header.magic, "PEF3", 4)) {
		errx(1, "Invalid pef header: %s", filename);
	}

	for(i = 0; i < header.nchunk; i++) {
		c = &chunk[i];
		c->size = fgetc(f);
		c->size |= fgetc(f) << 8;
		c->data = malloc(c->size);
		c->loadaddr = fgetc(f);
		c->loadaddr |= fgetc(f) << 8;
		fread(c->filename, 32, 1, f);
		fread(c->data, c->size, 1, f);
	}

	fclose(f);

	for(i = 0x08; i <= 0x0f; i++) {
		if(header.pageflags[i] & (PF_LOADED | PF_USED)) {
			errx(1,
				"Effects using memory in the range $800-$fff "
				"are not supported by pef2prg. Use pefchain "
				"or spin.");
		}
	}
}

int cmp_chunk(const void *a, const void *b) {
	const struct chunk *aa = (const struct chunk *) a;
	const struct chunk *bb = (const struct chunk *) b;

	return aa->loadaddr - bb->loadaddr;
}

void put_word(uint16_t w, FILE *f) {
	fputc(w & 255, f);
	fputc(w >> 8, f);
}

void save_prg(char *filename) {
	FILE *f;
	uint16_t offs = sizeof(header.efo) + 6 * header.nchunk + 2;
	int i;

	for(i = 0; i < header.nchunk; i++) {
		chunk[i].offset = offs;
		offs += chunk[i].size;
	}

	f = fopen(filename, "wb");
	if(!f) err(1, "fopen: %s", filename);

	fwrite(data_prgloader, sizeof(data_prgloader), 1, f);
	fwrite(&header.efo, sizeof(header.efo), 1, f);
	for(i = header.nchunk - 1; i >= 0; i--) {
		put_word(chunk[i].size, f);
		put_word(chunk[i].offset + (chunk[i].size & 0xff00), f);
		put_word(chunk[i].loadaddr + (chunk[i].size & 0xff00), f);
	}
	put_word(0, f);
	for(i = 0; i < header.nchunk; i++) {
		fwrite(chunk[i].data, chunk[i].size, 1, f);
	}

	fclose(f);
}

void usage(char *prgname) {
	fprintf(stderr, "%s\n\n", SPINDLE_VERSION);
	fprintf(stderr, "Usage: %s [-o out.prg] effect.pef\n", prgname);
	exit(1);
}

int main(int argc, char **argv) {
	int opt;
	struct option longopts[] = {
		{"help", 0, 0, 'h'},
		{"version", 0, 0, 'V'},
		{"output", 1, 0, 'o'},
		{0, 0, 0, 0}
	};
	char *outname = "a.prg";

	do {
		opt = getopt_long(argc, argv, "?hVo:", longopts, 0);
		switch(opt) {
			case 0:
			case '?':
			case 'h':
				usage(argv[0]);
				break;
			case 'V':
				fprintf(stderr, "%s\n", SPINDLE_VERSION);
				return 0;
			case 'o':
				outname = strdup(optarg);
				break;
		}
	} while(opt >= 0);

	if(argc != optind + 1) usage(argv[0]);

	load_pef(argv[optind]);
	qsort(chunk, header.nchunk, sizeof(struct chunk), cmp_chunk);
	save_prg(outname);

	return 0;
}
