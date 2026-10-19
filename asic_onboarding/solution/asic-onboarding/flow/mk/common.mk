# flow/mk/common.mk -- paths, configuration tag, file-list expansion, tool selection,
# help and clean. Included first by every block Makefile; block-independent.
# Documentation of every target and variable: flow/README.md.
#
# Contract for a block Makefile: set IP, DUT_TOP, TB_TOP, RTL_FLIST, TB_FLIST, PARAMS
# (and TEST, SDC, ... as needed) BEFORE including this file.

ifndef REPO_ROOT
  $(error REPO_ROOT is not set -- run 'source env.sh' in the repository root)
endif
ifndef IP
  $(error IP is not set -- the block Makefile must set IP before including common.mk)
endif

ifndef _COMMON_MK
_COMMON_MK := 1

SHELL         := /bin/bash
.SHELLFLAGS   := -o pipefail -c
.DEFAULT_GOAL := help
FORCE:
.PHONY: FORCE help clean

# Directory of the block Makefile; relative paths in the block variables are relative to it.
IP_DIR := $(abspath $(dir $(firstword $(MAKEFILE_LIST))))
# $(call flow_abs,<path>): absolute path (relative paths resolved against IP_DIR).
flow_abs = $(if $(filter /%,$(1)),$(1),$(abspath $(IP_DIR)/$(1)))
# $(call flow_on,<var value>): non-empty if a 0/1 switch is on.
flow_on = $(filter 1 y yes on true,$(strip $(1)))

# ------------------------------------------------------------------------------------
# Block variables (defaults; the block Makefile sets the real values)
# ------------------------------------------------------------------------------------
DUT_TOP   ?= $(IP)
TB_TOP    ?= tb_$(IP)
RTL_FLIST ?= rtl/$(IP).f
TB_FLIST  ?= tb/tb.f
LINT_TOP  ?= $(DUT_TOP)
LINT_FLIST ?= $(RTL_FLIST)

# ------------------------------------------------------------------------------------
# Run variables
# ------------------------------------------------------------------------------------
PARAMS   ?=
DEFINES  ?=
TEST     ?= smoke
PLUSARGS ?=
WAVES    ?= 0
COV      ?= 0
UVM      ?= 0
# SEED: default is a new random seed per make invocation, printed in the log. It must be
# expanded once (:=), never with ?= (that would draw a new seed at every reference).
ifeq ($(strip $(SEED)),)
  override SEED := $(shell echo $$(( (RANDOM << 15 | RANDOM) + 1 )))
endif
# Lint parameters: by default the same configuration as the simulation.
LINT_PARAMS ?= $(PARAMS)

# ------------------------------------------------------------------------------------
# Tool selection. env.sh sets these from the installed tools; ?= keeps the environment
# and the command line in control.
#   SIM       verilator | vcs                 -> flow/mk/sim_$(SIM).mk   (included below)
#   LINT_TOOL verilator | spyglass | vcst     -> flow/mk/lint.mk
#   SYN_TOOL  yosys | fc                      -> flow/mk/syn.mk          (P1)
#   STA_TOOL  opensta | pt                    -> flow/mk/sta.mk          (P2)
# ------------------------------------------------------------------------------------
SIM       ?= verilator
LINT_TOOL ?= verilator
SYN_TOOL  ?= yosys
STA_TOOL  ?= opensta

# ------------------------------------------------------------------------------------
# Configuration tag and build directories
# ------------------------------------------------------------------------------------
empty :=
space := $(empty) $(empty)
CFG_TAG   := $(subst =,-,$(subst $(space),_,$(strip $(PARAMS) $(DEFINES))))
CFG       := $(or $(CFG_TAG),default)
BUILD_DIR := $(REPO_ROOT)/build/$(IP)/$(CFG)

LINT_DIR    := $(BUILD_DIR)/lint
# Blocks with several testbenches (T-RTL1 hw/ip/cdc) set SIM_PER_TB=1: every TB_TOP then gets
# its own model and logs in build/<ip>/<cfg>/sim/<TB_TOP>/ (default: one testbench per IP).
SIM_PER_TB  ?= 0
SIM_DIR     := $(BUILD_DIR)/sim$(if $(call flow_on,$(SIM_PER_TB)),/$(TB_TOP))
COV_DIR     := $(BUILD_DIR)/cov
# Hooks for later phases (directories only; the rules live in their own .mk files):
REGRESS_DIR := $(BUILD_DIR)/regress
SYN_DIR     := $(BUILD_DIR)/syn
GLS_DIR     := $(BUILD_DIR)/gls
STA_DIR     := $(BUILD_DIR)/sta

# Verilator-style overrides of the TB top; other tools translate PARAMS themselves
# (e.g. sim_vcs.mk: -pvalue+, lint.mk/spyglass: set_option param).
PARAM_FLAGS  := $(addprefix -G,$(PARAMS))
DEFINE_FLAGS := $(addprefix +define+,$(DEFINES))

# Test identity and log of one simulation run.
TEST_ID := $(TEST)_s$(SEED)
SIM_LOG := $(SIM_DIR)/$(TEST_ID).log

# ------------------------------------------------------------------------------------
# File lists
# ------------------------------------------------------------------------------------
RTL_FLIST_ABS  := $(call flow_abs,$(RTL_FLIST))
TB_FLIST_ABS   := $(call flow_abs,$(TB_FLIST))
LINT_FLIST_ABS := $(call flow_abs,$(LINT_FLIST))

FLIST_EXPAND := $(REPO_ROOT)/flow/scripts/flist_expand.sh
# $(call flist_files,<list.f>)   absolute source files, compile order
# $(call flist_incdirs,<list.f>) include directories
# $(call flist_deps,<list.f>)    sources + headers in the include directories (for make
#                                prerequisites: editing any of them rebuilds the model)
flist_files   = $(shell $(FLIST_EXPAND) --files $(1))
flist_incdirs = $(shell $(FLIST_EXPAND) --incdirs $(1))
flist_deps    = $(call flist_files,$(1)) \
                $(foreach d,$(call flist_incdirs,$(1)),$(wildcard $(d)/*.svh $(d)/*.vh))
# $(call flist_flat,<list.f>,<out.f>): recipe line writing a flat list (+incdir+, +define+,
# absolute files) for tools that do not expand ${REPO_ROOT} in -f files.
flist_flat    = mkdir -p $(dir $(2)) && $(FLIST_EXPAND) --flat $(1) > $(2)

# ------------------------------------------------------------------------------------
# Shared simulation runner, used by every sim_<tool>.mk:
#   $(call flow_run_sim,<run command>,<tool version string>)
# Runs the command in SIM_DIR, writes a header (tool version, configuration, command)
# and the output to SIM_LOG, and fails unless the run exits 0, the log contains
# "TEST PASSED" and no "TEST FAILED".
# ------------------------------------------------------------------------------------
define flow_run_sim
	@mkdir -p $(SIM_DIR)
	@{ echo "# flow: $(IP) sim  SIM=$(SIM)  tool: $(2)"; \
	   echo "# cfg=$(CFG) PARAMS='$(PARAMS)' DEFINES='$(DEFINES)' TEST=$(TEST) SEED=$(SEED) PLUSARGS='$(PLUSARGS)' WAVES=$(WAVES)"; \
	   echo "# host=$$(hostname) date=$$(date '+%F %T')"; \
	   echo "# cmd: $(strip $(1))"; } > $(SIM_LOG)
	@echo "sim: $(IP) TEST=$(TEST) SEED=$(SEED) cfg=$(CFG) -> $(SIM_LOG)"
	@cd $(SIM_DIR) && ( $(1) ) 2>&1 | tee -a $(SIM_LOG); rc=$$?; \
	 if [ $$rc -ne 0 ]; then echo "sim: FAIL ($(IP) $(TEST_ID): exit code $$rc) log: $(SIM_LOG)"; exit 1; fi; \
	 if grep -q 'TEST FAILED' $(SIM_LOG); then \
	   echo "sim: FAIL ($(IP) $(TEST_ID): TEST FAILED) log: $(SIM_LOG)"; exit 1; fi; \
	 if ! grep -q 'TEST PASSED' $(SIM_LOG); then \
	   echo "sim: FAIL ($(IP) $(TEST_ID): no TEST PASSED line) log: $(SIM_LOG)"; exit 1; fi; \
	 echo "sim: PASS ($(IP) $(TEST_ID)) log: $(SIM_LOG)"
endef

# ------------------------------------------------------------------------------------
# help / clean. Every .mk registers its targets and variables here:
#   HELP_TARGETS += <target>      HELP_<target> := <one-line description>
#   HELP_VARS    += <VAR> ...     (printed with their current values)
# ------------------------------------------------------------------------------------
HELP_TARGETS := help clean
HELP_help    := print the targets and variables with their current values
HELP_clean   := delete build/$(IP)/ (all configurations)
HELP_VARS    := IP DUT_TOP TB_TOP RTL_FLIST TB_FLIST PARAMS DEFINES CFG BUILD_DIR \
                TEST SEED PLUSARGS WAVES COV UVM SIM LINT_TOOL SYN_TOOL STA_TOOL

help:
	@echo "Block $(IP) -- targets:"
	@$(foreach t,$(HELP_TARGETS),printf '  %-10s %s\n' '$(t)' '$(HELP_$(t))';)
	@echo "Variables (current values):"
	@$(foreach v,$(HELP_VARS),printf '  %-12s = %s\n' '$(v)' '$(subst ','\'',$($(v)))';)

clean:
	rm -rf $(REPO_ROOT)/build/$(IP)

# ------------------------------------------------------------------------------------
# Simulator rules: one file per simulator, selected with SIM (T-DV2 adds UVM on vcs).
# Each sim_<tool>.mk is inert unless SIM=<tool> and guards against double inclusion, so
# a block Makefile that also includes sim_verilator.mk explicitly (L0 text) still works.
# A new simulator = a new flow/mk/sim_<tool>.mk with targets build/sim/waves (+cov).
# ------------------------------------------------------------------------------------
SIM_MK := $(REPO_ROOT)/flow/mk/sim_$(SIM).mk
ifeq ($(wildcard $(SIM_MK)),)
  $(error SIM=$(SIM): no simulator rules $(SIM_MK))
endif
include $(SIM_MK)

# Hooks for later phases -- included by the block Makefile after this file:
#   include $(REPO_ROOT)/flow/mk/regress.mk   (V1)  regress, uses REGRESS_DIR, SIM rules
#   include $(REPO_ROOT)/flow/mk/syn.mk       (P1)  synth/gls, dispatches on SYN_TOOL
#   include $(REPO_ROOT)/flow/mk/sta.mk       (P2)  sta, dispatches on STA_TOOL
# Each registers HELP_TARGETS/HELP_VARS and writes only under its *_DIR.

endif # _COMMON_MK
