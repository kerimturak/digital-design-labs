# env.csh -- source this file from the repository root (csh, tcsh). bash/zsh: source env.sh
# Starter version: Lab L0 asks you to complete it so that it sets the same variables as env.sh.
setenv REPO_ROOT `pwd`
setenv LIB_DIR "${REPO_ROOT}/lib"
setenv LIB_STD "${LIB_DIR}/sky130_fd_sc_hd__tt_025C_1v80.lib"
setenv PATH "${REPO_ROOT}/flow/scripts:${PATH}"
if (! $?SIM) then
  which vcs >& /dev/null && setenv SIM vcs || setenv SIM verilator
endif
if (! $?LINT_TOOL) setenv LINT_TOOL verilator
if (! $?SYN_TOOL)  setenv SYN_TOOL yosys
if (! $?STA_TOOL)  setenv STA_TOOL opensta
# --- Synopsys cloud block (L0): same tool locations as env.sh
