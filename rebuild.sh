make realclean
aclocal
automake
autoreconf -vfi
chmod 755 configure
./configure
