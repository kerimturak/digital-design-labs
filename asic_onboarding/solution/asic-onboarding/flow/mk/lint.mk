# flow/mk/lint.mk -- lint of LINT_FLIST with top LINT_TOP. Block-independent.
#   LINT_TOOL=verilator  verilator --lint-only -Wall (+ lint/<ip>.vlt waivers)   default
#   LINT_TOOL=spyglass   SpyGlass lint/lint_rtl goal in sg_shell (flow/lint/spyglass_lint.prj)
#   LINT_TOOL=vcst       VC SpyGlass lint_rtl goal in vc_static_shell (flow/lint/vcst_lint.tcl)
#   LINT_TOOL=vcs        VCS compile with +lint=all (class-based code, e.g. dv/model/cache_model)
# Output: build/<ip>/<cfg>/lint/. The target fails on any Verilator warning (-Wall), and
# on any SpyGlass / VC SpyGlass fatal or error; with LINT_FAIL_ON=warning also on their
# warnings (infos never fail).

ifndef _LINT_MK
_LINT_MK := 1

LINT_LOG     := $(LINT_DIR)/lint_$(LINT_TOOL).log
LINT_FLAT    := $(LINT_DIR)/lint_flat.f
LINT_DEFINES ?= $(DEFINES)
LINT_GOAL    ?=
LINT_FAIL_ON ?= error

# Environment for the Tcl-driven tools (read by flow/lint/*.{prj,tcl}).
LINT_TCL_ENV = LINT_FLAT=$(LINT_FLAT) LINT_TOP=$(LINT_TOP) LINT_PARAMS='$(LINT_PARAMS)' \
               LINT_DEFINES='$(LINT_DEFINES)' LINT_GOAL='$(LINT_GOAL)' LINT_WAIVER='$(LINT_WAIVER)'

.PHONY: lint

ifeq ($(LINT_TOOL),verilator)
# -----------------------------------------------------------------------------------------
VERILATOR   ?= verilator
LINT_WAIVER ?= $(wildcard $(IP_DIR)/lint/$(IP).vlt)
lint:
	@mkdir -p $(LINT_DIR)
	@echo "lint: $(IP) top=$(LINT_TOP) cfg=$(CFG) tool=$$($(VERILATOR) --version) -> $(LINT_LOG)"
	@cd $(LINT_DIR) && $(VERILATOR) --lint-only -Wall --top-module $(LINT_TOP) \
	   $(addprefix -G,$(LINT_PARAMS)) $(addprefix +define+,$(LINT_DEFINES)) \
	   $(LINT_WAIVER) -f $(LINT_FLIST_ABS) 2>&1 | tee $(LINT_LOG) \
	 && echo "lint: PASS ($(IP), verilator)" \
	 || { echo "lint: FAIL ($(IP), verilator) log: $(LINT_LOG)"; exit 1; }

else ifeq ($(LINT_TOOL),spyglass)
# -----------------------------------------------------------------------------------------
SG_SHELL    ?= sg_shell
LINT_WAIVER ?= $(wildcard $(IP_DIR)/lint/$(IP).awl)
SG_RUN_DIR  := $(LINT_DIR)/spyglass
lint:
	@$(call flist_flat,$(LINT_FLIST_ABS),$(LINT_FLAT))
	@rm -rf $(SG_RUN_DIR) && mkdir -p $(SG_RUN_DIR)
	@echo "lint: $(IP) top=$(LINT_TOP) cfg=$(CFG) tool=SpyGlass ($$(command -v $(SG_SHELL))) -> $(LINT_LOG)"
	@cd $(SG_RUN_DIR) && $(LINT_TCL_ENV) $(SG_SHELL) -tcl $(REPO_ROOT)/flow/lint/spyglass_lint.prj \
	   < /dev/null > $(LINT_LOG) 2>&1; rc=$$?; \
	 summ=$$(grep -m1 'Reported Messages:' $(LINT_LOG)); \
	 if [ -z "$$summ" ]; then tail -20 $(LINT_LOG); echo "lint: FAIL ($(IP), spyglass: no goal summary, exit $$rc) log: $(LINT_LOG)"; exit 1; fi; \
	 echo "lint: SpyGlass $$(echo $$summ | sed 's/^ *//')"; \
	 rpt=$$(ls $(SG_RUN_DIR)/spyglass-1/consolidated_reports/*/moresimple.rpt 2>/dev/null | head -1); \
	 [ -n "$$rpt" ] && grep -E '^(ID |\[[0-9A-Fa-f]+\] )' $$rpt | sed "s#$(REPO_ROOT)/##" | cut -c1-200 | sed 's/^/  /'; \
	 echo "lint: report $$rpt"; \
	 set -- $$(echo "$$summ" | sed -E 's/.* ([0-9]+) Fatals, *([0-9]+) Errors, *([0-9]+) Warnings.*/\1 \2 \3/'); \
	 if [ "$$1" != 0 ] || [ "$$2" != 0 ] || { [ "$(LINT_FAIL_ON)" = warning ] && [ "$$3" != 0 ]; }; then \
	   echo "lint: FAIL ($(IP), spyglass: $$1 fatals, $$2 errors, $$3 warnings; LINT_FAIL_ON=$(LINT_FAIL_ON))"; exit 1; fi; \
	 echo "lint: PASS ($(IP), spyglass)"

else ifeq ($(LINT_TOOL),vcst)
# -----------------------------------------------------------------------------------------
VC_STATIC_SHELL ?= vc_static_shell
LINT_WAIVER ?= $(wildcard $(IP_DIR)/lint/$(IP).vcst.tcl)
VCST_RUN_DIR := $(LINT_DIR)/vcst
VCST_REPORT  := $(LINT_DIR)/vcst_report.txt
lint:
	@$(call flist_flat,$(LINT_FLIST_ABS),$(LINT_FLAT))
	@rm -rf $(VCST_RUN_DIR) $(VCST_REPORT) && mkdir -p $(VCST_RUN_DIR)
	@echo "lint: $(IP) top=$(LINT_TOP) cfg=$(CFG) tool=VC SpyGlass ($$(command -v $(VC_STATIC_SHELL))) -> $(LINT_LOG)"
	@cd $(VCST_RUN_DIR) && $(LINT_TCL_ENV) LINT_REPORT=$(VCST_REPORT) \
	   $(VC_STATIC_SHELL) -mode64 -f $(REPO_ROOT)/flow/lint/vcst_lint.tcl < /dev/null > $(LINT_LOG) 2>&1; rc=$$?; \
	 if [ $$rc -ne 0 ] || [ ! -f $(VCST_REPORT) ]; then tail -20 $(LINT_LOG); echo "lint: FAIL ($(IP), vcst: exit $$rc / no report) log: $(LINT_LOG)"; exit 1; fi; \
	 if grep -q 'COM_ENV006' $(LINT_LOG) $(VCST_REPORT); then grep -h 'COM_ENV006' $(LINT_LOG) $(VCST_REPORT) | head -3; \
	   echo "lint: FAIL ($(IP), vcst: top was black-boxed (COM_ENV006), nothing was linted -- class-based code needs LINT_TOOL=vcs)"; exit 1; fi; \
	 tot=$$(awk '/Management Summary/{m=1} m && $$1=="Total"{print $$2, $$3, $$4, $$5; exit}' $(VCST_REPORT)); \
	 set -- $${tot:-0 0 0 0}; \
	 echo "lint: VC SpyGlass $$1 Fatals, $$2 Errors, $$3 Warnings, $$4 Infos  report: $(VCST_REPORT)"; \
	 awk '/Tree Summary/{t=1} t && /^  (fatal|error|warning|info) /{printf "  %-8s %-20s %s\n", $$1, $$3, $$4} /^  Total/{if(t)exit}' $(VCST_REPORT); \
	 if [ "$$1" != 0 ] || [ "$$2" != 0 ] || { [ "$(LINT_FAIL_ON)" = warning ] && [ "$$3" != 0 ]; }; then \
	   echo "lint: FAIL ($(IP), vcst: $$1 fatals, $$2 errors, $$3 warnings; LINT_FAIL_ON=$(LINT_FAIL_ON))"; exit 1; fi; \
	 echo "lint: PASS ($(IP), vcst)"

else ifeq ($(LINT_TOOL),vcs)
# -----------------------------------------------------------------------------------------
# VCS compiler checks (+lint=all) for class-based code that the RTL linters cannot read
# (SpyGlass/VC SpyGlass parse synthesizable RTL only), e.g. dv/model/cache_model (T-MOD).
# Fails on any VCS Error; Lint-/Warning- messages are warnings (LINT_FAIL_ON=warning).
VCS ?= vcs
VCS_LINT_DIR := $(LINT_DIR)/vcs
lint:
	@$(call flist_flat,$(LINT_FLIST_ABS),$(LINT_FLAT))
	@rm -rf $(VCS_LINT_DIR) && mkdir -p $(VCS_LINT_DIR)
	@echo "lint: $(IP) top=$(LINT_TOP) cfg=$(CFG) tool=VCS +lint=all ($$(command -v $(VCS))) -> $(LINT_LOG)"
	@cd $(VCS_LINT_DIR) && $(VCS) -full64 -sverilog +lint=all -timescale=1ns/1ps -top $(LINT_TOP) \
	   -f $(LINT_FLAT) $(addprefix -pvalue+$(LINT_TOP).,$(LINT_PARAMS)) $(addprefix +define+,$(LINT_DEFINES)) \
	   -Mdir=$(VCS_LINT_DIR)/csrc -o $(VCS_LINT_DIR)/simv > $(LINT_LOG) 2>&1; rc=$$?; \
	 e=$$(grep -c '^Error-' $(LINT_LOG)); w=$$(grep -c -E '^(Lint|Warning)-' $(LINT_LOG)); \
	 grep -E '^(Error|Lint|Warning)-' -A1 $(LINT_LOG) | grep -v '^--' | sed "s#$(REPO_ROOT)/##" | cut -c1-200 | sed 's/^/  /'; \
	 echo "lint: VCS $$e errors, $$w warnings (exit $$rc)"; \
	 if [ $$rc -ne 0 ] || [ "$$e" != 0 ] || { [ "$(LINT_FAIL_ON)" = warning ] && [ "$$w" != 0 ]; }; then \
	   echo "lint: FAIL ($(IP), vcs: $$e errors, $$w warnings; LINT_FAIL_ON=$(LINT_FAIL_ON)) log: $(LINT_LOG)"; exit 1; fi; \
	 echo "lint: PASS ($(IP), vcs)"

else
  $(error LINT_TOOL=$(LINT_TOOL) is not supported: use verilator, spyglass, vcst or vcs)
endif

HELP_TARGETS += lint
HELP_lint    := lint LINT_FLIST with top LINT_TOP using LINT_TOOL (verilator|spyglass|vcst|vcs)
HELP_VARS    += LINT_TOP LINT_FLIST LINT_PARAMS LINT_DEFINES LINT_WAIVER LINT_GOAL LINT_FAIL_ON

endif # _LINT_MK
