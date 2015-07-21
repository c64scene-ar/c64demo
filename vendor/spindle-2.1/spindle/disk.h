/* Spindle by lft, http://www.linusakesson.net/software/spindle/
 */

extern int verbose;

#define NTRACK 35
#define NSECTOR 683
#define INTERLEAVE 5

#define DIRARTBLOCKS 6

struct blockfile {
	int		currtr;
	int		currse;
	uint8_t		*chainptr;
	uint8_t		*nextptr;
};

void disk_init(char *name, char *id);
void disk_storeloader(
	struct blockfile *bf,
	uint8_t *dirart,
	int active_dentry,
	uint32_t my_magic,
	uint32_t next_magic);
void disk_allocblock(
	struct blockfile *bf,
	int newgroup,
	int hint_new_bunch,
	uint8_t **dataptr,
	int *blockpos);
void disk_closeside(struct blockfile *bf, int last);
void disk_write(char *filename);
