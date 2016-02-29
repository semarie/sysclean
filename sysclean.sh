#!/bin/sh
#
# $OpenBSD$
#
# Copyright (c) 2015-2016 Sebastien Marie <semarie@openbsd.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
PATH='/bin:/sbin:/usr/bin:/usr/sbin'

set -u

usage() {
	echo "usage: ${0##*/} -f [-ai]\n       ${0##*/} -p [-i]" >&2
	exit 1
}

sc_err() {
	local _exit
	_exit="${1}"; shift

	echo "${0##*/}: error: $@"

	sc_cleanup
	exit "${_exit}"
}

sc_cleanup() {
	rm -rf -- "${_WRKDIR}"
}

# generate FILELIST_EXPECTED: list of expected files on the system
sc_generate_expected() {
	[[ -e "${FILELIST_EXPECTED}" ]] && return

	local _dbs _keyword _path

	[[ -r '/usr/lib/locate/src.db' ]] && _dbs='/usr/lib/locate/src.db'
	[[ -r '/usr/X11R6/lib/locate/xorg.db' ]] && \
		_dbs="${_dbs}${_dbs:+:}/usr/X11R6/lib/locate/xorg.db"

	[[ -z "${_dbs}" ]] && sc_err 1 "no system locate database found"

	# base system
	locate -d "${_dbs}" '*' \
		| cut -d: -f2- \
		> "${FILELIST_EXPECTED}"

	# / directory is expected too
	echo / >> "${FILELIST_EXPECTED}"

	# packages files (outside LOCALBASE) are expected files
	PKG_DBDIR="${PKG_DBDIR}" pkg_info -qL \
		| grep -v -e '^/usr/local/' -e '^$' \
		>> "${FILELIST_EXPECTED}"

	# add packages files from @extra and @sample
	find "${PKG_DBDIR}" -name +CONTENTS -print0 \
		| xargs -0 grep -Fh \
			-e '@cwd ' \
			-e '@extra ' \
			-e '@sample ' \
		> "${FILELIST_EXPECTED_PKGDB}"

	while read _keyword _path; do
		# change _cwd
		if [[ "${_keyword}" = '@cwd' ]]; then
			_cwd="${_path}"
			continue
		fi

		if [[ "${_path#/}" = "${_path}" ]] ; then
			# _path is relative, prepend _cwd
			echo "${_cwd}/${_path%/}"
		else
			# _path is absolute
			echo "${_path%/}"
		fi
	done < "${FILELIST_EXPECTED_PKGDB}" >> "${FILELIST_EXPECTED}"

	sort -o "${FILELIST_EXPECTED}" "${FILELIST_EXPECTED}"
}

# generate FILELIST_ACTUAL: list of actual files on the system. It walks the
# whole filesystem except severals directories.
#
# use SHOW_IGNORED for additional directories to not walk.
sc_generate_actual() {
	[[ -e "${FILELIST_ACTUAL}" ]] && return

	local _i=0 _path _prune

	# build default list of files to _prune
	for _path in '/etc/hostname.*' '/etc/ssh/ssh_host_*' /boot /bsd \
		/bsd.mp /bsd.rd /bsd.sp /dev /etc/fstab \
		/etc/hosts /etc/iked/local.pub /etc/iked/private/local.key \
		/etc/isakmpd/local.pub /etc/isakmpd/private/local.key \
		/etc/myname /etc/pkg.conf /etc/random.seed /home /obsd /root \
		/tmp /usr/local /usr/obj /usr/ports /usr/src /usr/xenocara \
		/usr/xobj /var/backups /var/cache /var/cron /var/db /var/log \
		/var/mail /var/run /var/spool/smtpd /var/sysmerge /var/unbound \
		/var/www/htdocs /var/www/logs /var/www/run /var/www/tmp ; do

		_prune[${_i}]='-path'	; _i=$((_i + 1))
		_prune[${_i}]="${_path}"; _i=$((_i + 1))
		_prune[${_i}]='-prune'	; _i=$((_i + 1))
		_prune[${_i}]='-o'	; _i=$((_i + 1))
	done

	# add IGNORE_ACTUAL entries to _prune list
	if [ "${SHOW_IGNORED}" = "false" -a -r "${IGNORE_ACTUAL}" ]; then
		while read _path; do
			# stripcom
			_path="${_path%%#*}"
			[[ -z "${_path}" ]] && continue

			_prune[${_i}]='-path'	; _i=$((_i + 1))
			_prune[${_i}]="${_path}"; _i=$((_i + 1))
			_prune[${_i}]='-prune'	; _i=$((_i + 1))
			_prune[${_i}]='-o'	; _i=$((_i + 1))
		done < "${IGNORE_ACTUAL}"
	fi

	# system hierarchy without some directories
	find / "${_prune[@]}" -print | sort > "${FILELIST_ACTUAL}"
}

# generate FILELIST_ADDEDFILES: list of unexpected files.
#
# use SHOW_USEDLIBS for removing from the list, libraries that are currently in
# use by some installed packages.
sc_generate_addedfiles() {
	[[ -e "${FILELIST_ADDEDFILES}" ]] && return

	sc_generate_expected
	sc_generate_actual

	# extract added files
	comm -23 "${FILELIST_ACTUAL}" "${FILELIST_EXPECTED}" \
		> "${FILELIST_ADDEDFILES}"

	# remove used-libs from FILELIST_ADDEDFILES
	if [[ "${SHOW_USEDLIBS}" = "false" ]]; then
		sc_generate_oldlibs_used_pattern

		grep -vf "${FILELIST_OLDLIBS_USED_PATTERN}" \
			< "${FILELIST_ADDEDFILES}" \
			> "${FILELIST_ADDEDFILES}.tmp"
		mv "${FILELIST_ADDEDFILES}.tmp" "${FILELIST_ADDEDFILES}"
	fi
}

# generate FILELIST_OLDLIBS_DB: extract libraries from FILELIST_ADDEDFILES (so
# there are only libraries that are not "expected" to be present), and associate
# filename with the @wantlib form.
sc_generate_oldlibs_db() {
	[[ -e "${FILELIST_OLDLIBS_DB}" ]] && return

	sc_generate_addedfiles

	# format: foo.0.0	/some/path/libfoo.so.0.0
	sed -n 's,.*/lib\([^.][^.]*\)\.so\([0-9.][0-9.]*\),\1\2	&,p' \
		< "${FILELIST_ADDEDFILES}" \
		| sort -b \
		> "${FILELIST_OLDLIBS_DB}"
}

# generate FILELIST_OLDLIBS_PATTERN: a grep pattern file for searching
# FILELIST_OLDLIBS_DB inside /var/db/pkg.
sc_generate_oldlibs_pattern() {
	[[ -e "${FILELIST_OLDLIBS_PATTERN}" ]] && return

	sc_generate_oldlibs_db

	# format: ^@wantlib foo.0.0$
	sed -n 's/^\([^	]*\)	.*/^@wantlib \1$/p' \
		< "${FILELIST_OLDLIBS_DB}" \
		> "${FILELIST_OLDLIBS_PATTERN}"
}

# generate FILELIST_OLDLIBS_USED_DB: a database associating packagename and
# library (in wantlib format) of unexpected libraries.
sc_generate_oldlibs_used_db() {
	[[ -e "${FILELIST_OLDLIBS_USED_DB}" ]] && return

	sc_generate_oldlibs_pattern

	# format: packagename-1.0p2	foo.0.0
	( cd "${PKG_DBDIR}" && grep -Rf "${FILELIST_OLDLIBS_PATTERN}" . ) \
		| sed 's,^\./\([^/]*\)/.*@wantlib \(.*\)$,\2	\1,' \
		| sort -b \
		> "${FILELIST_OLDLIBS_USED_DB}"
}

# generate FILELIST_OLDLIBS_USED_PATTERN: a grep pattern file for searching
# filenames of unexpected libraries.
sc_generate_oldlibs_used_pattern() {
	[[ -e "${FILELIST_OLDLIBS_USED_PATTERN}" ]] && return

	sc_generate_oldlibs_db
	sc_generate_oldlibs_used_db

	# format: ^filename$
	join -t '	' -o 2.2 \
		"${FILELIST_OLDLIBS_USED_DB}" "${FILELIST_OLDLIBS_DB}" \
		| uniq \
		| sed -e 's/^/^/' -e 's/$/$/' \
		> "${FILELIST_OLDLIBS_USED_PATTERN}"
}

# show list of unexpected files.
# by default, don't show used-libs.
sc_mode_files() {
	sc_generate_addedfiles

	cat "${FILELIST_ADDEDFILES}"
}

# show list of libraries in use by packages.
sc_mode_packages() {
	sc_generate_oldlibs_used_db

	# format: filename	packagename
	join -t '	' -o 2.2,1.2 \
		"${FILELIST_OLDLIBS_USED_DB}" "${FILELIST_OLDLIBS_DB}"
}

# main
PKG_DBDIR="${PKG_DBDIR:-/var/db/pkg}"
IGNORE_ACTUAL='/etc/sysclean.ignore'

MODE=''
SHOW_USEDLIBS='false'
SHOW_IGNORED='false'

while getopts 'hfpai' arg; do
	case "${arg}" in
	f)	[[ -n "${MODE}" ]] && usage
		MODE='files'
		;;
	p)	[[ -n "${MODE}" ]] && usage
		MODE='packages'
		SHOW_USEDLIBS='true'
		;;
	a)	SHOW_USEDLIBS='true' ;;
	i)	SHOW_IGNORED='true' ;;
	*)	usage ;;
	esac
done
shift $(( OPTIND -1 ))
[[ $# -ne 0 ]] && usage
[[ -z "${MODE}" ]] && usage

[[ $(id -u) -ne 0 ]] && \
	echo 'warn: need root privileges for complete listing' >&2

_WRKDIR=$(mktemp -d /tmp/sysclean.XXXXXXXXXX) || exit 1
FILELIST_EXPECTED="${_WRKDIR}/expected"
FILELIST_EXPECTED_PKGDB="${_WRKDIR}/expected-pkgdb"
FILELIST_ACTUAL="${_WRKDIR}/actual"
FILELIST_ADDEDFILES="${_WRKDIR}/added"
FILELIST_OLDLIBS_DB="${_WRKDIR}/oldlibs-db"
FILELIST_OLDLIBS_PATTERN="${_WRKDIR}/oldlibs-pattern"
FILELIST_OLDLIBS_USED_DB="${_WRKDIR}/oldlibs-used-db"
FILELIST_OLDLIBS_USED_PATTERN="${_WRKDIR}/oldlibs-used-pattern"
readonly _WRKDIR FILELIST_EXPECTED FILELIST_EXPECTED_PKGDB FILELIST_ACTUAL \
	FILELIST_ADDEDFILES FILELIST_OLDLIBS_DB FILELIST_OLDLIBS_PATTERN \
	FILELIST_OLDLIBS_USED_DB FILELIST_OLDLIBS_USED_PATTERN

trap 'sc_cleanup; exit 1' 0 1 2 3 13 15

case "${MODE}" in
'files' )	sc_mode_files ;;
'packages' )	sc_mode_packages ;;
esac

sc_cleanup
exit 0
