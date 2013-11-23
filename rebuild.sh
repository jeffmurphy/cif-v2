make clean
automake --copy --add-missing
autoreconf -vf
chmod 755 configure
./configure
