# flow/mk/cdc.mk -- 'make cdc' (Lab T-RTL1): structural clock-domain-crossing check of
# CDC_FLIST with top CDC_TOP using SpyGlass CDC (sg_shell, flow/cdc/spyglass_cdc.prj).
# Block-independent; included by the block Makefile after common.mk.
#   CDC_TOP    top of the check                    (default LINT_TOP, else DUT_TOP)
#   CDC_FLIST  file list                           (default LINT_FLIST)
#   CDC_PARAMS parameter overrides of CDC_TOP      (default LINT_PARAMS = PARAMS)
#   CDC_SGDC   SpyGlass constraints: clocks/domains, resets, port domains, FIFOs
#                                                  (default syn/<CDC_TOP>.sgdc)
#   CDC_GOALS  goals in order (default cdc/cdc_setup_check cdc/cdc_verify_struct; add
#              cdc/cdc_verify for the formal checks)
#   CDC_WAIVER optional .awl waiver file           (default lint/<ip>_cdc.awl if present)
#   CDC_FAIL_ON error (default) | warning
#   CDC_EXPECT  pass (default) | fail: 'fail' inverts the verdict -- used to show that the
#              check catches a deliberately broken crossing (missing synchronizer)
# Output: build/<ip>/<cfg>/cdc/ (cdc_spyglass.log, spyglass/spyglass-1/consolidated_reports).
# The target fails on any SpyGlass fatal or error of any goal (with CDC_FAIL_ON=warning
# also on warnings). Alternative tool: VC SpyGlass CDC in vc_static_shell (not wired here).

ifndef _CDC_MK
_CDC_MK := 1

CDC_TOP     ?= $(LINT_TOP)
CDC_FLIST   ?= $(LINT_FLIST)
CDC_PARAMS  ?= $(LINT_PARAMS)
CDC_SGDC    ?= syn/$(CDC_TOP).sgdc
CDC_GOALS   ?= cdc/cdc_setup_check cdc/cdc_verify_struct
CDC_WAIVER  ?= $(wildcard $(IP_DIR)/lint/$(IP)_cdc.awl)
CDC_FAIL_ON ?= error
CDC_EXPECT  ?= pass
SG_SHELL    ?= sg_shell

CDC_DIR     := $(BUILD_DIR)/cdc
CDC_LOG     := $(CDC_DIR)/cdc_spyglass.log
CDC_FLAT    := $(CDC_DIR)/cdc_flat.f
CDC_RUN_DIR := $(CDC_DIR)/spyglass

.PHONY: cdc
cdc:
	@$(call flist_flat,$(call flow_abs,$(CDC_FLIST)),$(CDC_FLAT))
	@test -f $(call flow_abs,$(CDC_SGDC)) || { echo "cdc: no constraints $(call flow_abs,$(CDC_SGDC))"; exit 1; }
	@rm -rf $(CDC_RUN_DIR) && mkdir -p $(CDC_RUN_DIR)
	@echo "cdc: $(IP) top=$(CDC_TOP) cfg=$(CFG) goals='$(CDC_GOALS)' tool=SpyGlass CDC ($$(command -v $(SG_SHELL))) -> $(CDC_LOG)"
	@cd $(CDC_RUN_DIR) && CDC_FLAT=$(CDC_FLAT) CDC_TOP=$(CDC_TOP) CDC_PARAMS='$(CDC_PARAMS)' \
	   CDC_SGDC=$(call flow_abs,$(CDC_SGDC)) CDC_GOALS='$(CDC_GOALS)' CDC_WAIVER='$(CDC_WAIVER)' \
	   $(SG_SHELL) -tcl $(REPO_ROOT)/flow/cdc/spyglass_cdc.prj < /dev/null > $(CDC_LOG) 2>&1; rc=$$?; \
	 n=$$(grep -c 'Reported Messages:' $(CDC_LOG)); \
	 if [ "$$n" -lt "$(words $(CDC_GOALS))" ]; then tail -20 $(CDC_LOG); echo "cdc: FAIL ($(IP): $$n of $(words $(CDC_GOALS)) goal summaries, exit $$rc) log: $(CDC_LOG)"; exit 1; fi; \
	 set -- $$(grep 'Reported Messages:' $(CDC_LOG) | sed -E 's/.* ([0-9]+) Fatals, *([0-9]+) Errors, *([0-9]+) Warnings.*/\1 \2 \3/' \
	          | awk '{f+=$$1; e+=$$2; w+=$$3} END {print f+0, e+0, w+0}'); \
	 for r in $(CDC_RUN_DIR)/spyglass-1/consolidated_reports/*/moresimple.rpt; do \
	   echo "cdc: $$(basename $$(dirname $$r))"; \
	   grep -E '^\[[0-9A-Fa-f]+\] ' $$r | grep -E ' (Fatal|Error|Warning) ' | sed "s#$(REPO_ROOT)/##" | cut -c1-220 | sed 's/^/  /'; \
	   echo "  synchronized crossings (Ac_sync01/02): $$(grep -cE '^\[[0-9A-Fa-f]+\] +Ac_sync0[12] ' $$r)"; \
	 done; \
	 echo "cdc: SpyGlass CDC $$1 fatals, $$2 errors, $$3 warnings (all goals)"; \
	 bad=0; if [ "$$1" != 0 ] || [ "$$2" != 0 ] || { [ "$(CDC_FAIL_ON)" = warning ] && [ "$$3" != 0 ]; }; then bad=1; fi; \
	 if [ "$(CDC_EXPECT)" = fail ]; then \
	   if [ $$bad = 1 ]; then echo "cdc: PASS ($(IP): the broken crossing was detected, CDC_EXPECT=fail)"; exit 0; \
	   else echo "cdc: FAIL ($(IP): CDC_EXPECT=fail but no error was reported)"; exit 1; fi; fi; \
	 if [ $$bad = 1 ]; then echo "cdc: FAIL ($(IP): $$1 fatals, $$2 errors, $$3 warnings; CDC_FAIL_ON=$(CDC_FAIL_ON)) log: $(CDC_LOG)"; exit 1; fi; \
	 echo "cdc: PASS ($(IP), spyglass)"

HELP_TARGETS += cdc
HELP_cdc     := structural CDC check of CDC_FLIST/CDC_TOP with SpyGlass CDC (CDC_SGDC, CDC_GOALS)
HELP_VARS    += CDC_TOP CDC_FLIST CDC_SGDC CDC_GOALS CDC_FAIL_ON CDC_EXPECT

endif # _CDC_MK
