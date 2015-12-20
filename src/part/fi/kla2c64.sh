#!/bin/bash
FILENAME=$1
echo "Processing $FILENAME"

# .kla file already contains the load address for the bitmap
dd if=$1 of=mc.c64 bs=1 count=8002

# put the screen matrix at $4000
dd if=$1 of=tmp.c64 bs=1 skip=8002 count=1000
echo -n -e '\x00\x40' | cat - tmp.c64 > mc-v.c64

# put the color matrix at $8000
dd if=$1 of=tmp.c64 bs=1 skip=9002 count=1000
echo -n -e '\x00\x80' | cat - tmp.c64 > mc-c.c64

rm -f tmp.c64
