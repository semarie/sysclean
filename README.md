
# NAME
     sysclean - help removing obsoletes files between upgrades

# SYNOPSIS
     sysclean -f [-ai]
     sysclean -p [-i]

# DESCRIPTION
     sysclean is a ksh(1) script designed to the administrator to help
     removing obsoletes files between upgrades.

     sysclean works by comparing a reference root directory against currently
     installed files.  It considers standard system files, configuration files
     installed by default, and packages files.

     sysclean doesn't remove any files on the system. It only reports
     obsoletes filenames or packages using obsoletes libraries.

     The options are as follows:

     -f      Filename mode.  sysclean will output obsoletes filenames present
             on the system. By default, it doesn't show filenames used by
             installed packages.

     -p      Package mode.  sysclean will output packages names using
             obsoletes files.

     -a      All files.  sysclean will not exclude filenames used by installed
             packages from output.

     -i      With ignored.  sysclean will not exclude filenames normally
             ignored using /etc/sysclean.ignore.

# ENVIRONMENT
     PKG_DBDIR  The standard package database directory, /var/db/pkg, can be
                overridden by specifying an alternative directory in the
                PKG_DBDIR environment variable.

# FILES
     /etc/sysclean.ignore  Patterns to ignore from output. One per line. The
                           pattern format is the same as find(1) -path option.

# EXAMPLES
     Obtain the list of outdated files (without used libraries from ports):

           # sysclean -f
           /usr/lib/libc.so.83.0

     Obtain the list of old libraries with package using it:

           # sysclean -p
           /usr/lib/libc.so.84.1   git-2.7.0
           /usr/lib/libc.so.84.1   gmake-4.1p0

     Obtain the list of all outdated files (including used libraries):

           # sysclean -fa
           /usr/lib/libc.so.83.0
           /usr/lib/libc.so.84.1

# SEE ALSO
     find(1), pkg_info(1), sysmerge(1)

# HISTORY
     The first version of sysclean was written in 2015.

# AUTHORS
     sysclean was written by Sebastien Marie <semarie@openbsd.org>.

# CAVEATS
     sysclean relies on pkg_info(1) for obtaining the list of installed files
     from packages.  This list doesn't contains directories entries resulting
     possible false-positives.

