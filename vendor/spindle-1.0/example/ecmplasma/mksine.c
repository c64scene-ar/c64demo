// This is an example effect bundled with Spindle
// http://www.linusakesson.net/software/spindle/

#include <stdio.h>
#include <stdint.h>
#include <math.h>

int main() {
	int i, ch;

	for(i = 0; i < 256; i++) {
		ch = 127 * sin(i * M_PI * 2 / 256);
		fputc(ch & 255, stdout);
	}

	return 0;
}
