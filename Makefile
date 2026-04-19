SHELL := /usr/bin/env bash

PKGS := $(sort $(notdir $(patsubst %/update.sh,%,$(wildcard pkgs/*/update.sh))))
UPDATE_TARGETS := $(addprefix update-,$(PKGS))

J ?= $(shell nproc 2>/dev/null || echo 4)
LOG_DIR := logs/update

.PHONY: help update update-list $(UPDATE_TARGETS)

help:
	@echo "Targets:"
	@echo "  make update              - run every pkgs/*/update.sh in parallel (best-effort)"
	@echo "  make update PKG=<name>   - run a single pkgs/<name>/update.sh"
	@echo "  make update-<name>       - same as above"
	@echo "  make update-list         - list packages with an update.sh"
	@echo "  make update J=4          - cap parallelism (default: nproc)"

update-list:
	@for p in $(PKGS); do echo $$p; done

update:
ifdef PKG
	@$(MAKE) --no-print-directory update-$(PKG)
else
	@mkdir -p $(LOG_DIR)
	@rm -f $(LOG_DIR)/*.ok $(LOG_DIR)/*.fail
	@echo "Updating $(words $(PKGS)) package(s) with -j$(J): $(PKGS)"
	@$(MAKE) --no-print-directory -k -j$(J) $(UPDATE_TARGETS) || true
	@echo
	@echo "=== update summary ==="
	@ok=0; fail=0; \
	for p in $(PKGS); do \
	  if [ -f $(LOG_DIR)/$$p.ok ]; then \
	    printf "  \033[32mOK\033[0m    %s\n" "$$p"; ok=$$((ok+1)); \
	  else \
	    printf "  \033[31mFAIL\033[0m  %s  (see $(LOG_DIR)/%s.log)\n" "$$p" "$$p"; fail=$$((fail+1)); \
	  fi; \
	done; \
	echo "ok=$$ok fail=$$fail"
endif

$(UPDATE_TARGETS): update-%:
	@mkdir -p $(LOG_DIR)
	@pkg=$*; \
	script=pkgs/$$pkg/update.sh; \
	log=$(LOG_DIR)/$$pkg.log; \
	ok=$(LOG_DIR)/$$pkg.ok; \
	fail=$(LOG_DIR)/$$pkg.fail; \
	rm -f $$ok $$fail; \
	if [ ! -x $$script ]; then \
	  echo ">>> $$pkg: no executable update.sh, skipping"; \
	  touch $$fail; \
	  exit 1; \
	fi; \
	echo ">>> $$pkg: start"; \
	if $$script >$$log 2>&1; then \
	  touch $$ok; \
	  echo "<<< $$pkg: ok"; \
	else \
	  rc=$$?; \
	  touch $$fail; \
	  echo "<<< $$pkg: FAIL rc=$$rc (log: $$log)"; \
	  exit $$rc; \
	fi
