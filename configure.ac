#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.63])
AC_INIT(cif-protocol, [Protocol Buffers/Thrift IDL files used across the CIF platform], [ci-framework@googlegroups.com])
AM_INIT_AUTOMAKE


AC_PROG_CXX
AC_PROG_CC
LANGS="C cpp"
AC_PATH_PROG([PERL], [perl], [no])
test "x$PERL" != "xno" && LANGS="$LANGS perl"
AC_PATH_PROG([PYTHON], [python], [no])
test "x$PYTHON" != "xno" && LANGS="$LANGS python"
AC_PATH_PROG([XSD2IDL], [xsd2idl], [no])
AC_CHECK_PROG([GIT], [git], [yes], [no])



min_thrift_version=0.8.0
min_protoc_version=2.4.1

# version minreq actualinstalled
#  return 0 if min <= actual
#         1 if min  > actual

function version {
	if test "x$1" != "x$2" ; then 
    	LOWEROFTWO=$(echo -e "$1\n$2" | sort --version-sort | head -1)
    	INSTALLEDVERSION=$2
    	test "x$LOWEROFTWO" != "x$INSTALLEDVERSION"
    	return $?
    else
    	return 0
    fi
}

BUILD=`date +%Y%M%d`
if test "x$GIT" = "xyes" ; then
	BUILD=`git describe --tags`
fi

# using the prebuilts is desireable because they may have been
# tweaked. you can say 'no' (and install xsd2idl) to rebuild them
# from the raw xsd files

AC_ARG_WITH([prebuilt-xsd2idl], [AS_HELP_STRING([--with-prebuilt-xsd2idl],
    [use prebuilt XSD based IDL files [default=yes]])],
    [with_prebuilt_xsd2idl=$withval],[with_prebuilt_xsd2idl=yes])
    
# if protoc isnt found, we won't generate those bindings

AC_PATH_PROG([PROTOC], [protoc], [no])
    if test "x$PROTOC" = 'xno'; then
        AC_MSG_WARN([protoc command not found, will not generate protocol buffer bindings])
    else
    	IDLTARGETS="pb"
    fi

# ditto

AC_PATH_PROG([THRIFT], [thrift], [no])
    if test "x$THRIFT" = 'xno'; then
        AC_MSG_WARN([thrift command not found, will not generate thrift bindings])
    else
    	IDLTARGETS="$IDLTARGETS thrift"
    fi

# if you said with-prebuilt-xsd2idl=no and we can't find xsd2idl to 
# recreate the prebuilts from the raw XSD.. then we fail.

for i in src/*.xsd ; do 
	i=`basename $i`
	XSDFILES="$XSDFILES $i"
done

if test "$with_prebuilt_xsd2idl" = "yes" ; then
	echo "Using prebuilts"
	TARGET_XSD2IDL="prebuilts"
else
	if test "$XSD2IDL" = 'no' ; then
	    AC_MSG_ERROR([you said --with-prebuilt-xsd2idl=no but I cant find xsd2idl])
		TARGET_XSD2IDL="prebuilts"
	else
		echo "Ignoring prebuilts and rebuilding from XSDs"
		TARGET_XSD2IDL=" "
	fi
fi

for lang in $LANGS ; do 
	for idl in $IDLTARGETS ; do 
		echo "Targeting $idl for $lang"
		TARGETS="$TARGETS ${idl}_${lang}"
	done
done

AC_CONFIG_FILES([
                 Makefile
                 src/Makefile
])


# Checks for versions.

if test "x$THRIFT" != "xno" ; then
	AC_MSG_CHECKING(for $THRIFT >= $min_thrift_version)
	THRIFT_VERSION=`$THRIFT -version | sed 's/Thrift version //'`
	AC_MSG_RESULT($THRIFT_VERSION)
	version $min_thrift_version $THRIFT_VERSION || AC_MSG_ERROR(thrift $min_thrift_version required)
fi

if test "x$PROTOC" != "xno" ; then
	AC_MSG_CHECKING(for $PROTOC >= $min_protoc_version)
	PROTOC_VERSION=`$PROTOC --version | sed 's/libprotoc //'`
	AC_MSG_RESULT($PROTOC_VERSION)
	version $min_protoc_version $PROTOC_VERSION || AC_MSG_ERROR(protoc $min_protoc_version required)
fi

# Checks for header files.

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.

AC_SUBST(TARGET_XSD2IDL)
AC_SUBST(XSDFILES)
AC_SUBST(XSD2IDL)
AC_SUBST(BUILD)
AC_SUBST(TARGETS)
AC_OUTPUT
