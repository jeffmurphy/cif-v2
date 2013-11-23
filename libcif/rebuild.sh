autoreconf -vf
automake --copy --add-missing
chmod 755 configure
./configure
make
make dist
