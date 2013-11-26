docdir = doc

fixperms:
	chmod 0755 $(prefix)
	chmod 0755 $(prefix)/bin
	chown -R $(CIF_USER) $(prefix)
	chgrp -R $(CIF_GROUP) $(prefix)

install: 
	-mkdir -p ${prefix}/bin
	-echo Installing CIF CLI to ${prefix}/bin
	[ -d $(bindir) ] || $(INSTALL) -m 0755 -d $(bindir)
	$(INSTALL) -m 0755 "src/cli.py" "$(bindir)/cli.py"

clean-local:
	rm -f *~

realclean: clean-local
	rm Makefile.in
	rm Makefile
