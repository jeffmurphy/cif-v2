make realclean
automake --copy --add-missing
aclocal
autoreconf -vf
chmod 755 configure
./configure
