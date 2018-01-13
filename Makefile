.DEFAULT_GOAL := all
SHELL := /bin/bash

.PHONY: all
all: submodule bundle_install update commit

.PHONY: submodule
submodule:
	git submodule init && git submodule update && cd vendor/homebrew-core && git checkout master && git pull

.PHONY: bundle_install
bundle_install:
	bundle install

.PHONY: update
update:
	bundle exec ruby update.rb

.PHONY: commit
commit: submodule
	CORE_SHA=$$(cd vendor/homebrew-core && git rev-parse HEAD) && \
		git commit -am "Updated formulae to $$CORE_SHA"
