 // Declare our picture 
.var picture = LoadBinary("res/dcc.prg") 
// Bitmap load 
//.pc = $0c00 "Screen Ram" 
  //    .fill picture.getScreenRamSize(), picture.getScreenRam(i) 


.pc = $2000 - 2 "Bitmap Data" 
.fill picture.getSize(), picture.get(i)

// Upstart 
.pc = $0801 "Basic Upstart Program" 
:BasicUpstart($0810) 

// Main 
.pc = $0810 "Main Program" 

	lda $4710  // Background data
	sta $d020
	sta $d021
	ldx #$00
loaddccimage:
	lda $3f40,x // Charmem data (Scren ram)
	sta $0c00,x
	lda $4040,x
	sta $0d00,x
	lda $4140,x
	sta $0e00,x
	lda $4240,x
	sta $0f00,x

	lda $4328,x // Colormem data
	sta $d800,x
	lda $4428,x
	sta $d900,x
	lda $4528,x
	sta $da00,x
	lda $4628,x
	sta $db00,x
	inx

bne loaddccimage
	lda #$3b     // Hi-Res
	sta $d011
	lda #$18     // Multicolor
	sta $d016
	lda #$38     // Screen ram = 0x400, bitmap at 2000
	sta $d018

loop:
	jmp loop