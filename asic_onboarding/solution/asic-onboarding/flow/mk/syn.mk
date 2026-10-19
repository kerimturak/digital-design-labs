# flow/mk/syn.mk -- logic synthesis, gate-level simulation and equivalence (Lab P1).
# Block-independent; included by the block Makefile after common.mk (sta.mk includes it
# too). Dispatches on SYN_TOOL like lint.mk dispatches on LINT_TOOL:
#
#   SYN_TOOL=yosys  sv2v (-DSYNTHESIS) + Yosys (flow/syn/yosys_synth.tcl) to the Liberty
#                   library LIB (default LIB_STD); GLS of the generic netlist + simcells.v
#   SYN_TOOL=fc     Fusion Compiler (flow/syn/fc_synth.tcl) to LIB_DB, non-physical
#                   compile_logical; GLS of the mapped netlist + Verilog cell models
#
# Targets:  synth   netlist + reports in build/<ip>/<cfg>/syn/  (fails on latches)
#           gls     the V testbench (TB_FLIST, TB_TOP) on the netlist with SIM (vcs |
#                   verilator), random power-up state, same PASS/FAIL rule as 'sim'
#           lec     Formality: RTL == netlist (optional, Synopsys cloud)
# Outputs are named by DUT_TOP, so seq_mul and comb_mul of one IP never collide.

ifndef _SYN_MK
_SYN_MK := 1

.PHONY: synth gls lec

SYN_FLATTEN    ?= 1
# Clock period (ns) of the SDC during synthesis (fc only: Yosys is not timing-driven).
# Kept separate from CLK_PERIOD so that 'make sta CLK_PERIOD=<p>' analyzes one fixed
# netlist at any period (the P2/P3 method); 'make synth SYN_CLK_PERIOD=3' asks FC for a
# faster netlist (timing-driven sizing) -- a different netlist, a different experiment.
SYN_CLK_PERIOD ?= 10.0
SDC            ?=
# Interface ports of the top module keep the interface's default parameters unless they
# are given explicitly (Fusion Compiler elaborate: <port>.<param>=<value>). A block with
# interface ports sets e.g.  SYN_IF_PARAMS = cpu.AW=$(call param_of,ADDR_W,10) ...
# $(call param_of,<name>,<default>): value of <name> in PARAMS, else <default>.
SYN_IF_PARAMS ?=
# SYN_WIRE_LOAD: wire-load model for FC synthesis (empty: zero wire load, FC's logical default)
SYN_WIRE_LOAD ?=
param_of = $(or $(patsubst $(1)=%,%,$(filter $(1)=%,$(PARAMS))),$(2))
SDC_ABS        := $(if $(strip $(SDC)),$(call flow_abs,$(strip $(SDC))))

NETLIST     := $(SYN_DIR)/$(DUT_TOP).v
SYN_SUMMARY := $(SYN_DIR)/$(DUT_TOP)_summary.txt
SYN_FLAT    := $(SYN_DIR)/$(DUT_TOP)_flat.f
SYN_STAMP   := $(SYN_DIR)/$(DUT_TOP).cmd
SYN_DEPS     = $(call flist_deps,$(RTL_FLIST_ABS)) $(SDC_ABS)
RTL_SRCS     = $(call flist_files,$(RTL_FLIST_ABS))

# Generated, design-independent library views (Verilog cell models, placeholder LEF):
# one copy per library under build/lib/, shared by every block.
LIB_GEN_DIR := $(REPO_ROOT)/build/lib
LIB_NAME    := $(basename $(notdir $(or $(LIB_DB),$(LIB_STD))))

# ------------------------------------------------------------------------------------
# Library-dependent SDC values. The IP SDC files read SDC_DRIVE_CELL / SDC_DRIVE_PIN /
# SDC_LOAD from the environment, so one SDC serves sky130, the bring-up class library
# and SAED32. Defaults by library name; override on the command line for another PDK.
# ------------------------------------------------------------------------------------
ifneq ($(filter sky130%,$(LIB_NAME)),)
  SDC_DRIVE_CELL ?= sky130_fd_sc_hd__inv_2
  SDC_DRIVE_PIN  ?= Y
  SDC_LOAD       ?= 0.01
else ifneq ($(filter class%,$(LIB_NAME)),)
  # class.lib: capacitive_load_unit 0.1 fF, every input pin 1 unit -> 4 = four inputs
  SDC_DRIVE_CELL ?= IV
  SDC_DRIVE_PIN  ?= Z
  SDC_LOAD       ?= 4
else ifneq ($(filter saed32%,$(LIB_NAME)),)
  # SAED32 (unit 1 fF): INVX2 of the same Vt flavor, ~4 fF = a few cell inputs
  SDC_DRIVE_CELL ?= INVX2_$(shell echo '$(word 1,$(subst _, ,$(patsubst saed32%,%,$(LIB_NAME))))' | tr a-z A-Z)
  SDC_DRIVE_PIN  ?= Y
  SDC_LOAD       ?= 4
endif
SDC_ENV = CLK_PERIOD=$(1) SDC_DRIVE_CELL='$(SDC_DRIVE_CELL)' SDC_DRIVE_PIN='$(SDC_DRIVE_PIN)' \
          SDC_LOAD='$(SDC_LOAD)'

# The synthesis command line is a prerequisite: changing PARAMS-independent knobs
# (SYN_FLATTEN, SYN_CLK_PERIOD, library, tool) re-synthesizes in the same CFG directory.
$(SYN_STAMP): FORCE
	@mkdir -p $(@D)
	@echo '$(SYN_TOOL) $(LIB_DB) $(LIB_STD) $(LIB_NDM) flat=$(SYN_FLATTEN) p=$(SYN_CLK_PERIOD) sdc=$(SDC_ABS) $(PARAMS) $(SYN_IF_PARAMS) wl=$(SYN_WIRE_LOAD) $(DEFINES) $(SDC_DRIVE_CELL) $(SDC_LOAD)' \
	  | cmp -s - $@ || echo '$(SYN_TOOL) $(LIB_DB) $(LIB_STD) $(LIB_NDM) flat=$(SYN_FLATTEN) p=$(SYN_CLK_PERIOD) sdc=$(SDC_ABS) $(PARAMS) $(SYN_IF_PARAMS) wl=$(SYN_WIRE_LOAD) $(DEFINES) $(SDC_DRIVE_CELL) $(SDC_LOAD)' > $@

synth: $(NETLIST)

ifeq ($(SYN_TOOL),yosys)
# =====================================================================================
# Yosys (lab text). Not installed on the Synopsys cloud: written to the lab specification
# and kept so the open-source flow works wherever sv2v/Yosys/Verilator are installed.
# =====================================================================================
LIB         ?= $(LIB_STD)
SV2V        ?= sv2v
YOSYS       ?= yosys
SV2V_OUT    := $(SYN_DIR)/$(DUT_TOP)_sv2v.v
SYN_LOG     := $(SYN_DIR)/$(DUT_TOP)_yosys.log
NETLIST_GEN := $(SYN_DIR)/$(DUT_TOP)_generic.v
GLS_NETLIST := $(NETLIST_GEN)
# Models of the Yosys internal cells ($_AND_, $_DFF_PN0_, ...), evaluated only when used.
GLS_CELLS    = $(shell $(YOSYS)-config --datdir)/simcells.v

$(NETLIST): $(SYN_STAMP) $(SYN_DEPS) $(REPO_ROOT)/flow/syn/yosys_synth.tcl
	@mkdir -p $(SYN_DIR)
	$(SV2V) -DSYNTHESIS $(addprefix -D,$(DEFINES)) \
	  $(addprefix -I,$(call flist_incdirs,$(RTL_FLIST_ABS))) $(RTL_SRCS) > $(SV2V_OUT)
	DUT_TOP=$(DUT_TOP) SYN_SRC=$(SV2V_OUT) SYN_DIR=$(SYN_DIR) LIB=$(LIB) \
	SYN_PARAMS="$(PARAMS)" SYN_FLATTEN=$(SYN_FLATTEN) \
	  $(YOSYS) -q -l $(SYN_LOG) -c $(REPO_ROOT)/flow/syn/yosys_synth.tcl
	@if grep -n 'Latch inferred' $(SYN_LOG); then \
	   echo "ERROR: latch inferred, see $(SYN_LOG)"; exit 1; fi
	@# summary in the same key/value format as the fc branch (read by sweep.sh)
	@awk -v lib=$(LIB_NAME) ' \
	  /Number of cells/ && !c {c=$$NF} \
	  /__(df|edf|sdf)/ {f+=$$2} \
	  /Chip area/ && !a {a=$$NF} \
	  /used for sequential elements/ {s=$$(NF-1)} \
	  END {print "tool yosys"; print "library " lib; print "cells " c; print "flops " f+0; \
	       print "latches 0"; print "area " a; print "seq_area " s+0; \
	       printf "seq_fraction %.3f\n", (a>0 ? s/a : 0)}' \
	  $(SYN_DIR)/$(DUT_TOP)_stat.rpt > $(SYN_SUMMARY)
	@grep -A40 'Number of cells' $(SYN_DIR)/$(DUT_TOP)_stat.rpt

else ifeq ($(SYN_TOOL),fc)
# =====================================================================================
# Fusion Compiler (Synopsys cloud). Reads SystemVerilog directly: no sv2v.
# =====================================================================================
FC_SHELL ?= fc_shell
# LIB_NDM: NDM cell library of a real PDK (e.g. SAED32 *_frame_timing.ndm). Empty: a
# bring-up NDM is built from LIB_DB + a placeholder LEF generated from LIB_STD.
LIB_NDM  ?=
LIB_TF   ?=
SYN_TF   := $(REPO_ROOT)/flow/syn/fc_bringup.tf
SYN_LEF  := $(if $(LIB_NDM),,$(LIB_GEN_DIR)/$(LIB_NAME).lef)
SYN_LOG  := $(SYN_DIR)/$(DUT_TOP)_fc.log
GLS_NETLIST := $(NETLIST)
# LIB_VERILOG: the library's own Verilog cell models (a PDK provides them); otherwise
# zero-delay models generated from the Liberty file by flow/scripts/lib2v.py.
LIB_VERILOG ?=
GLS_CELLS   := $(or $(LIB_VERILOG),$(LIB_GEN_DIR)/$(LIB_NAME)_cells.v)

$(LIB_GEN_DIR)/%.lef: $(LIB_STD) $(REPO_ROOT)/flow/scripts/lib2lef.py $(REPO_ROOT)/flow/scripts/liberty.py
	@mkdir -p $(@D)
	$(PYTHON) $(REPO_ROOT)/flow/scripts/lib2lef.py $(LIB_STD) $@

$(NETLIST): $(SYN_STAMP) $(SYN_DEPS) $(REPO_ROOT)/flow/syn/fc_synth.tcl $(SYN_TF) $(SYN_LEF)
	@$(call flist_flat,$(RTL_FLIST_ABS),$(SYN_FLAT))
	@rm -rf $(SYN_DIR)/fc_$(DUT_TOP) $(NETLIST) && mkdir -p $(SYN_DIR)/fc_$(DUT_TOP)
	@echo "synth: $(IP) top=$(DUT_TOP) cfg=$(CFG) Fusion Compiler ($$(command -v $(FC_SHELL))) lib=$(LIB_NAME) -> $(SYN_LOG)"
	@cd $(SYN_DIR)/fc_$(DUT_TOP) && DUT_TOP=$(DUT_TOP) SYN_DIR=$(SYN_DIR) SYN_FLAT=$(SYN_FLAT) \
	   SYN_PARAMS='$(PARAMS)' SYN_IF_PARAMS='$(SYN_IF_PARAMS)' SYN_WIRE_LOAD='$(SYN_WIRE_LOAD)' SYN_DEFINES='$(DEFINES)' SYN_FLATTEN=$(SYN_FLATTEN) \
	   LIB_DB=$(LIB_DB) LIB_NDM='$(LIB_NDM)' LIB_TF='$(LIB_TF)' SYN_LEF=$(SYN_LEF) SYN_TF=$(SYN_TF) \
	   SYN_SDC='$(SDC_ABS)' $(call SDC_ENV,$(SYN_CLK_PERIOD)) \
	   $(FC_SHELL) -f $(REPO_ROOT)/flow/syn/fc_synth.tcl < /dev/null > $(SYN_LOG) 2>&1; rc=$$?; \
	 if [ $$rc -ne 0 ] || ! grep -q '^fc_synth: ' $(SYN_LOG) || [ ! -s $(NETLIST) ]; then \
	   grep -E '^(Error|Warning: .*latch)' $(SYN_LOG) | head -20; \
	   rm -f $(NETLIST); echo "synth: FAIL ($(IP) $(DUT_TOP), exit $$rc) log: $(SYN_LOG)"; exit 1; fi; \
	 grep '^fc_synth: ' $(SYN_LOG); \
	 echo "synth: warnings in log: $$(grep -c '^Warning' $(SYN_LOG)) (unique: $$(grep '^Warning' $(SYN_LOG) | sed 's/.*(\([A-Z]*-[0-9]*\))$$/\1/' | sort -u | tr '\n' ' '))"
	@sed 's/^/  /' $(SYN_SUMMARY)
	@echo "synth: PASS ($(IP) $(DUT_TOP)) netlist: $(NETLIST)"

else
  $(error SYN_TOOL=$(SYN_TOOL) is not supported: use yosys or fc)
endif

$(LIB_GEN_DIR)/%_cells.v: $(LIB_STD) $(REPO_ROOT)/flow/scripts/lib2v.py $(REPO_ROOT)/flow/scripts/liberty.py
	@mkdir -p $(@D)
	$(PYTHON) $(REPO_ROOT)/flow/scripts/lib2v.py $(LIB_STD) $@

# =====================================================================================
# gls: the V testbench on the netlist. The RTL modules of the block are replaced by the
# netlist; packages and interfaces stay (the testbench needs them). +define+GLS lets
# bind files skip assertions on internal signals that no longer exist. The power-up
# state of every flip-flop is random (silicon has no initializers): VCS
# +vcs+initreg+random (compile and run; the values follow +ntb_random_seed=SEED -- note
# that +vcs+initreg+0/1 at run time would mean all-0/all-1, not a seed), Verilator
# --x-initial unique + rand reset 2 + seed.
# =====================================================================================
GLS_LOG      := $(GLS_DIR)/$(TEST_ID).log
GLS_DROP      = $(filter-out %_pkg.sv %_if.sv %.svh %.vh,$(RTL_SRCS))
GLS_SRCS      = $(filter-out $(GLS_DROP),$(call flist_files,$(TB_FLIST_ABS)))
GLS_INCDIRS   = $(call flist_incdirs,$(TB_FLIST_ABS))
GLS_FLAT     := $(GLS_DIR)/gls_flat.f
# GLS_INIT: random (default: random power-up values) | x (VCS only: flip-flops start X,
# the four-state check of missing resets) -- the RTL sim uses the same idea.
GLS_INIT     ?= random

ifeq ($(SIM),vcs)
GLS_MODEL_DIR := $(GLS_DIR)/vcs
GLS_BIN       := $(GLS_MODEL_DIR)/simv
GLS_BUILD_CMD := $(VCS) -full64 -sverilog -timescale=1ns/1ps -top $(TB_TOP) -f $(GLS_FLAT) \
                 $(VCS_PARAM_FLAGS) $(DEFINE_FLAGS) +define+GLS \
                 $(if $(filter random,$(GLS_INIT)),+vcs+initreg+random) \
                 -Mdir=$(GLS_MODEL_DIR)/csrc -o $(GLS_BIN) $(VCS_FLAGS)
GLS_RUN_CMD   := $(GLS_BIN) -no_save +ntb_random_seed=$(SEED) +TEST=$(TEST) +SEED=$(SEED) \
                 $(if $(filter random,$(GLS_INIT)),+vcs+initreg+random) $(SIMV_FLAGS) $(PLUSARGS)
GLS_VERSION    = $(VCS_VERSION)
else ifeq ($(SIM),verilator)
GLS_MODEL_DIR := $(GLS_DIR)/verilator
GLS_BIN       := $(GLS_MODEL_DIR)/V$(TB_TOP)
GLS_BUILD_CMD := $(VERILATOR) --binary --timing -Wno-fatal -Wno-PINNOTFOUND --timescale 1ns/1ps \
                 --x-assign unique --x-initial unique +define+GLS \
                 $(PARAM_FLAGS) $(DEFINE_FLAGS) --top-module $(TB_TOP) -Mdir $(GLS_MODEL_DIR) \
                 $(if $(VERILATOR_CXX),-MAKEFLAGS 'CXX=$(VERILATOR_CXX) LINK=$(VERILATOR_CXX)') \
                 $(if $(VERILATOR_LDFLAGS),-LDFLAGS '$(VERILATOR_LDFLAGS)') \
                 $(VERILATOR_FLAGS) -f $(GLS_FLAT)
GLS_RUN_CMD   := $(GLS_BIN) +verilator+rand+reset+2 +verilator+seed+$(SEED) \
                 +TEST=$(TEST) +SEED=$(SEED) $(PLUSARGS)
GLS_VERSION    = $(VLT_VERSION)
endif

$(GLS_MODEL_DIR)/build.cmd: FORCE
	@mkdir -p $(@D)
	@echo '$(subst ','\'',$(strip $(GLS_BUILD_CMD)))' | cmp -s - $@ || \
	 echo '$(subst ','\'',$(strip $(GLS_BUILD_CMD)))' > $@

$(GLS_BIN): $(GLS_MODEL_DIR)/build.cmd $(NETLIST) $(GLS_CELLS) $(call flist_deps,$(TB_FLIST_ABS))
	@{ $(foreach d,$(GLS_INCDIRS),echo '+incdir+$(d)';) \
	   $(foreach f,$(GLS_SRCS),echo '$(f)';) \
	   echo '$(GLS_NETLIST)'; echo '$(GLS_CELLS)'; } > $(GLS_FLAT)
	@echo "gls: build $(IP) top=$(DUT_TOP) cfg=$(CFG) $(GLS_VERSION) -> $(GLS_MODEL_DIR)"
	@echo "gls: netlist $(GLS_NETLIST)  cells $(GLS_CELLS)  (RTL replaced: $(notdir $(GLS_DROP)))"
	@cd $(GLS_MODEL_DIR) && $(strip $(GLS_BUILD_CMD)) > build.log 2>&1 \
	  || { tail -30 $(GLS_MODEL_DIR)/build.log; echo "gls: build FAIL log: $(GLS_MODEL_DIR)/build.log"; exit 1; }

# The shared runner of sim_*.mk, pointed at GLS_DIR: same log header, same PASS/FAIL rule.
gls: SIM_DIR := $(GLS_DIR)
gls: SIM_LOG := $(GLS_LOG)
gls: $(GLS_BIN)
	$(call flow_run_sim,$(GLS_RUN_CMD),$(GLS_VERSION) GLS $(SYN_TOOL) netlist)

# =====================================================================================
# lec: Formality, RTL (reference) versus netlist (implementation). FC writes an SVF file
# that tells Formality about register merging, inversion and constant flops. Optional
# (P1); needs fm_shell and the .db of the library.
# =====================================================================================
FM_SHELL ?= fm_shell
LEC_DIR  := $(SYN_DIR)/lec_$(DUT_TOP)
LEC_LOG  := $(SYN_DIR)/$(DUT_TOP)_lec.log
lec: $(NETLIST)
	@$(call flist_flat,$(RTL_FLIST_ABS),$(SYN_FLAT))
	@rm -rf $(LEC_DIR) && mkdir -p $(LEC_DIR)
	@echo "lec: $(IP) top=$(DUT_TOP) cfg=$(CFG) Formality ($$(command -v $(FM_SHELL))) -> $(LEC_LOG)"
	@cd $(LEC_DIR) && DUT_TOP=$(DUT_TOP) SYN_DIR=$(SYN_DIR) SYN_FLAT=$(SYN_FLAT) NETLIST=$(NETLIST) \
	   SYN_PARAMS='$(PARAMS)' SYN_DEFINES='$(DEFINES)' LIB_DB=$(LIB_DB) \
	   SVF=$(if $(filter fc,$(SYN_TOOL)),$(SYN_DIR)/$(DUT_TOP).svf) \
	   $(FM_SHELL) -f $(REPO_ROOT)/flow/syn/fm_lec.tcl < /dev/null > $(LEC_LOG) 2>&1; \
	 if grep -q '^lec: SUCCEEDED' $(LEC_LOG); then grep '^lec:' $(LEC_LOG); echo "lec: PASS ($(IP) $(DUT_TOP))"; \
	 else grep -E '^(lec:|Error)' $(LEC_LOG) | head -20; echo "lec: FAIL ($(IP) $(DUT_TOP)) log: $(LEC_LOG)"; exit 1; fi

HELP_TARGETS += synth gls lec
HELP_synth   := synthesize DUT_TOP with SYN_TOOL (yosys|fc) -> $(NETLIST); fails on latches
HELP_gls     := run TEST on the netlist with SIM (random power-up state); fail unless TEST PASSED
HELP_lec     := Formality equivalence RTL vs netlist (optional)
HELP_VARS    += SYN_FLATTEN SYN_CLK_PERIOD SDC LIB_STD LIB_DB LIB_NDM LIB_TF LIB_VERILOG NETLIST GLS_INIT

endif # _SYN_MK
