#!/usr/bin/env bash
# check_tools.sh -- print and check the tool versions needed by a phase of the program.
#
# Usage: check_tools.sh [R|V|P]      (default R)
# Python: $PYTHON (set by env.sh to a python3 >= 3.8) or python3.
#   R  Phase 1 RTL (and L0):   make, git, python3, lint, simulation, waveforms
#   V  Phase 2 verification:   same tools as R
#   P  Phase 3 PD/PPA:         + synthesis (sv2v + Yosys, or Fusion Compiler)
#                              + STA (OpenSTA, or PrimeTime)
#
# Every flow step can run on an open-source tool or on a Synopsys tool. For each step the
# script reports both columns (version, minimum, OK / TOO OLD / MISSING). A step passes if
# either toolset is usable; the exit code is non-zero if a step needed by the phase fails.
# Synopsys versions are taken from the install path (no license checkout).

set -u
phase=${1:-R}
case "$phase" in R|V|P) ;; *) echo "usage: check_tools.sh [R|V|P]" >&2; exit 2 ;; esac
phase_rank() { case "$1" in R) echo 1 ;; V) echo 2 ;; P) echo 3 ;; esac; }
want=$(phase_rank "$phase")

# version_ge <found> <min>: true if found >= min (sort -V)
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

# Open-source tool version: prints the version or nothing.
oss_version() {
  local v=""
  command -v "$1" >/dev/null 2>&1 || return 0
  case "$1" in
    verilator) v=$(verilator --version 2>/dev/null | awk '{print $2}') ;;
    gtkwave)   v=$(gtkwave --version 2>/dev/null </dev/null | grep -o -m1 'v[0-9][0-9.]*' | tr -d v) ;;
    make)      v=$(make --version 2>/dev/null | head -n1 | awk '{print $3}') ;;
    git)       v=$(git --version 2>/dev/null | awk '{print $3}') ;;
    *python3*) v=$("$1" --version 2>&1 | awk '{print $2}') ;;
    sv2v)      v=$(sv2v --numeric-version 2>/dev/null || sv2v --version 2>/dev/null | grep -o -m1 '[0-9][0-9.]*') ;;
    yosys)     v=$(yosys -V 2>/dev/null | grep -o -m1 '[0-9][0-9.]*' | head -n1) ;;
    sta)       v=$(echo exit | sta -version 2>/dev/null | grep -o -m1 '[0-9][0-9.]*' | head -n1) ;;
  esac
  echo "${v:-?}"
}

# Synopsys tool version from the install path: /global/apps/vcs/2024.09-SP1-1/bin/vcs.
snps_version() {
  local p
  p=$(command -v "$1" 2>/dev/null) || return 0
  p=$(readlink -f "$p")
  echo "$p" | grep -o -E '/[A-Z]?-?[0-9]{4}\.[0-9]{2}[-A-Za-z0-9.]*/' | head -n1 | tr -d / || echo found
}

# One cell: "<tool> <version> >= <min> <status>"; sets global cell_ok=1 if usable.
cell_ok=0
oss_cell() {   # <tool> <min>
  local v; v=$(oss_version "$1")
  if [ -z "$v" ]; then printf '%-30s' "${1##*/} - MISSING"; return; fi
  if [ "$v" = "?" ] || version_ge "$v" "$2"; then
    printf '%-30s' "${1##*/} $v>=$2 OK"; cell_ok=1
  else
    printf '%-30s' "${1##*/} $v>=$2 TOO OLD"
  fi
}
snps_cell() {  # <tool>
  local v; v=$(snps_version "$1")
  if [ -z "$v" ]; then printf '%-34s' "$1 - MISSING"; return; fi
  printf '%-34s' "$1 $v OK"; cell_ok=1
}

fail=0
printf 'check_tools.sh phase %s (host %s)\n' "$phase" "$(hostname)"
printf '%-7s %-30s %-34s %-6s %s\n' step open-source synopsys needed result
# step  needed-from  open-source-tool(s) min   synopsys-tool
row() {
  local step=$1 from=$2 oss=$3 min=$4 snps=$5 need res
  cell_ok=0
  printf '%-7s ' "$step"
  if [ "$oss" = "-" ]; then printf '%-30s' "-"; else oss_cell "$oss" "$min"; fi
  printf ' '
  if [ "$snps" = "-" ]; then printf '%-34s' "-"; else snps_cell "$snps"; fi
  need=0
  if [ "$from" != alt ] && [ "$(phase_rank "$from")" -le "$want" ]; then need=1; fi
  if [ $cell_ok -eq 1 ]; then res=OK
  elif [ "$from" = alt ]; then res="missing (alternative/optional)"
  elif [ $need -eq 1 ]; then res=FAIL
  else res="missing (needed from $from)"; fi
  printf ' %-6s %s\n' "$from" "$res"
}

row make    R make      4.0    -
row git     R git       2.30   -
row python  R "${PYTHON:-python3}" 3.8 -
row lint    R verilator 5.020  sg_shell
row lint    alt -       -      vc_static_shell
row sim     R verilator 5.020  vcs
row waves   R gtkwave   3.3    verdi
row conv    alt sv2v    0.0.11 -
row synth   P yosys     0.38   fc_shell
row sta     P sta       2.4    pt_shell
row equiv   alt -       -      fm_shell

# Rows marked 'alt' are alternatives or optional: vc_static_shell (second lint tool),
# sv2v (needed only on the Yosys path, checked jointly below), fm_shell (no lab needs it).
# The verdict is computed per step over both toolsets:
have() { command -v "$1" >/dev/null 2>&1; }
vlt_ok=0; v=$(oss_version verilator); [ -n "$v" ] && version_ge "$v" 5.020 && vlt_ok=1
lint_ok=0; { [ $vlt_ok -eq 1 ] || have sg_shell || have vc_static_shell; } && lint_ok=1
synth_ok=0; { { have sv2v && have yosys; } || have fc_shell; } && synth_ok=1
fail=0
for tm in make:4.0 git:2.30 "${PYTHON:-python3}:3.8"; do
  v=$(oss_version "${tm%%:*}"); { [ -n "$v" ] && version_ge "$v" "${tm##*:}"; } || fail=1
done
[ $lint_ok -eq 1 ] || fail=1
{ [ $vlt_ok -eq 1 ] || have vcs; } || fail=1
{ have gtkwave || have verdi; } || fail=1
if [ "$want" -ge 3 ]; then
  [ $synth_ok -eq 1 ] || fail=1
  { have sta || have pt_shell; } || fail=1
fi
# The equivalence row (Formality) is informational: no lab requires it.

echo
if [ $fail -ne 0 ]; then echo "check_tools: phase $phase FAIL"; exit 1; fi
echo "check_tools: phase $phase PASS"
