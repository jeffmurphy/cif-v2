docdir = doc

fixperms:
	chmod 0755 $(prefix)
	chmod 0755 $(prefix)/bin
	chown -R $(CIF_USER) $(prefix)
	chgrp -R $(CIF_GROUP) $(prefix)

install:
	-mkdir -p ${prefix}/bin
	-echo Installing CIF Router to ${prefix}/bin
	[ -d $(bindir) ] || $(INSTALL) -m 0755 -d $(bindir)
	[ -d $(bindir)/CIFRouter ] || $(INSTALL) -m 0755 -d $(bindir)/CIFRouter
	$(INSTALL) -m 0755 "poc/cif-router.py" "$(bindir)/cif-router.py"
	$(INSTALL) -m 0755 "poc/CIFRouter/__init__.py" "$(bindir)/CIFRouter/__init__.py"
	$(INSTALL) -m 0755 "poc/CIFRouter/MiniClient.py" "$(bindir)/CIFRouter/MiniClient.py"
	$(INSTALL) -m 0755 "poc/CIFRouter/PubSubMgr.py" "$(bindir)/CIFRouter/PubSubMgr.py"

clean-local:
	rm -f *~

realclean: clean-local
	rm Makefile.in
	rm Makefile
