
# NAME
     sysclean - help removing obsolete files between upgrades

# SYNOPSIS
     sysclean [-s | -f | -a | -p] [-i]

# DESCRIPTION
     sysclean is a perl(1) script designed to help removing obsolete files
     between upgrades.

     sysclean works by comparing a reference root directory against currently
     installed files.  It considers standard system files, configuration files
     installed by default, and packages files.

     sysclean doesn't remove any files on the system.  It only reports
     obsolete filenames or packages using out-of-date libraries.

     The options are as follows:

     -s      Safe mode.  sysclean will output obsolete filenames present on
             the system.  It excludes any dynamic libraries and all files
             under /etc directory.  It is the default mode used.

     -f      File mode.  sysclean will showing additionnally old libraries
             that aren't used by any packages, and /etc will be inspected.
             Note that it will report on stderr libraries from base with
             better version than expected one.

     -a      All files mode.  sysclean will not exclude filenames used by
             installed packages from output.

     -p      Package mode.  sysclean will output packages names using obsolete
             files.

     -i      With ignored.  sysclean will not exclude filenames normally
             ignored using /etc/sysclean.ignore.

# ENVIRONMENT
     PKG_DBDIR  The standard package database directory, /var/db/pkg, can be
                overridden by specifying an alternative directory in the
                PKG_DBDIR environment variable.

# FILES
     /etc/sysclean.ignore  Each line of the file contains the name of a path
                           to ignore during filesystem walking, specified by
                           its absolute pathname, one per line.  Shell
                           globbing is supported in pathnames, see
                           File::Glob(3p) for syntax details.  If the pattern
                           matches a directory, sysclean will not explore it,
                           so all files behind will be ignored too.  For
                           compatibility with changelist(5) file format, the
                           character `+' is skipped at beginning of line.
                           Additional files can be included with the @include
                           keyword, for example:

                                 @include "/etc/changelist"

# EXAMPLES
     Obtain the list of outdated files (without used libraries from ports):

           # sysclean -f
           /usr/lib/libc.so.83.0

     Obtain the list of old libraries with package using it:

           # sysclean -p
           /usr/lib/libc.so.84.1   git-2.7.0
           /usr/lib/libc.so.84.1   gmake-4.1p0

     Obtain the list of all outdated files (including used libraries):

           # sysclean -a
           /usr/lib/libc.so.83.0
           /usr/lib/libc.so.84.1

# SEE ALSO
     pkg_info(1), sysmerge(8)

# HISTORY
     The first version of sysclean was written as ksh(1) script in 2015, and
     rewritten using perl(1) in 2016.

# AUTHORS
     sysclean was written by Sebastien Marie <semarie@online.fr>.

