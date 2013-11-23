
ME=cif-protocol
BUILD=@BUILD@
TARGETS=@TARGETS@
SNAPSHOT=$(ME)-$(BUILD)
EXTRA_DIST=prebuilt
PREFIX=@prefix@

SUBDIRS=src

all-am:


reconf:
	autoreconf -vf

clean:

realclean: clean

snapshot:
	git archive --format=tar --prefix=$(SNAPSHOT)/ $(SNAPSHOT) | gzip > ../$(SNAPSHOT).tar.gz
