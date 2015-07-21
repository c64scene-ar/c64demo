#include <err.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void err(int eval, const char *fmt, ...) {
	va_list valist;

	va_start(valist, fmt);
	vfprintf(stderr, fmt, valist);
	fprintf(stderr, ": %s\n", strerror(errno));
	exit(eval);
}

void errx(int eval, const char *fmt, ...) {
	va_list valist;

	va_start(valist, fmt);
	vfprintf(stderr, fmt, valist);
	fprintf(stderr, "\n");
	exit(eval);
}
