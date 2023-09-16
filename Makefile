#	$OpenBSD$

MAN=	sysclean.8

SCRIPT=	sysclean.pl

BINDIR?=	/usr/local/sbin
MANDIR?=	/usr/local/man/man

realinstall:
	${INSTALL} ${INSTALL_COPY} -o ${BINOWN} -g ${BINGRP} -m ${BINMODE} \
		${.CURDIR}/${SCRIPT} ${DESTDIR}${BINDIR}/sysclean

README.md: sysclean.8
	mandoc -T markdown sysclean.8 \
	| sed	-e 's/&nbsp;/ /g' \
		-e 's/&lt;/</g' \
		-e 's/&gt;/>/g' \
		-e 's/\\\[/[/g' \
	>$@

regress: run-regress-perl-syntax \
	run-regress-man-lint \
	run-regress-man-readme

run-regress-perl-syntax:
	@echo TEST: perl syntax
	@perl -c sysclean.pl

run-regress-man-lint:
	@echo TEST: man page lint
	@mandoc -T lint -W style sysclean.8

run-regress-man-readme:
	@echo TEST: README.md sync
	@mv README.md README.md.orig
	@${MAKE} README.md
	@mv README.md README.md.new
	@mv README.md.orig README.md
	@diff -q README.md README.md.new ; rm README.md.new

.include <bsd.prog.mk>
