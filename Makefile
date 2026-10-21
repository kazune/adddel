SHELL = /bin/bash
PANDOC ?= pandoc
BATS ?= bats
PREFIX ?= /usr/local
DESTDIR ?=
INSTALL ?= install

.PHONY: dist install test

dist:
	@PANDOC="$(PANDOC)" $(SHELL) scripts/dist.sh

install:
	@if [ ! -f dist/bin/adddel ] || [ ! -r dist/bin/adddel ] || \
	    [ ! -f dist/share/man/man1/adddel.1 ] || [ ! -r dist/share/man/man1/adddel.1 ]; then \
		printf 'make install: distribution files are missing or unreadable; run make dist first\n' >&2; \
		exit 1; \
	fi
	$(INSTALL) -d -m 755 "$(DESTDIR)$(PREFIX)/bin" "$(DESTDIR)$(PREFIX)/share/man/man1"
	$(INSTALL) -m 755 dist/bin/adddel "$(DESTDIR)$(PREFIX)/bin/adddel"
	$(INSTALL) -m 644 dist/share/man/man1/adddel.1 "$(DESTDIR)$(PREFIX)/share/man/man1/adddel.1"

test: dist
	$(BATS) tests
