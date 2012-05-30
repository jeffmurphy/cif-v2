EXTRA_DIST = lib sbin

ME=cif-protocol
BUILD=@BUILD@
TARGETS=@TARGETS@
SNAPSHOT=$(ME)-$(BUILD)


SUBDIRS=src

all-am:

clean:
	rm Makefile
	rm config.log
	rm config.status
	rm -fr build
	
realclean: clean
	rm Makefile.in
	rm configure
	rm aclocal.m4

reconf:
	autoreconf -vf

snapshot:
	git archive --format=tar --prefix=$(BUILD)/ $(BUILD) | gzip > $(SNAPSHOT).tar.gz
