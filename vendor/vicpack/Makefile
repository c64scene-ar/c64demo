include Makefile.config

COMPFLAGS= $(COMPFLAGS_CAMLIMAGES)
LINKFLAGS= $(COMPFLAGS) $(LINKFLAGS_CAMLIMAGES) unix.cmxa str.cmxa extLib.cmxa

all: opt

SRCS= asm6510.ml spriteoverlays.ml vicpack.ml 

byt: vicpack.byt

vicpack.byt: $(SRCS:.ml=.cmo)
	$(CAMLC) -o vicpack.byt enum.cmo bitset.cmo $(DLLPATHS) $(LINKFLAGS) $(SRCS:.ml=.cmo)

opt: vicpack

vicpack: $(SRCS:.ml=.cmx) 
	$(CAMLOPT) -o vicpack $(LINKFLAGS:.cma=.cmxa) $(SRCS:.ml=.cmx)

clean::
	rm -f vicpack vicpack.byt

vicpack-w32: vicpack
	mkdir vicpack-w32
	cp ~/bin/acme.exe vicpack-w32
	cp vicpack.exe vicpack-w32
	cp /usr/X11R6/bin/cygX11-6.dll vicpack-w32
	cp /usr/bin/cygwin1.dll vicpack-w32
	cp /usr/bin/cygjpeg-62.dll vicpack-w32
	cp /usr/bin/cygpng12.dll vicpack-w32
	cp /usr/bin/cygz.dll vicpack-w32
	cp /usr/bin/cygtiff-5.dll vicpack-w32
	zip -r vicpack-w32.zip vicpack-w32
	rm -rf vicpack-w32

vicpack-osx: vicpack
	mkdir vicpack-osx
	cp ~/bin/acme vicpack-osx
	cp vicpack vicpack-osx
	tar cvzf vicpack-osx.tgz vicpack-osx
	rm -rf vicpack-osx

examples.zip: examples/*.png examples/Makefile
	rm -f examples.zip
	zip examples.zip examples/*.png examples/Makefile examples/Credits.txt

.SUFFIXES:
.SUFFIXES: .ml .mli .cmo .cmi .cmx .mll .mly

.ml.cmo:
	$(CAMLC) -c $(COMPFLAGS) $<

.mli.cmi:
	$(CAMLC) -c $(COMPFLAGS) $<

.ml.cmx:
	$(CAMLOPT) -c $(COMPFLAGS) $<

.mll.cmo:
	$(CAMLLEX) $<
	$(CAMLC) -c $(COMPFLAGS) $*.ml

.mll.cmx:
	$(CAMLLEX) $<
	$(CAMLOPT) -c $(COMPFLAGS) $*.ml

.mly.cmo:
	$(CAMLYACC) $<
	$(CAMLC) -c $(COMPFLAGS) $*.mli
	$(CAMLC) -c $(COMPFLAGS) $*.ml

.mly.cmx:
	$(CAMLYACC) $<
	$(CAMLOPT) -c $(COMPFLAGS) $*.mli
	$(CAMLOPT) -c $(COMPFLAGS) $*.ml

.mly.cmi:
	$(CAMLYACC) $<
	$(CAMLC) -c $(COMPFLAGS) $*.mli

.mll.ml:
	$(CAMLLEX) $<

.mly.ml:
	$(CAMLYACC) $<

clean::
	rm -f *.cm[iox] *~ .*~ *.o *.s *.exe *.zip *.tgz

