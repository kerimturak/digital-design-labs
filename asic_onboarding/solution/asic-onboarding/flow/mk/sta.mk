# flow/mk/sta.mk -- static timing analysis (Lab P2) and parameter sweeps (Lab P3).
# Block-independent; included by the block Makefile after syn.mk (it includes syn.mk
# itself, for NETLIST). Dispatches on STA_TOOL like lint.mk on LINT_TOOL:
#
#   STA_TOOL=opensta  OpenSTA  (flow/sta/sta.tcl)     Liberty LIB (default LIB_STD)
#   STA_TOOL=pt       PrimeTime (flow/sta/pt_sta.tcl)  compiled LIB_DB
#
# Targets:  sta      synthesize if needed, then time NETLIST with SDC at CLK_PERIOD
#           sweep    synth + iterated sta over every PARAMS line of CONFIGS -> CSV + plots
#           print-X  print the value of make variable X (used by sweep.sh)
# Reports: build/<ip>/<cfg>/sta/<top>_p<period>_{check_setup,setup,hold,recovery,removal,
#          drv}.rpt, <top>_p<period>.log and <top>_p<period>_summary.txt (key/value, read
#          by sweep.sh: slack_max tns slack_min startpoint endpoint path_type).

ifndef _STA_MK
_STA_MK := 1

include $(REPO_ROOT)/flow/mk/syn.mk

.PHONY: sta sweep

CLK_PERIOD  ?= 10.0
STA_TAG     := $(DUT_TOP)_p$(CLK_PERIOD)
STA_OUT     := $(STA_DIR)/$(STA_TAG)
STA_LOG     := $(STA_OUT).log
STA_SUMMARY := $(STA_OUT)_summary.txt

# STA_SDC: constraints of the analysis; default the block's SDC (the one synthesis used).
# A separate variable so that an analysis-only change -- 'make sta STA_SDC=my_io.sdc' (P2
# question 6) -- times the existing netlist instead of re-synthesizing it: SDC is a
# prerequisite of the netlist (Fusion Compiler synthesizes against it), STA_SDC is not.
STA_SDC     ?= $(SDC)
STA_SDC_ABS := $(if $(strip $(STA_SDC)),$(call flow_abs,$(strip $(STA_SDC))))

# Common environment of both STA scripts (the SDC reads CLK_PERIOD and SDC_* itself).
STA_ENV = DUT_TOP=$(DUT_TOP) NETLIST=$(NETLIST) SDC=$(STA_SDC_ABS) STA_OUT=$(STA_OUT) SYN_WIRE_LOAD='$(SYN_WIRE_LOAD)' \
          $(call SDC_ENV,$(CLK_PERIOD))

sta_check_sdc = $(if $(STA_SDC_ABS),,$(error sta: SDC is not set -- add 'SDC := syn/$(IP).sdc' to the block Makefile))

ifeq ($(STA_TOOL),opensta)
# =====================================================================================
# OpenSTA (lab text). Not installed on the Synopsys cloud: written to the lab
# specification and kept for machines with the open-source tools.
# =====================================================================================
STA ?= sta
LIB ?= $(LIB_STD)
sta: $(NETLIST)
	$(sta_check_sdc)
	@mkdir -p $(STA_DIR)
	$(STA_ENV) LIB=$(LIB) $(STA) -no_init -exit $(REPO_ROOT)/flow/sta/sta.tcl | tee $(STA_LOG)
	@# key/value summary in the same format as the pt branch
	@{ echo "tool opensta"; echo "period $(CLK_PERIOD)"; \
	   awk '/^worst slack/ && !mx {print "slack_max " $$NF; mx=1; next} \
	        /^worst slack/ && mx {print "slack_min " $$NF} \
	        /^tns/ {print "tns " $$NF}' $(STA_LOG); \
	   awk '/^Startpoint:/ && !s {print "startpoint " $$2; s=1; sp=$$0} \
	        /^Endpoint:/   && !e {print "endpoint " $$2; e=1; ep=$$0} \
	        END {a=(sp ~ /input port/) ? "in" : "reg"; b=(ep ~ /output port/) ? "out" : "reg"; \
	             print "path_type " a "2" b}' $(STA_OUT)_setup.rpt; } > $(STA_SUMMARY)
	@sed 's/^/  /' $(STA_SUMMARY)

else ifeq ($(STA_TOOL),pt)
# =====================================================================================
# PrimeTime (Synopsys cloud): the sign-off STA tool, same reports, its own format.
# =====================================================================================
PT_SHELL ?= pt_shell
sta: $(NETLIST)
	$(sta_check_sdc)
	@mkdir -p $(STA_DIR)/pt
	@echo "sta: $(IP) top=$(DUT_TOP) cfg=$(CFG) period=$(CLK_PERIOD) PrimeTime ($$(command -v $(PT_SHELL))) lib=$(LIB_NAME) -> $(STA_LOG)"
	@cd $(STA_DIR)/pt && $(STA_ENV) LIB_DB=$(LIB_DB) \
	   $(PT_SHELL) -f $(REPO_ROOT)/flow/sta/pt_sta.tcl < /dev/null > $(STA_LOG) 2>&1; rc=$$?; \
	 if [ $$rc -ne 0 ] || ! grep -q '^pt_sta: ' $(STA_LOG); then \
	   grep -E '^Error' $(STA_LOG) | head -20; echo "sta: FAIL ($(IP) $(DUT_TOP), exit $$rc) log: $(STA_LOG)"; exit 1; fi; \
	 grep '^pt_sta: ' $(STA_LOG)
	@sed 's/^/  /' $(STA_SUMMARY)
	@echo "sta: reports $(STA_OUT)_*.rpt"

else
  $(error STA_TOOL=$(STA_TOOL) is not supported: use opensta or pt)
endif

# =====================================================================================
# sweep (Lab P3): for each PARAMS line of CONFIGS, synth + sta iterated to the minimum
# period (T <- T - slack, from CLK_PERIOD); CSV and plots in build/<ip>/sweep/.
# =====================================================================================
CONFIGS   ?= syn/configs.txt
SWEEP_DIR := $(REPO_ROOT)/build/$(IP)/sweep
# <top>_sweep.csv for syn/configs.txt; another list gets its own CSV (configs_2way.txt ->
# <top>_configs_2way_sweep.csv), so a stretch sweep never overwrites the main one.
SWEEP_TAG := $(if $(filter configs,$(basename $(notdir $(CONFIGS)))),,_$(basename $(notdir $(CONFIGS))))
SWEEP_CSV := $(SWEEP_DIR)/$(DUT_TOP)$(SWEEP_TAG)_sweep.csv
sweep:
	@test -f $(call flow_abs,$(CONFIGS)) || { echo "sweep: no $(CONFIGS)"; exit 1; }
	@mkdir -p $(SWEEP_DIR)
	DUT_TOP=$(DUT_TOP) MAKE='$(MAKE)' $(REPO_ROOT)/flow/scripts/sweep.sh \
	  $(call flow_abs,$(CONFIGS)) $(SWEEP_CSV) $(CLK_PERIOD)
	$(PYTHON) $(REPO_ROOT)/flow/scripts/plot_sweep.py $(SWEEP_CSV)
	@column -s, -t $(SWEEP_CSV)

# print-<VAR>: value of a make variable, e.g. make -s print-SYN_DIR PARAMS="AW=4 DW=32"
print-%:
	@echo '$($*)'

HELP_TARGETS += sta sweep print-VAR
HELP_sta     := time NETLIST with SDC at CLK_PERIOD using STA_TOOL (opensta|pt) -> $(STA_DIR)
HELP_sweep   := synth + iterated sta for every PARAMS line of CONFIGS -> $(SWEEP_CSV)
HELP_print-VAR := print the value of make variable VAR (make -s print-SYN_DIR)
HELP_VARS    += CLK_PERIOD STA_SDC CONFIGS STA_DIR

endif # _STA_MK
