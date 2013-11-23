make realclean
for i in libcif libcif-dbi smrt router db ui ; do
	cd $i
	automake --copy --add-missing
	autoreconf -vf
	chmod 755 configure
	cd ..
done

automake --copy --add-missing
autoreconf -vf
chmod 755 configure
./configure
