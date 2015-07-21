/* Spindle by lft, http://www.linusakesson.net/software/spindle/
 */

struct chunk {
	struct chunk		*next;
	uint16_t		loadaddr;
	uint16_t		size;
	uint8_t			*data;
	char			name[64];
	int			under_io;

	/* The following fields are used by the cruncher. They
	 * should be initialised to zero before calling
	 * compress_group.
	 */

	struct arena		*arena;
	struct chaincache	**cache;
	struct chain		*chain;
	uint16_t		end;
	int			synced;
};

// The jumpaddr parameter must be zero for every group except the first.
void compress_group(struct chunk *ch, struct blockfile *bf, uint16_t jumpaddr);

void report_histogram();
