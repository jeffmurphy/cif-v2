
ME=cif-protocol
BUILD=@BUILD@
TARGETS=@TARGETS@
SNAPSHOT=$(ME)-$(BUILD)
EXTRA_DIST=prebuilt

SUBDIRS=src

all-am:


reconf:
	autoreconf -vf

snapshot:
	git archive --format=tar --prefix=$(SNAPSHOT)/ $(SNAPSHOT) | gzip > ../$(SNAPSHOT).tar.gz
