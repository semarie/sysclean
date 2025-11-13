SYSCLEAN(8) - System Manager's Manual

# NAME

**sysclean** - list obsolete elements between OpenBSD upgrades

# SYNOPSIS

**sysclean**
[**-a** | **-p**]
[**-i**]

# DESCRIPTION

**sysclean**
is a
perl(1)
script designed to help remove obsolete files, users and groups, between
OpenBSD
upgrades.

**sysclean**
compares a reference installation against the currently installed elements,
taking files from both the base system and packages into account.

**sysclean**
is a read-only tool.
It does not remove anything on the system.

By default,
**sysclean**
lists obsolete filenames, users and groups on the system.
It excludes any used dynamic libraries.
It will report base libraries with versions newer than what's expected.

The options are as follows:

**-a**

> All files mode.
> **sysclean**
> will not exclude filenames used by installed packages from output.

**-i**

> With ignored.
> **sysclean**
> will include filenames that are ignored by default, using
> */etc/sysclean.ignore*.

**-p**

> Package mode.
> **sysclean**
> will output package names that are using obsolete files.

# ENVIRONMENT

`PKG_DBDIR`

> The standard package database directory,
> */var/db/pkg*,
> can be overridden by specifying an alternative directory in the
> `PKG_DBDIR`
> environment variable.

# FILES

*/etc/sysclean.ignore*

> Files to ignore, one per line, with absolute pathnames.

> A line starting with
> '@user'
> or
> '@group'
> will be interpreted as user or group to ignore.

> Shell globbing is supported in pathnames; see
> File::Glob(3p).
> If the pattern matches a directory,
> **sysclean**
> will not inspect it or any files contained within.
> For compatibility with the
> changelist(5)
> file format, the character
> '+'
> is skipped at the beginning of a line.

> */etc/changelist*
> is implictly included.

# EXAMPLES

Obtain a list of outdated files (without libraries used by packages):

	# sysclean
	/usr/lib/libc.so.83.0

Obtain a list of old libraries and the package using them:

	# sysclean -p
	/usr/lib/libc.so.84.1   git-2.7.0
	/usr/lib/libc.so.84.1   gmake-4.1p0

Obtain a list of all outdated files (including used libraries):

	# sysclean -a
	/usr/lib/libc.so.83.0
	/usr/lib/libc.so.84.1

Obtain a list of users and groups that can safely be removed
(from ports or base):

	# sysclean
	@user _mpd:560:_mpd::/var/spool/mpd:/sbin/nologin
	@group _mpd:560

# SEE ALSO

pkg\_info(1),
sysmerge(8)

# HISTORY

The first version of
**sysclean**
was written as
ksh(1)
script in 2015, and rewritten using
perl(1)
in 2016.

# AUTHORS

**sysclean**
was written by
Sebastien Marie <[semarie@kapouay.eu.org](mailto:semarie@kapouay.eu.org)>.

OpenBSD 7.8 - March 10, 2024 - SYSCLEAN(8)
