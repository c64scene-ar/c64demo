// efo header

.byt   "EFO2"    // fileformat magic
.word  0    // prepare routine
.word  setup    // setup routine
.word  interrupt  // irq handler
.word  main    // main routine
.word  0    // fadeout routine
.word  0    // cleanup routine
.word  0    // location of playroutine call

// tags go here

//.byt  "P",$04,$07  // range of pages in use
//.byt  "I",$10,$1f  // range of pages inherited
//.byt  "Z",$02,$03  // range of zero-page addresses in use
//.byt  "S"    // i/o safe
//.byt  "X"    // avoid loading
//.byt  "M",<play,>play  // install music playroutine

.byt  0

.word  loadaddr
