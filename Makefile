SHELL = /bin/bash
PANDOC ?= pandoc
BATS ?= bats

.PHONY: dist test

dist:
	@PANDOC="$(PANDOC)" $(SHELL) scripts/dist.sh

test: dist
	$(BATS) tests
