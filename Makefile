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
	run-regress-man-readme \
	run-regress-man-date

# check perl syntax
run-regress-perl-syntax:
	@echo TEST: perl syntax
	@perl -c sysclean.pl

# check man page
run-regress-man-lint:
	@echo TEST: man page lint
	@mandoc -T lint -W style sysclean.8

# ensure README.md and man page are in sync
run-regress-man-readme:
	@echo TEST: README.md sync
	@mv README.md README.md.orig
	@${MAKE} README.md
	@mv README.md README.md.new
	@mv README.md.orig README.md
	diff -q README.md README.md.new
	@rm README.md.new

# ensure .Dd date inside man page is the right date
run-regress-man-date:
	@echo TEST: man page date
	@if [ -d .git ]; then \
		grep -qF -- \
			"$$(date -r $$(git log -1 --format=%ct sysclean.8) \
				+'.Dd %B %d, %Y')" \
			sysclean.8 ; \
	elif [ -d .got ]; then \
		grep -qF -- \
			"$$(got log -l 1 sysclean.8 \
				| sed -ne 's/^date: //p' \
				| xargs -0 date -j -f '%a %b %d %T %Y %Z' \
					+'.Dd %B %d, %Y')" \
			sysclean.8 ; \
	else \
		echo "unchecked" ; \
	fi

.if !defined(VERSION)
release:
	@echo "error: please define VERSION"; false

.else
release: sysclean-${VERSION}.tar.gz

DISTRIBUTED_FILES = \
	Makefile \
	README.md \
	sysclean.ignore \
	${MAN} \
	${SCRIPT}
	
sysclean-${VERSION}.tar.gz: ${DISTRIBUTED_FILES}
	chmod a+rX ${DISTRIBUTED_FILES}
	pax -w -zf "$@" -s ',^,sysclean-${VERSION}/,' ${DISTRIBUTED_FILES}

.endif

.include <bsd.prog.mk>
