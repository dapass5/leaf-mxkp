SHELL := /bin/sh
ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
BUILD := $(ROOT)/build
.PHONY: all icon build package validate test check source
all: package
icon:
	python3 scripts/gen_icon.py
build:
	sh scripts/build-mkxp-z.sh
package: icon build
	python3 scripts/package.py
	python3 scripts/validate_pak.py build/package/mkxp-z.pak
validate:
	python3 scripts/validate_pak.py pak
test:
	sh tests/test-launch.sh
	ruby tests/test_sa_timing.rb
	ruby tests/test_sa_performance.rb
	ruby tests/test_sa_tile_loop.rb
	ruby tests/test_sa_hash_lookup.rb
	ruby tests/test_sa_speedup.rb
check: validate test
source:
	python3 scripts/source_archive.py
