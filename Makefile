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
	>$@

regress: run-regress-perl-syntax \
	run-regress-man-lint \
	run-regress-man-readme \
	run-regress-man-date

run-regress-perl-syntax:
	@echo TEST: perl syntax
	@perl -c sysclean.pl

run-regress-man-lint:
	@echo TEST: man page lint
	@mandoc -T lint -W style sysclean.8

run-regress-man-readme:
	@echo TEST: README.md sync
	@mandoc -T markdown sysclean.8 | diff -q README.md -

run-regress-man-date:
	@echo TEST: man page date
	@if [ -d .git ]; then \
		grep -qF -- \
			"$$(date -r $$(git log -1 --format="%ct" sysclean.8) \
				+'.Dd %B %d, %Y')" \
			sysclean.8 ; \
	fi

.include <bsd.prog.mk>
