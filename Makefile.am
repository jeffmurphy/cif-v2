SUBDIRS = libcif libcif-dbi router smrt ui protocol db
EXTRA_DIST = sbin

ME=cif-v2
BUILD=2.0
SNAPSHOT=$(ME)-$(BUILD)

all: 

fixperms:
	chmod 0755 $(prefix)
	chown -R $(CIF_USER) $(prefix)
	chgrp -R $(CIF_GROUP) $(prefix)

install: files-install fixperms

files-install: libcif-install libcif-dbi-install router-install smrt-install db-install ui-install protocol-install

libcif-install: protocol-install
	-( cd libcif && make install )

libcif-dbi-install: protocol-install
	-( cd libcif-dbi && make install )

purgedb:
	-( cd db && make purgedb )

initdb-small:
	-( cd db && make initdb-small )

upgradedb:
	-( cd libcif-dbi && make upgradedb )

router-install: protocol-install
	-( cd router && make install )

smrt-install: protocol-install
	-( cd smrt && make install )

ui-install: protocol-install
	-( cd ui && make install )

db-install: protocol-install
	-(cd db && make install )

protocol-install:
	-( cd protocol && make install )

depends: fixdeps

fixdeps:
	@for dir in libcif libcif-dbi smrt; do \
		$(PERL) ./sbin/test-dependencies --verbose --install --prefix $(prefix) ; \
	done

testdeps:
	@for dir in libcif libcif-dbi smrt; do \
		$(PERL) ./sbin/test-dependencies --verbose --prefix $(prefix) ; \
	done

clean:
	@for dir in libcif libcif-dbi smrt ui router db ; do \
		(cd $$dir && make clean) \
	done
	rm -f *~

realclean: clean
	@for dir in libcif libcif-dbi smrt ui router db ; do \
		(cd $$dir && make realclean) \
	done
	rm -f Makefile.in config.*
	rm configure
	rm aclocal.m4
	rm -fr autom4te.cache
	rm Makefile

reconf:
	autoreconf -vf

snapshot:
	git archive --format=tar --prefix=$(BUILD)/ $(BUILD) | gzip > $(SNAPSHOT).tar.gz
