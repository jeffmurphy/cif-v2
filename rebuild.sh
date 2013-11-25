make realclean
for i in libcif libcif-dbi smrt router db ui ; do
	echo '********* ' Rebuilding in $i
	cd $i
	automake --copy --add-missing
	aclocal
	autoreconf -vf
	chmod 755 configure
	cd ..
done

echo '********* ' Rebuilding top level

automake --copy --add-missing
aclocal
autoreconf -vf
chmod 755 configure
./configure
