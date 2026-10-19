# env.csh -- csh/tcsh version of env.sh:   source env.csh
# Same variables and the same tool selection as env.sh (keep both files in sync).
#
# csh cannot reliably tell a sourced script its own path. This file uses $_ (set by an
# interactive tcsh to "source <path>"); otherwise it must be sourced from the repo root.

set _env_src = ""
if ( $?_ ) then
  set _env_src = `echo "$_" | awk '{print $NF}'`
endif
if ( "$_env_src" == "" || ! -f "$_env_src" ) set _env_src = "./env.csh"
if ( ! -f "$_env_src" ) then
  echo "env.csh: cannot locate env.csh -- source it from the repository root"
  unset _env_src
  exit 1
endif
set _env_dir = `dirname "$_env_src"`
setenv REPO_ROOT `cd "$_env_dir" && pwd`
unset _env_src _env_dir

if ( ! -f "${REPO_ROOT}/flow/mk/common.mk" ) then
  echo "env.csh: ${REPO_ROOT} does not look like the repository root"
endif

# Directories to prepend to PATH (each only once, see the loop below).
set _env_add = ( "${REPO_ROOT}/flow/scripts" )

# --- Technology library (used from P1) -------------------------------------------------
setenv LIB_DIR "${REPO_ROOT}/lib"
setenv LIB_STD "${LIB_DIR}/sky130_fd_sc_hd__tt_025C_1v80.lib"
setenv LIB_DB  "${LIB_DIR}/sky130_fd_sc_hd__tt_025C_1v80.db"

# =====================================================================================
# Synopsys cloud block (see env.sh): optional tool locations, each guarded.
# =====================================================================================
set _r = /global/apps
which verilator >& /dev/null
if ( $status != 0 && -x $_r/freeware/verilator/5.013/bin/verilator ) set _env_add = ( $_env_add $_r/freeware/verilator/5.013/bin )
which gtkwave >& /dev/null
if ( $status != 0 && -x $_r/freeware/gtkwave/3.3.115/bin/gtkwave ) set _env_add = ( $_env_add $_r/freeware/gtkwave/3.3.115/bin )
# Verilator --timing needs g++ >= 10; RHEL 8 ships g++ 8 -> GCC 12.4 for Verilator models only.
if ( ! $?VERILATOR_CXX && -x $_r/freeware/gcc/12.4.0/bin/g++ ) then
  set _g = `g++ -dumpversion | cut -d. -f1`
  if ( $_g < 10 ) then
    setenv VERILATOR_CXX $_r/freeware/gcc/12.4.0/bin/g++
    setenv VERILATOR_LDFLAGS "-Wl,-rpath,$_r/freeware/gcc/12.4.0/lib64"
  endif
  unset _g
endif
which vc_static_shell >& /dev/null
if ( $status != 0 && -x $_r/vcstatic/2024.09-SP2-4/bin/vc_static_shell ) set _env_add = ( $_env_add $_r/vcstatic/2024.09-SP2-4/bin )
if ( ! $?VC_STATIC_HOME && -d $_r/vcstatic/2024.09-SP2-4 ) setenv VC_STATIC_HOME $_r/vcstatic/2024.09-SP2-4
if ( ! $?SPYGLASS_HOME && -x $_r/spyglass/2025.06-SP1/SPYGLASS_HOME/bin/sg_shell ) setenv SPYGLASS_HOME $_r/spyglass/2025.06-SP1/SPYGLASS_HOME
which sg_shell >& /dev/null
if ( $status != 0 && $?SPYGLASS_HOME ) then
  if ( -x $SPYGLASS_HOME/bin/sg_shell ) set _env_add = ( $_env_add $SPYGLASS_HOME/bin )
endif
which pt_shell >& /dev/null
if ( $status != 0 && -x $_r/pt/2025.06/bin/pt_shell ) set _env_add = ( $_env_add $_r/pt/2025.06/bin )
which fc_shell >& /dev/null
if ( $status != 0 && -x $_r/fc/2025.06-SP1/bin/fc_shell ) set _env_add = ( $_env_add $_r/fc/2025.06-SP1/bin )
which fm_shell >& /dev/null
if ( $status != 0 && -x $_r/fm/2026.03-SP2/bin/fm_shell ) set _env_add = ( $_env_add $_r/fm/2026.03-SP2/bin )
# Flow bring-up library (generic Synopsys 'class' library) when sky130 is absent. Not a
# real technology: the coordinator substitutes SAED32 or the team PDK.
set _c = $_r/syn/2025.06-SP4/libraries/syn
if ( ! -f "$LIB_STD" && -f $_c/class.lib ) setenv LIB_STD $_c/class.lib
if ( ! -f "$LIB_DB"  && -f $_c/class.db  ) setenv LIB_DB  $_c/class.db
unset _r _c
# ===================================================== end of Synopsys cloud block ===

foreach _d ( $_env_add )
  echo ":${PATH}:" | grep -q ":${_d}:"
  if ( $status != 0 ) setenv PATH "${_d}:${PATH}"
end
unset _d _env_add
rehash

# --- PYTHON: a python3 >= 3.8 for the helper/plot scripts -------------------------------
if ( ! $?PYTHON ) then
  foreach _p ( python3 python3.12 python3.11 python3.10 python3.9 python3.8 )
    which $_p >& /dev/null
    if ( $status == 0 ) then
      $_p -c 'import sys; sys.exit(sys.version_info < (3, 8))' >& /dev/null
      if ( $status == 0 ) then
        setenv PYTHON `which $_p`
        break
      endif
    endif
  end
  if ( ! $?PYTHON ) setenv PYTHON python3
  unset _p
endif

# --- Tool selection (an already-set value is kept) ---------------------------------------
if ( ! $?SIM ) then
  setenv SIM verilator
  which vcs >& /dev/null
  if ( $status == 0 ) setenv SIM vcs
endif
if ( ! $?LINT_TOOL ) then
  # verilator if >= 5.020, else spyglass, else vcst
  set _v = 0
  which verilator >& /dev/null
  if ( $status == 0 ) set _v = `verilator --version | awk '{print $2}'`
  set _lo = `printf '5.020\n%s\n' "$_v" | sort -V | head -n1`
  if ( "$_lo" == "5.020" ) then
    setenv LINT_TOOL verilator
  else
    setenv LINT_TOOL verilator
    which vc_static_shell >& /dev/null
    if ( $status == 0 ) setenv LINT_TOOL vcst
    which sg_shell >& /dev/null
    if ( $status == 0 ) setenv LINT_TOOL spyglass
  endif
  unset _v _lo
endif
if ( ! $?SYN_TOOL ) then
  setenv SYN_TOOL yosys
  which yosys >& /dev/null
  if ( $status != 0 ) then
    which fc_shell >& /dev/null
    if ( $status == 0 ) setenv SYN_TOOL fc
  endif
endif
if ( ! $?STA_TOOL ) then
  setenv STA_TOOL opensta
  which sta >& /dev/null
  if ( $status != 0 ) then
    which pt_shell >& /dev/null
    if ( $status == 0 ) setenv STA_TOOL pt
  endif
endif

if ( ! $?ENV_QUIET ) then
  echo "env.csh: REPO_ROOT=${REPO_ROOT}"
  echo "env.csh: SIM=${SIM} LINT_TOOL=${LINT_TOOL} SYN_TOOL=${SYN_TOOL} STA_TOOL=${STA_TOOL}"
  echo "env.csh: LIB_STD=${LIB_STD}"
endif
