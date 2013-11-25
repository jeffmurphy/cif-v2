#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.63])
AC_INIT(cif-v1, [2.0], [ci-framework@googlegroups.com])
AM_INIT_AUTOMAKE

# setup


# Checks for programs.
AC_ARG_VAR([PERL],[Perl interpreter command])
AC_PATH_PROG([PERL], [perl], [not found])
if test "$PERL" = 'not found'; then
    AC_MSG_ERROR([cannot use $PACKAGE_NAME without perl])
fi

# Checks for programs.
AC_ARG_VAR([PYTHON],[Python interpreter command])
AC_PATH_PROG([PYTHON], [python], [not found])
if test "$PYTHON" = 'not found'; then
    AC_MSG_ERROR([cannot use $PACKAGE_NAME without python])
fi

dnl Defaults paths for installation
AC_PREFIX_DEFAULT([/opt/cif])

# Checks for libraries.

# Checks for header files.

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.

#dnl CIF_USER
AC_ARG_WITH(user,
    AC_HELP_STRING([--with-user=USER],
        [user the cif scripts will run as (default: cif)]),
    CIF_USER=$withval,
    CIF_USER=cif)
AC_SUBST(CIF_USER)

#dnl CIF_GROUP
AC_ARG_WITH(group,
    AC_HELP_STRING([--with-group=GROUP],
        [group the cif scripts will run as (default: cif)]),
    CIF_GROUP=$withval,
    CIF_GROUP=$CIF_USER
)
AC_SUBST(CIF_GROUP)

dnl DB_TYPE
AC_ARG_WITH(db-type,
        AC_HELP_STRING([--with-db-type=TYPE],
                   [sort of database CIF will use (default: HBase) (HBase DynamoDB)]),
            DB_TYPE=$withval,
            DB_TYPE='HBase')
if test "$DB_TYPE" != 'HBase' -a "$DB_TYPE" != 'DynamoDB' ; then
    AC_MSG_ERROR([valid db type: HBase or DynamoDB])
fi
AC_SUBST(DB_TYPE)

dnl DB_HOST
AC_ARG_WITH(db-host,
        AC_HELP_STRING([--with-db-host=HOSTNAME],
                   [FQDN or IP of database server (default: localhost)]),
            DB_HOST=$withval,
            DB_HOST=localhost)
AC_SUBST(DB_HOST)

dnl DB_PORT
AC_ARG_WITH(db-port,
        AC_HELP_STRING([--with-db-port=PORT],
                   [port on which the database listens on (default: 5432]),
            DB_PORT=$withval,
            DB_PORT=5432)
AC_SUBST(DB_PORT)

AC_CONFIG_FILES([Makefile libcif/Makefile libcif-dbi/Makefile router/Makefile smrt/Makefile ui/Makefile protocol/Makefile db/Makefile])
AC_OUTPUT
