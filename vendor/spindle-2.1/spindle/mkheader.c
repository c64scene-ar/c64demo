#include <err.h>
#include <stdio.h>
#include <string.h>

void visit(char *fname) {
	FILE *f;
	char buf[512], *ptr;
	int ch, x = 0;

	f = fopen(fname, "rb");
	if(!f) err(1, "%s", fname);

	snprintf(buf, sizeof(buf), "%s", fname);
	ptr = buf;
	while(strchr(ptr, '/')) {
		ptr = strchr(ptr, '/') + 1;
	}
	if(strchr(ptr, '.')) {
		*strchr(ptr, '.') = 0;
	}

	printf("uint8_t data_%s[] = {", ptr);
	while((ch = fgetc(f)) != EOF) {
		if(x == 0) {
			printf("\n\t");
		} else {
			printf(" ");
		}
		printf("0x%02x,", ch);
		x = (x + 1) % 8;
	}
	printf("\n};\n");

	fclose(f);
}

int main(int argc, char **argv) {
	int i;

	for(i = 1; i < argc; i++) {
		visit(argv[i]);
	}

	return 0;
}
