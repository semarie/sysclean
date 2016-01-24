#	$OpenBSD$

MAN=	sysclean.8

SCRIPT=	sysclean.sh

realinstall:
	${INSTALL} ${INSTALL_COPY} -o ${BINOWN} -g ${BINGRP} -m ${BINMODE} \
		${.CURDIR}/${SCRIPT} ${DESTDIR}${BINDIR}/sysclean

.include <bsd.prog.mk>
