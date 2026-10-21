SHELL = /bin/bash
PANDOC ?= pandoc
BATS ?= bats
SHELLCHECK ?= shellcheck
PREFIX ?= /usr/local
DESTDIR ?=
INSTALL ?= install
BASH_FILES ?= src/adddel scripts/*.sh
BATS_FILES ?= tests/*.bats
SHELL_FILES ?= $(BASH_FILES) $(BATS_FILES)

.PHONY: dist install check test

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

check:
	$(SHELLCHECK) $(SHELL_FILES)
	@for script in $(BASH_FILES); do \
		$(SHELL) -n "$$script" || exit $$?; \
	done

test: dist
	$(BATS) tests
