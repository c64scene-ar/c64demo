// This is an example effect bundled with Spindle
// http://www.linusakesson.net/software/spindle/

#define _GNU_SOURCE
#include <stdio.h>
#include <math.h>

int main() {
	int i;

	printf("sine36\n");
	for(i = 0; i < 256; i++) {
		printf("\t\t.byt\t$%02x\n", (int) round(
			17.5 +
			17.5 * cos(i * M_PI * 2 * 1 / 256) +
			0 * sin(i * M_PI * 2 * 2 / 256)));
	}
	printf("sine256\n");
	for(i = 0; i < 256; i++) {
		printf("\t\t.byt\t$%02x\n", ((int) round(
			256 +
			127 * sin(i * M_PI * 2 * 2 / 256))) & 255);
	}

	return 0;
}
