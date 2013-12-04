EXTRA_DIST = lib bin sbin rules

all: default

default:
	@echo "Please read the README before beginning your installation."

install: files-install etc-install local-whitelist etc-link

files-install: libs-install bin-install

local-whitelist:
	[ -e $(prefix)/etc/whitelist_domains ] || touch "$(prefix)/etc/whitelist_domains"
	[ -e $(prefix)/etc/whitelist_infrastructure ] || touch "$(prefix)/etc/whitelist_infrastructure"
	[ -e $(prefix)/etc/whitelist_urls ] || touch "$(prefix)/etc/whitelist_urls"

etc-link:
	[ -d $(sysconfdir) ] || ln -sf $(prefix)/etc $(sysconfdir)
    
etc-install:
	[ -d $(sysconfdir) ] || $(INSTALL) -m 0755 -d $(sysconfdir)
	-( cd rules/etc && find . -type d -print ) | while read dir ; do \
    $(INSTALL) -m 0750 -d "$(sysconfdir)/$$dir" ; \
    done
	-( cd rules/etc && find . -type f -print ) | while read file ; do \
    $(INSTALL) -m 0640 "rules/etc/$$file" "$(sysconfdir)/$$file" ; \
    done
    
libs-install:
	[ -d $(libdir) ] || $(INSTALL) -m 0755 -d $(libdir)
	-( cd lib && find . -type d -print ) | while read dir ; do \
    $(INSTALL) -m 0755 -d "$(libdir)/$$dir" ; \
    done
	-( cd lib && find . -type f -print ) | while read file ; do \
    $(INSTALL) -m 0644 "lib/$$file" "$(libdir)/$$file" ; \
    done
    
bin-install:    
	[ -d $(bindir) ] || $(INSTALL) -m 0755 -d $(bindir)
	-( cd bin && find . -type f -print ) | while read file ; do \
        $(INSTALL) -m 0755 "bin/$$file" "$(bindir)/$$file" ; \
    done

clean:
	rm -f *~

realclean: clean
	rm Makefile.in
	rm Makefile

reconf:
	autoreconf -vf
