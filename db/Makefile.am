docdir = doc

initdb-small:
	src/install-hbase-small.sh

fixperms:
	chmod 0755 $(prefix)
	chmod 0755 $(prefix)/bin
	chown -R $(CIF_USER) $(prefix)
	chgrp -R $(CIF_GROUP) $(prefix)

install:
	-mkdir -p ${prefix}/bin
	-echo Installing CIF HBase DB Agent to ${prefix}/bin
	[ -d $(bindir) ] || $(INSTALL) -m 0755 -d $(bindir)
	[ -d $(bindir)/CIFRouter ] || $(INSTALL) -m 0755 -d $(bindir)/CIFRouter
	-( cd src && find . -type d -print ) | while read file ; do \
		$(INSTALL) -m 0755 -d  "$(bindir)/$$file" ; \
    	done
	-( cd src && find . -type f -name \*.py -print ) | while read file ; do \
		$(INSTALL) -m 0755 "src/$$file" "$(bindir)/$$file" ; \
	done

clean-local:
	rm -f *~

realclean: clean-local
	rm doc/hadoop/hdfs-site.xml
	rm Makefile.in
	rm Makefile
