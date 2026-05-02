SHELL := /usr/bin/env bash

PKGS := $(sort $(notdir $(patsubst %/update.sh,%,$(wildcard pkgs/*/update.sh))))
UPDATE_TARGETS := $(addprefix update-,$(PKGS))

J ?= $(shell nproc 2>/dev/null || echo 4)
LOG_DIR := logs/update
NIX_STRICT_FLAGS := --option accept-flake-config false --option use-registries false

.PHONY: help update update-list audit security-audit security-check security-build vuln-check $(UPDATE_TARGETS)

help:
	@echo "Targets:"
	@echo "  make update              - run every pkgs/*/update.sh in parallel (best-effort)"
	@echo "  make update PKG=<name>   - run a single pkgs/<name>/update.sh"
	@echo "  make update-<name>       - same as above"
	@echo "  make update-list         - list packages with an update.sh"
	@echo "  make update J=4          - cap parallelism (default: nproc)"
	@echo "  make audit               - run static supply-chain audit"
	@echo "  make security-check      - run audit and nix flake check"
	@echo "  make security-build      - build laptop and hq system closures"
	@echo "  make vuln-check          - scan the host system closure with vulnix (HOST=$(HOST))"

audit: security-audit

security-audit:
	@scripts/security-audit

security-check: security-audit
	@nix $(NIX_STRICT_FLAGS) flake check --no-update-lock-file

security-build:
	@nix $(NIX_STRICT_FLAGS) build .#nixosConfigurations.laptop.config.system.build.toplevel --no-update-lock-file
	@nix $(NIX_STRICT_FLAGS) build .#nixosConfigurations.hq.config.system.build.toplevel --no-update-lock-file

HOST ?= $(shell hostname)
VULNIX_TARGET ?= .\#nixosConfigurations.$(HOST).config.system.build.toplevel
VULNIX_ARGS ?=

vuln-check:
	@set -euo pipefail; \
	target="$(VULNIX_TARGET)"; \
	echo "Building $$target for vulnerability scan..." >&2; \
	out=$$(nix $(NIX_STRICT_FLAGS) build --no-link --print-out-paths --no-update-lock-file "$$target"); \
	echo "Scanning $$out with vulnix..." >&2; \
	nix $(NIX_STRICT_FLAGS) shell --no-write-lock-file .#vulnix -c scripts/vulnix-runtime-closure "$$out" $(VULNIX_ARGS)

update-list:
	@for p in $(PKGS); do echo $$p; done

PKG_VERSION = $$(grep -m1 -E '^[[:space:]]*version[[:space:]]*=[[:space:]]*"' pkgs/$$pkg/default.nix 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/')

update:
ifdef PKG
	@$(MAKE) --no-print-directory update-$(PKG)
else
	@mkdir -p $(LOG_DIR)
	@rm -f $(LOG_DIR)/*.ok $(LOG_DIR)/*.fail $(LOG_DIR)/*.before $(LOG_DIR)/*.after
	@echo "Updating $(words $(PKGS)) package(s) with -j$(J): $(PKGS)"
	@$(MAKE) --no-print-directory -k -j$(J) $(UPDATE_TARGETS) || true
	@echo
	@echo "=== update summary ==="
	@ok=0; fail=0; bumped=0; unchanged=0; \
	for pkg in $(PKGS); do \
	  before=$$(cat $(LOG_DIR)/$$pkg.before 2>/dev/null || echo "?"); \
	  after=$$(cat $(LOG_DIR)/$$pkg.after 2>/dev/null || echo "?"); \
	  if [ -f $(LOG_DIR)/$$pkg.ok ]; then \
	    if [ "$$before" != "$$after" ]; then \
	      printf "  \033[32mBUMPED\033[0m   %-22s %s -> %s\n" "$$pkg" "$$before" "$$after"; bumped=$$((bumped+1)); \
	    else \
	      printf "  \033[90mup-to-date\033[0m %-22s %s\n" "$$pkg" "$$before"; unchanged=$$((unchanged+1)); \
	    fi; \
	    ok=$$((ok+1)); \
	  else \
	    printf "  \033[31mFAIL\033[0m     %-22s (see $(LOG_DIR)/%s.log)\n" "$$pkg" "$$pkg"; fail=$$((fail+1)); \
	  fi; \
	done; \
	echo "ok=$$ok (bumped=$$bumped unchanged=$$unchanged) fail=$$fail"
endif

$(UPDATE_TARGETS): update-%:
	@mkdir -p $(LOG_DIR)
	@pkg=$*; \
	script=pkgs/$$pkg/update.sh; \
	log=$(LOG_DIR)/$$pkg.log; \
	ok=$(LOG_DIR)/$$pkg.ok; \
	fail=$(LOG_DIR)/$$pkg.fail; \
	before_file=$(LOG_DIR)/$$pkg.before; \
	after_file=$(LOG_DIR)/$$pkg.after; \
	rm -f $$ok $$fail $$before_file $$after_file; \
	echo "$(PKG_VERSION)" >$$before_file; \
	if [ ! -x $$script ]; then \
	  echo ">>> $$pkg: no executable update.sh, skipping"; \
	  touch $$fail; \
	  exit 1; \
	fi; \
	echo ">>> $$pkg: start"; \
	if $$script >$$log 2>&1; then \
	  echo "$(PKG_VERSION)" >$$after_file; \
	  touch $$ok; \
	  before=$$(cat $$before_file); after=$$(cat $$after_file); \
	  if [ "$$before" != "$$after" ]; then \
	    echo "<<< $$pkg: ok (bumped $$before -> $$after)"; \
	  else \
	    echo "<<< $$pkg: ok (unchanged $$before)"; \
	  fi; \
	else \
	  rc=$$?; \
	  echo "$(PKG_VERSION)" >$$after_file; \
	  touch $$fail; \
	  echo "<<< $$pkg: FAIL rc=$$rc (log: $$log)"; \
	  exit $$rc; \
	fi
