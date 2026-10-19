# Top-level Makefile -- delegates to the blocks; nothing block-specific here.
#
#   make <target> IP=<ip>      runs <target> in hw/ip/<ip>   (e.g. make sim IP=counter TEST=smoke)
#   make <target> TOP=<top>    runs <target> in hw/top/<top> (IP=<top> works too: hw/ip first)
#   make check-all             lint + sim (default test) of every block with a Makefile
#                              (hw/ip/*, hw/top/*, and dv/model/* models such as dv/model/cache_model);
#                              PASS/FAIL table, non-zero exit code on any failure
#   make help | clean          this help | delete build/ entirely
# All other variables (PARAMS, SEED, SIM, LINT_TOOL, ...) are passed through to the block.

ifndef REPO_ROOT
  $(error REPO_ROOT is not set -- run 'source env.sh' in the repository root)
endif

SHELL         := /bin/bash
.DEFAULT_GOAL := help

IPS  := $(sort $(patsubst $(REPO_ROOT)/hw/ip/%/Makefile,%,$(wildcard $(REPO_ROOT)/hw/ip/*/Makefile)))
TOPS := $(sort $(patsubst $(REPO_ROOT)/hw/top/%/Makefile,%,$(wildcard $(REPO_ROOT)/hw/top/*/Makefile)))
# Models under dv/model/ with a block Makefile (T-MOD: dv/model/cache_model) are checked too.
MODELS := $(sort $(patsubst $(REPO_ROOT)/dv/model/%/Makefile,%,$(wildcard $(REPO_ROOT)/dv/model/*/Makefile)))

# Steps of check-all; later labs may extend the list (e.g. CHECK_STEPS="lint sim regress").
CHECK_STEPS ?= lint sim
CHECK_DIR   := $(REPO_ROOT)/build/check-all

# Known block targets (explicit, because e.g. 'build' also exists as a directory here).
BLOCK_TARGETS := help lint build sim waves cov clean regress synth gls sta sweep cdc lec

# IP= / TOP= select the block and must not reach the block Makefile (it sets IP itself).
MAKEOVERRIDES := $(filter-out IP=% TOP=%,$(MAKEOVERRIDES))
SUBMAKE       := $(MAKE) --no-print-directory

ifneq ($(strip $(IP)$(TOP)),)
  # IP=<name> looks in hw/ip/ first, then in hw/top/ (T-RTL2: make sim IP=dcache_cdc_top).
  BLOCK_DIR := $(if $(IP),$(if $(wildcard $(REPO_ROOT)/hw/ip/$(IP)/Makefile),$(REPO_ROOT)/hw/ip/$(IP),$(REPO_ROOT)/hw/top/$(IP)),$(REPO_ROOT)/hw/top/$(TOP))
  ifeq ($(wildcard $(BLOCK_DIR)/Makefile),)
    $(error no Makefile in $(BLOCK_DIR) (blocks: $(IPS) $(TOPS)))
  endif
.PHONY: $(BLOCK_TARGETS)
$(BLOCK_TARGETS):
	@$(SUBMAKE) -C $(BLOCK_DIR) $@
# Any other target is delegated too.
.DEFAULT:
	@$(SUBMAKE) -C $(BLOCK_DIR) $@
else
.PHONY: help clean
help:
	@echo "make <target> IP=<ip>   targets: $(BLOCK_TARGETS) (see 'make help IP=<ip>')"
	@echo "make <target> TOP=<top>"
	@echo "make check-all          $(CHECK_STEPS) of every block (CHECK_STEPS='$(CHECK_STEPS)')"
	@echo "make clean              delete $(REPO_ROOT)/build"
	@echo "blocks:  hw/ip: $(or $(IPS),-)   hw/top: $(or $(TOPS),-)   dv/model: $(or $(MODELS),-)"
	@echo "tools:   SIM=$(SIM) LINT_TOOL=$(LINT_TOOL) SYN_TOOL=$(SYN_TOOL) STA_TOOL=$(STA_TOOL)"
clean:
	rm -rf $(REPO_ROOT)/build
endif

# check-all: every step of every block, even after a failure, then a summary table.
.PHONY: check-all
check-all:
	@mkdir -p $(CHECK_DIR); rm -f $(CHECK_DIR)/*.log; fail=0; rows=(); \
	for b in $(addprefix ip/,$(IPS)) $(addprefix top/,$(TOPS)) $(addprefix dv/model/,$(MODELS)); do \
	  row=$$(printf '%-24s' "$$b"); \
	  case $$b in dv/model/*) d=$(REPO_ROOT)/$$b ;; *) d=$(REPO_ROOT)/hw/$$b ;; esac; \
	  for s in $(CHECK_STEPS); do \
	    log=$(CHECK_DIR)/$${b//\//_}_$$s.log; \
	    printf 'check-all: %-24s %-8s ... ' "$$b" "$$s"; \
	    if $(SUBMAKE) -C $$d $$s > $$log 2>&1; then r=PASS; else r=FAIL; fail=1; fi; \
	    if [ $$r = FAIL ]; then echo "FAIL  (log: $$log)"; else echo PASS; fi; \
	    row="$$row $$(printf '%-6s' $$r)"; \
	  done; \
	  rows+=("$$row"); \
	done; \
	echo; printf '%-24s' "block"; for s in $(CHECK_STEPS); do printf ' %-6s' "$$s"; done; echo; \
	for r in "$${rows[@]}"; do echo "$$r"; done; \
	echo; echo "logs: $(CHECK_DIR)/"; \
	if [ $$fail -ne 0 ]; then echo "check-all: FAIL"; exit 1; fi; \
	echo "check-all: PASS"
