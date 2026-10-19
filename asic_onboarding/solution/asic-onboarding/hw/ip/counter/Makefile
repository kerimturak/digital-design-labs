# hw/ip/counter/Makefile -- block variables + include of the shared flow (flow/README.md).
# All variables are set BEFORE the includes; the shared rules are block-independent.
IP        := counter
DUT_TOP   := counter
TB_TOP    ?= tb_counter
RTL_FLIST := rtl/counter.f
TB_FLIST  ?= tb/tb.f
PARAMS    ?= WIDTH=8
TEST      ?= smoke
# P2: constraints (flow check: synth/sta/gls also run on this L0 block)
SDC       := syn/counter.sdc

include $(REPO_ROOT)/flow/mk/common.mk
include $(REPO_ROOT)/flow/mk/lint.mk
# Simulator rules: common.mk already includes sim_$(SIM).mk (SIM=verilator by default,
# SIM=vcs on the Synopsys cloud, see env.sh). This line is kept from the lab text; it is
# inert unless SIM=verilator, and including a .mk twice is harmless.
include $(REPO_ROOT)/flow/mk/sim_verilator.mk
include $(REPO_ROOT)/flow/mk/syn.mk
include $(REPO_ROOT)/flow/mk/sta.mk
