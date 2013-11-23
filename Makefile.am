SUBDIRS = libcif libcif-dbi router smrt ui protocol
EXTRA_DIST = sbin

ME=cif-v2
BUILD=$(shell git describe --tags)
SNAPSHOT=$(ME)-$(BUILD)

all: default

default:
        $(PERL) libcif/sbin/gen_protocol_bindings.pl

fixperms:
        chmod 0755 $(prefix)
        chown -R $(CIF_USER) $(prefix)
        chgrp -R $(CIF_GROUP) $(prefix)

install: files-install fixperms

files-install: libcif-install libcif-dbi-install cif-router-install cif-smrt-install

libcif-install:
        -( cd libcif && make install )

libcif-dbi-install:
        -( cd libcif-dbi && make install )

purgedb:
        -( cd db && make purgedb )

initdb:
        -( cd db && make initdb )

upgradedb:
        -( cd libcif-dbi && make upgradedb )

router-install:
        -( cd router && make install )

smrt-install:
        -( cd smrt && make install )

ui-install:
	-( cd ui && make install )

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
        rm Makefile
        rm config.log
        rm config.status

realclean:
        clean
        rm Makefile.in
        rm configure
        rm aclocal.m4

reconf:
        autoreconf -vf

snapshot:
        git archive --format=tar --prefix=$(BUILD)/ $(BUILD) | gzip > $(SNAPSHOT).tar.gz
