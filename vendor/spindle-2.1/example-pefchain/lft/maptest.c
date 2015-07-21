// This is an example effect bundled with Spindle
// http://www.linusakesson.net/software/spindle/

#define _GNU_SOURCE

#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include <err.h>

#define WIDTH 160
#define HEIGHT 80

#define TEXTHI 0x3e
#define TEXTLO 0x3f

struct cell {
	uint8_t		bitmap[8][4];
	uint8_t		pal[3];
	uint8_t		ncol;
} cell[10][40];

uint8_t picture[HEIGHT][WIDTH];

uint8_t ram[0x10000];

int sample(double xx, double yy) {
	double xint, yint, d;
	int xsel, ysel;

	xx += 9 + 32;
	yy += 4;

	xx = modf(xx, &xint);
	yy = modf(yy, &yint);
	if(xx < 0) xx += 1;
	if(yy < 0) yy += 1;
	d = hypot(xx - .5, yy - .5);

	xsel = (int) floor(xint) & 31;
	ysel = (int) floor(yint);

	if(d < .36 && xsel < 19) {
		return ysel * 19 + xsel;
	} else {
		return 0;
	}
}

void encodecell(int cx, int cy, int frame) {
	int x, y, ncol = 0, sel, i;

	for(x = 0; x < 4; x++) {
		for(y = 0; y < 8; y++) {
			sel = picture[cy * 8 + y][cx * 4 + x];
			if(sel) {
				for(i = 0; i < ncol; i++) {
					if(cell[cy][cx].pal[i] == sel) {
						break;
					}
				}
				if(i == ncol) {
					if(ncol == 3) {
						fprintf(stderr,
							"Frame %d: Too many colours in cell %d, %d\n",
							frame,
							cx,
							cy);
						i = -1;
					} else {
						cell[cy][cx].pal[ncol++] = sel;
					}
				}
				cell[cy][cx].bitmap[y][x] = i + 1;
			} else {
				cell[cy][cx].bitmap[y][x] = 0;
			}
		}
	}
	cell[cy][cx].ncol = ncol;
}

void put_asm(uint16_t org, int *pos, uint8_t b) {
	if(*pos >= 0x1000) errx(1, "Code area full!");
	ram[org + *pos] = b;
	(*pos)++;
}

void put_lda(uint16_t org, int *pos, int sel) {
	put_asm(org, pos, 0xbd);	// lda abs,x
	put_asm(org, pos, sel);
	put_asm(org, pos, TEXTLO);
}

void put_ora(uint16_t org, int *pos, int sel) {
	put_asm(org, pos, 0x1d);	// ora abs,x
	put_asm(org, pos, sel);
	put_asm(org, pos, TEXTHI);
}

void put_sta(uint16_t org, int *pos, uint16_t dest) {
	put_asm(org, pos, 0x8d);	// sta abs
	put_asm(org, pos, dest & 255);
	put_asm(org, pos, dest >> 8);
}

int main() {
	int x, y, xx, yy, bits, i;
	FILE *f;
	char buf[64];
	int frame;
	uint16_t vm, bm, code;
	int codepos;
	int swapbits[4] = {0, 2, 1, 3};

	for(frame = 0; frame < 6; frame++) {
		for(y = 0; y < HEIGHT; y++) {
			for(x = 0; x < WIDTH; x++) {
				double xx, yy, r, ang, amp;
				xx = ((double) x - WIDTH / 2) / 8;
				yy = ((double) y - HEIGHT / 2) / 12;
				r = hypot(xx, yy);
				ang = atan2(yy, xx);
				amp = 1 - hypot(xx, yy * 4) * .09;
				if(amp < 0) amp = 0;
				r -= amp * 1.0 * sin(r);
				ang += amp * M_PI * .1;
				xx = r * cos(ang);
				yy = r * sin(ang);
				xx += .5;
				yy += (double) frame / 6;
				picture[y][x] = sample(xx, yy);
			}
		}

		for(y = 0; y < 10; y++) {
			for(x = 0; x < 40; x++) {
				encodecell(x, y, frame);
			}
		}

		if(frame >= 4) {
			bm = 0xc000 + (frame & 1) * 400 * 8;
			vm = 0xdc00 + (frame & 1) * 400;
			code = 0xe000 + (frame & 1) * 0x1000;
		} else {
			bm = 0x6000 + (frame / 2) * 0x4000 + (frame & 1) * 400 * 8;
			vm = 0x7c00 + (frame / 2) * 0x4000 + (frame & 1) * 400;
			code = 0x4000 + (frame / 2) * 0x4000 + (frame & 1) * 0x1000;
		}

		for(y = 0; y < 10; y++) {
			for(x = 0; x < 40; x++) {
				for(yy = 0; yy < 8; yy++) {
					bits = 0;
					for(xx = 0; xx < 4; xx++) {
						bits <<= 2;
						bits |= swapbits[cell[y][x].bitmap[yy][xx]];
					}
					ram[bm + (y * 40 + x) * 8 + yy] = bits;
				}
			}
		}

		codepos = 0;

		// Perform all writes to colour ram first
		for(y = 0; y < 10; y++) {
			for(x = 0; x < 40; x++) {
				struct cell *c = &cell[y][x];

				if(c->ncol == 3) {
					put_lda(code, &codepos, c->pal[2]);
					put_sta(code, &codepos, 0xd800 + (frame & 1) * 400 + y * 40 + x);
				}
			}
		}

		fprintf(stderr, "Frame %d: %d writes to colour ram\n", frame, codepos / 6);

		if(frame >= 4) {
			put_asm(code, &codepos, 0xc6);	// dec zp
			put_asm(code, &codepos, 0x01);
		}

		for(y = 0; y < 10; y++) {
			for(x = 0; x < 40; x++) {
				struct cell *c = &cell[y][x];

				put_lda(code, &codepos, c->pal[0]);
				if(c->ncol > 1) {
					put_ora(code, &codepos, c->pal[1]);
				}
				put_sta(code, &codepos, vm + y * 40 + x);
			}
		}

		if(frame >= 4) {
			put_asm(code, &codepos, 0xe6);	// inc zp
			put_asm(code, &codepos, 0x01);
		}

		put_asm(code, &codepos, 0x60);	// rts

		fprintf(stderr, "Frame %d: %d bytes of code\n", frame, codepos);

		snprintf(buf, sizeof(buf), "speedcode%d.bin", frame + 1);
		f = fopen(buf, "wb");
		fputc(code & 255, f);
		fputc(code >> 8, f);
		fwrite(ram + code, codepos, 1, f);
		fclose(f);

		snprintf(buf, sizeof(buf), "pic%d.ppm", frame + 1);
		f = fopen(buf, "wb");
		fprintf(f, "P6\n%d %d\n255\n", WIDTH * 2, HEIGHT);
		for(y = 0; y < HEIGHT; y++) {
			for(x = 0; x < WIDTH; x++) {
				uint8_t rgb[3];
				struct cell *c;
				int bits;

				c = &cell[y / 8][x / 4];
				bits = c->bitmap[y % 8][x % 4];
				rgb[0] = bits? c->pal[bits - 1] : 0;
				rgb[1] = rgb[0];
				rgb[2] = rgb[0];
				fwrite(rgb, 3, 1, f);
				fwrite(rgb, 3, 1, f);
			}
		}
		fclose(f);
	}

	for(i = 0; i < 3; i++) {
		uint16_t bmaddr[3] = {0x6000, 0xa000, 0xc000};

		snprintf(buf, sizeof(buf), "bitmap%d.bin", i + 1);
		f = fopen(buf, "wb");
		fputc(bmaddr[i] & 255, f);
		fputc(bmaddr[i] >> 8, f);
		fwrite(ram + bmaddr[i], 400 * 8 * 2, 1, f);
		fclose(f);
	}

	return 0;
}
