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

struct header header;

struct chunk {
	uint16_t	loadaddr;
	uint16_t	size;
	uint8_t		*data;
	char		filename[32];
} chunk[MAXCHUNKS];

void add_chunk(FILE *f, int loadsize, char *filename) {
	struct chunk *c;
	int i;

	if(header.nchunk >= MAXCHUNKS) {
		errx(1, "Too many files. (Max %d)", MAXCHUNKS);
	}
	c = &chunk[header.nchunk];
	c->loadaddr = fgetc(f);
	c->loadaddr |= fgetc(f) << 8;
	loadsize -= 2;
	c->size = loadsize;
	c->data = malloc(loadsize);
	fread(c->data, loadsize, 1, f);
	for(i = c->loadaddr >> 8; i <= (c->loadaddr + loadsize - 1) >> 8; i++) {
		header.pageflags[i] |= PF_LOADED | PF_USED;
		header.chunkmap[i] = header.nchunk;
	}
	snprintf(c->filename, sizeof(c->filename), "%s", filename);
	header.nchunk++;
}

void get_range(FILE *f, int tag, char *filename, int *loadsize, int flag) {
	int first, last, i;

	first = fgetc(f);
	last = fgetc(f);
	*loadsize -= 2;
	if(first < 0 || first > 255 || last < 0 || last > 255 || last < first) {
		errx(1, "Bad range in '%c' tag in %s", tag, filename);
	}
	for(i = first; i <= last; i++) header.pageflags[i] |= flag;
}

void load_efo(char *fname) {
	FILE *f;
	struct stat sb;
	int loadsize, tag;

	f = fopen(fname, "rb");
	if(!f) err(1, "fopen: %s", fname);

	if(fstat(fileno(f), &sb)) err(1, "fstat: %s", fname);
	loadsize = (int) sb.st_size - sizeof(header.efo);

	fread(&header.efo, sizeof(header.efo), 1, f);
	if(strncmp((char *) header.efo.magic, "EFO2", 4)) {
		errx(1, "Wrong header magic: %s", fname);
	}

	for(;;) {
		tag = fgetc(f);
		loadsize--;
		if(tag == EOF || tag == 0) break;
		switch(tag) {
			case 'P':
				get_range(f, tag, fname, &loadsize, PF_USED);
				break;
			case 'Z':
				get_range(f, tag, fname, &loadsize, PF_ZPUSED);
				break;
			case 'I':
				get_range(f, tag, fname, &loadsize, PF_INHERIT);
				break;
			case 'S':
				header.flags |= EF_SAFE_IO;
				break;
			case 'U':
				header.flags |= EF_UNSAFE;
				break;
			case 'X':
				header.flags |= EF_DONT_LOAD;
				break;
			case 'M':
				header.installs_music[0] = fgetc(f);
				header.installs_music[1] = fgetc(f);
				loadsize -= 2;
				break;
			default:
				errx(1, "Invalid tag '%c' in %s", tag, fname);
		}
	}

	add_chunk(f, loadsize, fname);

	fclose(f);
}

void load_extra(char *filename) {
	FILE *f;
	struct stat sb;
	int filesize;

	f = fopen(filename, "rb");
	if(!f) err(1, "fopen: %s", filename);

	if(fstat(fileno(f), &sb)) err(1, "fstat: %s", filename);
	filesize = (int) sb.st_size;

	add_chunk(f, filesize, filename);

	fclose(f);
}

void save_pef(char *filename) {
	FILE *f;
	struct chunk *c;
	int i;

	f = fopen(filename, "wb");
	if(!f) err(1, "fopen: %s", filename);

	header.magic[0] = 'P';
	header.magic[1] = 'E';
	header.magic[2] = 'F';
	header.magic[3] = '3';

	fwrite(&header, sizeof(header), 1, f);
	for(i = 0; i < header.nchunk; i++) {
		c = &chunk[i];
		fputc(c->size & 255, f);
		fputc(c->size >> 8, f);
		fputc(c->loadaddr & 255, f);
		fputc(c->loadaddr >> 8, f);
		fwrite(c->filename, 32, 1, f);
		fwrite(c->data, c->size, 1, f);
	}

	fclose(f);
}

void usage(char *prgname) {
	fprintf(stderr, "%s\n\n", SPINDLE_VERSION);
	fprintf(stderr,
		"Usage: %s [-o out.pef] effect.efo [additional-file.prg ...]\n",
		prgname);
	exit(1);
}

int main(int argc, char **argv) {
	int opt, i;
	struct option longopts[] = {
		{"help", 0, 0, 'h'},
		{"version", 0, 0, 'V'},
		{"output", 1, 0, 'o'},
		{0, 0, 0, 0}
	};
	char *outname = "effect.pef";

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

	if(argc == optind) usage(argv[0]);
	argc -= optind;
	argv += optind;

	load_efo(argv[0]);
	for(i = 1; i < argc; i++) load_extra(argv[i]);

	if(header.installs_music[0] || header.installs_music[1]) {
		for(i = 0; i < 256; i++) {
			if((header.pageflags[i] & PF_LOADED)
			&& header.chunkmap[i]) {
				header.pageflags[i] |= PF_MUSIC;
			}
		}
	}

	save_pef(outname);

	return 0;
}
