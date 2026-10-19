# env.sh -- source this file at the start of every session:   source env.sh
# Works from bash and zsh (sh-compatible syntax). For csh/tcsh use env.csh.
#
# Sets:   REPO_ROOT  LIB_DIR  LIB_STD  LIB_DB  PATH (+ flow/scripts)
#         SIM  LINT_TOOL  SYN_TOOL  STA_TOOL   tool selection used by flow/mk/*.mk
#         PYTHON (python3 >= 3.8 if one is installed)
#         (Synopsys cloud only: VC_STATIC_HOME, SPYGLASS_HOME, VERILATOR_CXX, VERILATOR_LDFLAGS)
# Every value can be overridden after sourcing, or on the make command line
# (make sim SIM=verilator). Nothing in the flow depends on the current directory.

# --- REPO_ROOT: directory of this file (bash: BASH_SOURCE, zsh: %x prompt expansion) ---
if [ -n "${BASH_VERSION:-}" ]; then
  _env_src="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  eval '_env_src="${(%):-%x}"'          # eval: keeps bash from parsing zsh-only syntax
else
  _env_src="./env.sh"                    # other shells: must be sourced from the repo root
fi
REPO_ROOT="$(cd "$(dirname "${_env_src}")" && pwd)"
export REPO_ROOT
unset _env_src

if [ ! -f "${REPO_ROOT}/flow/mk/common.mk" ]; then
  echo "env.sh: ${REPO_ROOT} does not look like the repository root" >&2
fi

# Prepend a directory to PATH once (re-sourcing does not grow PATH).
_env_path_add() {
  case ":${PATH}:" in
    *":$1:"*) ;;
    *) PATH="$1:${PATH}" ;;
  esac
}
_env_have() { command -v "$1" >/dev/null 2>&1; }

_env_path_add "${REPO_ROOT}/flow/scripts"

# --- Technology library (used from P1) ------------------------------------------------
# Default: SkyWater 130 nm in lib/ (provided by the coordinator, never committed).
export LIB_DIR="${REPO_ROOT}/lib"
LIB_STD="${LIB_DIR}/sky130_fd_sc_hd__tt_025C_1v80.lib"
LIB_DB="${LIB_DIR}/sky130_fd_sc_hd__tt_025C_1v80.db"

# =====================================================================================
# Synopsys cloud block. Only machine-specific part of the repository: optional tool
# locations, each guarded by an existence check, so this file still works anywhere.
# The Makefiles never contain absolute tool paths; they call the tools through PATH.
# =====================================================================================
_env_syn_root=/global/apps
# Open-source tools installed under /global/apps/freeware (Verilator 5.013, GTKWave).
if ! _env_have verilator && [ -x "${_env_syn_root}/freeware/verilator/5.013/bin/verilator" ]; then
  _env_path_add "${_env_syn_root}/freeware/verilator/5.013/bin"
fi
if ! _env_have gtkwave && [ -x "${_env_syn_root}/freeware/gtkwave/3.3.115/bin/gtkwave" ]; then
  _env_path_add "${_env_syn_root}/freeware/gtkwave/3.3.115/bin"
fi
# Verilator --timing needs g++ >= 10 (C++20 coroutines); RHEL 8 ships g++ 8. Verilator
# models are then built with GCC 12.4 (rpath to its libstdc++); nothing else changes.
# (gcc-toolset-13 lacks libatomic.so, which Verilator links with -latomic.)
_env_gcc=${_env_syn_root}/freeware/gcc/12.4.0
if [ -z "${VERILATOR_CXX:-}" ] && [ -x "${_env_gcc}/bin/g++" ]; then
  _env_gxx="$(g++ -dumpversion 2>/dev/null | cut -d. -f1)"
  if [ "${_env_gxx:-0}" -lt 10 ] 2>/dev/null; then
    export VERILATOR_CXX="${_env_gcc}/bin/g++"
    export VERILATOR_LDFLAGS="-Wl,-rpath,${_env_gcc}/lib64"
  fi
  unset _env_gxx
fi
unset _env_gcc
# Synopsys tools (VCS and Verdi are normally already in PATH through the site setup).
if ! _env_have vc_static_shell && [ -x "${_env_syn_root}/vcstatic/2024.09-SP2-4/bin/vc_static_shell" ]; then
  _env_path_add "${_env_syn_root}/vcstatic/2024.09-SP2-4/bin"
fi
if _env_have vc_static_shell && [ -z "${VC_STATIC_HOME:-}" ]; then
  VC_STATIC_HOME="$(cd "$(dirname "$(command -v vc_static_shell)")/.." && pwd)"
  export VC_STATIC_HOME
fi
# Standalone SpyGlass (LINT_TOOL=spyglass).
if [ -z "${SPYGLASS_HOME:-}" ] && [ -x "${_env_syn_root}/spyglass/2025.06-SP1/SPYGLASS_HOME/bin/sg_shell" ]; then
  SPYGLASS_HOME="${_env_syn_root}/spyglass/2025.06-SP1/SPYGLASS_HOME"
  export SPYGLASS_HOME
fi
if [ -n "${SPYGLASS_HOME:-}" ] && ! _env_have sg_shell && [ -x "${SPYGLASS_HOME}/bin/sg_shell" ]; then
  _env_path_add "${SPYGLASS_HOME}/bin"
fi
if ! _env_have pt_shell && [ -x "${_env_syn_root}/pt/2025.06/bin/pt_shell" ]; then
  _env_path_add "${_env_syn_root}/pt/2025.06/bin"
fi
if ! _env_have fc_shell && [ -x "${_env_syn_root}/fc/2025.06-SP1/bin/fc_shell" ]; then
  _env_path_add "${_env_syn_root}/fc/2025.06-SP1/bin"
fi
if ! _env_have fm_shell && [ -x "${_env_syn_root}/fm/2026.03-SP2/bin/fm_shell" ]; then
  _env_path_add "${_env_syn_root}/fm/2026.03-SP2/bin"
fi
# Flow bring-up library when sky130 is not installed: the generic Synopsys 'class'
# library shipped with Design Compiler. It is NOT a real technology -- it only lets the
# synthesis/STA flow run end to end. The coordinator substitutes SAED32 or the team PDK
# by setting LIB_STD/LIB_DB (e.g. in lib/ or after sourcing this file).
_env_class_dir="${_env_syn_root}/syn/2025.06-SP4/libraries/syn"
if [ ! -f "${LIB_STD}" ] && [ -f "${_env_class_dir}/class.lib" ]; then
  LIB_STD="${_env_class_dir}/class.lib"
fi
if [ ! -f "${LIB_DB}" ] && [ -f "${_env_class_dir}/class.db" ]; then
  LIB_DB="${_env_class_dir}/class.db"
fi
unset _env_syn_root _env_class_dir
# ===================================================== end of Synopsys cloud block ===

export LIB_STD LIB_DB PATH

# --- PYTHON: a python3 >= 3.8 for the helper/plot scripts (RHEL 8 python3 is 3.6) -------
if [ -z "${PYTHON:-}" ]; then
  for _env_py in python3 python3.12 python3.11 python3.10 python3.9 python3.8; do
    if _env_have "${_env_py}" && "${_env_py}" -c 'import sys; sys.exit(sys.version_info < (3, 8))' 2>/dev/null; then
      PYTHON="$(command -v "${_env_py}")"; break
    fi
  done
  unset _env_py
  export PYTHON="${PYTHON:-python3}"
fi

# --- Tool selection (flow/README.md). An already-set value is kept. -------------------
# SIM: verilator (default) | vcs.  A licensed VCS is preferred when it is in PATH.
if [ -z "${SIM:-}" ]; then
  if _env_have vcs; then SIM=vcs; else SIM=verilator; fi
fi
# LINT_TOOL: verilator (default) | spyglass (standalone sg_shell) | vcst (VC SpyGlass in
# vc_static_shell). Verilator is used when it is >= 5.020 (the program minimum);
# otherwise SpyGlass, then VC Static, when installed.
if [ -z "${LINT_TOOL:-}" ]; then
  _env_vlt_ok=0
  if _env_have verilator; then
    _env_vlt_ver="$(verilator --version 2>/dev/null | awk '{print $2}')"
    if [ "$(printf '%s\n%s\n' 5.020 "${_env_vlt_ver:-0}" | sort -V | head -n1)" = "5.020" ]; then
      _env_vlt_ok=1
    fi
  fi
  if [ "${_env_vlt_ok}" = 1 ]; then LINT_TOOL=verilator
  elif _env_have sg_shell; then LINT_TOOL=spyglass
  elif _env_have vc_static_shell; then LINT_TOOL=vcst
  else LINT_TOOL=verilator; fi
  unset _env_vlt_ok _env_vlt_ver
fi
# SYN_TOOL: yosys (default) | fc (Fusion Compiler).   Used from P1 (flow/mk/syn.mk).
if [ -z "${SYN_TOOL:-}" ]; then
  if _env_have yosys; then SYN_TOOL=yosys
  elif _env_have fc_shell; then SYN_TOOL=fc
  else SYN_TOOL=yosys; fi
fi
# STA_TOOL: opensta (default) | pt (PrimeTime).        Used from P2 (flow/mk/sta.mk).
if [ -z "${STA_TOOL:-}" ]; then
  if _env_have sta; then STA_TOOL=opensta
  elif _env_have pt_shell; then STA_TOOL=pt
  else STA_TOOL=opensta; fi
fi
export SIM LINT_TOOL SYN_TOOL STA_TOOL

unset -f _env_path_add _env_have

if [ -z "${ENV_QUIET:-}" ]; then
  echo "env.sh: REPO_ROOT=${REPO_ROOT}"
  echo "env.sh: SIM=${SIM} LINT_TOOL=${LINT_TOOL} SYN_TOOL=${SYN_TOOL} STA_TOOL=${STA_TOOL}"
  echo "env.sh: LIB_STD=${LIB_STD}"
fi
