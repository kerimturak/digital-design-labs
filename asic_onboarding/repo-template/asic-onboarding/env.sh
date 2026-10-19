# env.sh -- source this file from the repository root (bash, zsh). csh/tcsh: source env.csh
# Starter version: Lab L0 asks you to complete it (tool detection, PYTHON, cloud block).
if [ -n "${BASH_SOURCE[0]:-}" ]; then _env_src="${BASH_SOURCE[0]}"; else _env_src="$(eval 'echo ${(%):-%x}')"; fi
export REPO_ROOT="$(cd "$(dirname "${_env_src}")" && pwd)"
unset _env_src
export LIB_DIR="${REPO_ROOT}/lib"
export LIB_STD="${LIB_DIR}/sky130_fd_sc_hd__tt_025C_1v80.lib"   # used from P1
export PATH="${REPO_ROOT}/flow/scripts:${PATH}"
# Tool selection: keep a value that is already set, else pick from the installed tools
: "${SIM:=$(command -v vcs >/dev/null && echo vcs || echo verilator)}"
: "${LINT_TOOL:=verilator}"          # spyglass if Verilator < 5.020 and sg_shell exists
: "${SYN_TOOL:=yosys}" "${STA_TOOL:=opensta}"   # fc / pt if Yosys / OpenSTA are missing
export SIM LINT_TOOL SYN_TOOL STA_TOOL
# --- Synopsys cloud block (L0): add the /global/apps/... locations here, each guarded by
# --- an existence check. Makefiles never contain absolute tool paths.
