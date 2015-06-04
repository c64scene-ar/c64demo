// Spindle by lft, http://www.linusakesson.net/software/spindle/

extern int verbose;

#define NTRACK 35
#define NSECTOR 683
#define DIRARTBLOCKS 6
#define INTERLEAVE 5

struct blockmap {
	int	currtr;
	int	currse;
	int	below_io;
	int	nblock;
	uint8_t	map[NTRACK][24];
};

struct filespec {
	uint8_t	ntrack;
	uint8_t	spec[35][4];
	uint8_t	below_io;	// 1 if file overlaps with i/o area.
};

void init_disk(char *name, char *id);
void seek_to_end(struct blockmap *bm);
void seek_to_middle(struct blockmap *bm, int first_sector_available);
void store_block(struct blockmap *blockmap, uint8_t *data);
void store_loader(struct filespec *fs, uint16_t jumpaddr, uint8_t *dirart, int active_dentry);
void write_disk(char *filename);

void compress(struct blockmap *bm, uint8_t *data, uint16_t loadsize, uint16_t loadaddr, char *fname);
