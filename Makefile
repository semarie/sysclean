#	$OpenBSD$

MAN=	sysclean.8

SCRIPT=	sysclean.sh

BINDIR?=	/usr/local/bin
MANDIR?=	/usr/local/man/man

realinstall:
	${INSTALL} ${INSTALL_COPY} -o ${BINOWN} -g ${BINGRP} -m ${BINMODE} \
		${.CURDIR}/${SCRIPT} ${DESTDIR}${BINDIR}/sysclean

README.md: sysclean.8
	mandoc -T ascii sysclean.8 | sed -e 's/.//g' -e '/^SYSCLEAN.*/d' -e '/^OpenBSD /d' -e 's/^\([A-Z]\)/# \1/' >$@

.include <bsd.prog.mk>
