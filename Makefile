#	$OpenBSD$

MAN=	sysclean.8

SCRIPT=	sysclean.pl

BINDIR?=	/usr/local/bin
MANDIR?=	/usr/local/man/man

realinstall:
	${INSTALL} ${INSTALL_COPY} -o ${BINOWN} -g ${BINGRP} -m ${BINMODE} \
		${.CURDIR}/${SCRIPT} ${DESTDIR}${BINDIR}/sysclean

README.md: sysclean.8
	mandoc -T markdown sysclean.8 >$@

.include <bsd.prog.mk>
