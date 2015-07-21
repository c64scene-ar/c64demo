// Effect-wide flags.
#define EF_SAFE_IO	0x01
#define EF_DONT_LOAD	0x02
#define EF_UNSAFE	0x04

// Used by pefchain internally.
#define EF_BLANK	0x80
#define EF_SCRIPTBLANK	0x40

// Page flags.
#define PF_LOADED	0x01
#define PF_USED		0x02
#define PF_ZPUSED	0x04
#define PF_INHERIT	0x08
#define PF_MUSIC	0x10

// Used by pefchain internally.
#define PF_RESIDENT	0x80
#define PF_RESERVED	0x100

#define MAXCHUNKS 32

struct efoheader {
	uint8_t		magic[4];
	uint8_t		v_prepare[2];
	uint8_t		v_setup[2];
	uint8_t		v_irq[2];
	uint8_t		v_main[2];
	uint8_t		v_fadeout[2];
	uint8_t		v_cleanup[2];
	uint8_t		v_jsr[2];
};

struct header {
	uint8_t			magic[4];
	uint8_t			flags;
	uint8_t			pageflags[256];
	uint8_t			chunkmap[256];
	struct efoheader	efo;
	uint8_t			installs_music[2];
	uint8_t			reserved[22];
	uint8_t			nchunk;
};
