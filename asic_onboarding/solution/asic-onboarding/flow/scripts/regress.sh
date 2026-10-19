#!/usr/bin/env bash
# flow/scripts/regress.sh -- run a regression list (Lab V1). Called by flow/mk/regress.mk;
# block-independent: it only calls 'make build' and 'make sim' of the block.
#
#   regress.sh --ip <ip> --ip-dir <dir> --list <regress.list> [options]
#     --summary <file>     summary table          (default build/<ip>/regress_summary.txt)
#     --seed-base <n>      seeds are base+1 .. base+N   (default 0: reproducible 1..N)
#     --jobs <n>           runs in parallel per configuration (default 1)
#     --configs <a,b>      only these configurations (default: all)
#     --tests <a,b>        only these tests          (default: all)
#     --cover-check 0|1    fail if a cover property was never hit (default 1)
#
# List format (one entry per line, '#' comments):
#   config <name> [VAR=value ...]          make variables of a compile-time configuration,
#                                          e.g. config w32d5 PARAMS="WIDTH=32 DEPTH=5"
#   test <name> <seeds> <configs> [+plusargs ...]
#                                          <configs>: '*' (all) or a comma list of names
#
# Every run is an ordinary 'make sim' with its normal log build/<ip>/<cfg>/sim/<test>_s<seed>.log;
# the make output goes to build/<ip>/regress/<config>/<test>_s<seed>.out. Each configuration
# is built once before its runs (own build directory, L0 rule). Lines 'COVER: <label> <count>'
# printed by the testbench are summed over all runs of the regression.
# Exit code: 0 only if every run passed (and every reported cover was hit, --cover-check 1).

set -uo pipefail
set -f   # no pathname expansion: '*' in the list means 'all configurations'

ip= ; ip_dir= ; list= ; summary= ; seed_base=0 ; jobs=1 ; only_cfgs= ; only_tests= ; cover_check=1
while [ $# -gt 0 ]; do
  case "$1" in
    --ip)          ip=$2; shift 2 ;;
    --ip-dir)      ip_dir=$2; shift 2 ;;
    --list)        list=$2; shift 2 ;;
    --summary)     summary=$2; shift 2 ;;
    --seed-base)   seed_base=$2; shift 2 ;;
    --jobs)        jobs=$2; shift 2 ;;
    --configs)     only_cfgs=$2; shift 2 ;;
    --tests)       only_tests=$2; shift 2 ;;
    --cover-check) cover_check=$2; shift 2 ;;
    *) echo "regress: unknown option $1" >&2; exit 2 ;;
  esac
done
: "${REPO_ROOT:?REPO_ROOT is not set -- source env.sh}"
[ -n "$ip" ] && [ -d "$ip_dir" ] || { echo "regress: --ip and --ip-dir are required" >&2; exit 2; }
[ -f "$list" ] || { echo "regress: no regression list $list" >&2; exit 2; }
MAKE_CMD=${MAKE:-make}
summary=${summary:-$REPO_ROOT/build/$ip/regress_summary.txt}
out_root=$REPO_ROOT/build/$ip/regress

# Variables given to 'make regress' on the command line are exported to this script. The
# ones that select a configuration or a run must come from the list only; everything else
# (SIM, COV, WAVES, TB_TOP, VERILATOR_FLAGS, ...) is inherited by every run.
user_plusargs=${PLUSARGS:-}
unset MAKEFLAGS MFLAGS GNUMAKEFLAGS MAKEOVERRIDES PARAMS DEFINES TEST SEED PLUSARGS

join_args() {  # join_args <a> <b>: "a b" without stray blanks
  local r="$1 $2"; r=${r# }; echo "${r% }"
}

in_list() {  # in_list <item> <comma list or empty=all>
  [ -z "$2" ] && return 0
  case ",$2," in *",$1,"*) return 0 ;; esac
  return 1
}

# ---- parse the list ---------------------------------------------------------------------
cfg_names=() ; declare -A cfg_vars
t_names=() ; t_seeds=() ; t_cfgs=() ; t_args=()
lineno=0
while IFS= read -r line || [ -n "$line" ]; do
  lineno=$((lineno + 1))
  line=${line%%#*}
  [ -z "${line//[[:space:]]/}" ] && continue
  eval "words=($line)" 2>/dev/null || { echo "regress: $list:$lineno: cannot parse: $line" >&2; exit 2; }
  case "${words[0]}" in
    config)
      [ ${#words[@]} -ge 2 ] || { echo "regress: $list:$lineno: config without a name" >&2; exit 2; }
      cfg_names+=("${words[1]}")
      vars=""
      for w in "${words[@]:2}"; do vars+=" $(printf '%q' "$w")"; done
      cfg_vars[${words[1]}]=$vars ;;
    test)
      [ ${#words[@]} -ge 4 ] || { echo "regress: $list:$lineno: expected 'test <name> <seeds> <configs> [plusargs]'" >&2; exit 2; }
      t_names+=("${words[1]}"); t_seeds+=("${words[2]}"); t_cfgs+=("${words[3]}")
      t_args+=("${words[*]:4}") ;;
    *) echo "regress: $list:$lineno: unknown keyword '${words[0]}'" >&2; exit 2 ;;
  esac
done < "$list"
[ ${#cfg_names[@]} -gt 0 ] || { cfg_names=(default); cfg_vars[default]=""; }

mkdir -p "$(dirname "$summary")" "$out_root"
rm -f "$summary"
start_all=$(date +%s)
{
  echo "# regress: $ip  list=${list#$REPO_ROOT/}  SIM=${SIM:-verilator}  seeds=$((seed_base + 1))..  $(date '+%F %T')"
  printf '%-10s %-14s %10s  %-6s %6s  %s\n' config test seed result time log
} | tee "$summary"

# ---- one run (executed in the background when --jobs > 1) -------------------------------
run_one() {  # run_one <cfg> <test> <seed> <plusargs> <resultfile>
  local cfg=$1 t=$2 s=$3 pa=$4 res=$5 out t0 rc log
  out=$out_root/$cfg/${t}_s$s.out
  t0=$(date +%s)
  eval "$MAKE_CMD" --no-print-directory -C "$ip_dir" sim "${cfg_vars[$cfg]}" \
       TEST="$t" SEED="$s" PLUSARGS="$(printf '%q' "$pa")" > "$out" 2>&1 < /dev/null
  rc=$?
  log=$(sed -n 's/^sim: \(PASS\|FAIL\) .* log: \(.*\)$/\2/p' "$out" | tail -1)
  printf '%s|%s|%s|%s|%s|%s\n' "$cfg" "$t" "$s" "$([ $rc -eq 0 ] && echo PASS || echo FAIL)" \
         "$(( $(date +%s) - t0 ))" "${log:-$out}" > "$res"
}

fail=0 ; n_runs=0 ; n_fail=0 ; rerun=() ; logs=()
for cfg in "${cfg_names[@]}"; do
  in_list "$cfg" "$only_cfgs" || continue
  mkdir -p "$out_root/$cfg"
  # Runs of this configuration
  runs=()
  for i in "${!t_names[@]}"; do
    in_list "${t_names[$i]}" "$only_tests" || continue
    [ "${t_cfgs[$i]}" = "*" ] || in_list "$cfg" "${t_cfgs[$i]}" || continue
    for ((k = 1; k <= t_seeds[i]; k++)); do runs+=("$i $((seed_base + k))"); done
  done
  [ ${#runs[@]} -eq 0 ] && continue
  # Build once; a build failure fails every run of the configuration.
  if ! eval "$MAKE_CMD" --no-print-directory -C "$ip_dir" build "${cfg_vars[$cfg]}" \
          > "$out_root/$cfg/build.out" 2>&1 < /dev/null; then
    for r in "${runs[@]}"; do
      set -- $r
      printf '%-10s %-14s %10s  %-6s %6s  %s\n' "$cfg" "${t_names[$1]}" "$2" BUILD - \
             "${out_root#$REPO_ROOT/}/$cfg/build.out" | tee -a "$summary"
      n_runs=$((n_runs + 1)); n_fail=$((n_fail + 1)); fail=1
    done
    rerun+=("make -C ${ip_dir#$REPO_ROOT/} build ${cfg_vars[$cfg]# }")
    continue
  fi
  # Runs, at most --jobs at a time; results are printed in list order.
  resdir=$(mktemp -d "$out_root/$cfg/.res.XXXX")
  idx=0
  for r in "${runs[@]}"; do
    set -- $r
    pa=$(join_args "${t_args[$1]}" "$user_plusargs")
    if [ "$jobs" -gt 1 ]; then
      while [ "$(jobs -rp | wc -l)" -ge "$jobs" ]; do wait -n; done
      run_one "$cfg" "${t_names[$1]}" "$2" "$pa" "$resdir/$(printf %05d $idx)" &
    else
      run_one "$cfg" "${t_names[$1]}" "$2" "$pa" "$resdir/$(printf %05d $idx)"
    fi
    idx=$((idx + 1))
  done
  wait
  idx=0
  for r in "${runs[@]}"; do
    set -- $r
    IFS='|' read -r c t s res secs log < "$resdir/$(printf %05d $idx)"
    printf '%-10s %-14s %10s  %-6s %5ss  %s\n' "$c" "$t" "$s" "$res" "$secs" "${log#$REPO_ROOT/}" | tee -a "$summary"
    n_runs=$((n_runs + 1))
    [ -f "$log" ] && logs+=("$log")
    if [ "$res" != PASS ]; then
      n_fail=$((n_fail + 1)); fail=1
      pa=$(join_args "${t_args[$1]}" "$user_plusargs")
      rerun+=("make -C ${ip_dir#$REPO_ROOT/} sim$(echo "${cfg_vars[$c]}") TEST=$t SEED=$s${pa:+ PLUSARGS=\"$pa\"}")
    fi
    idx=$((idx + 1))
  done
  rm -rf "$resdir"
done

# ---- cover properties: 'COVER: <label> <count>' summed over the runs of this regression --
if [ ${#logs[@]} -gt 0 ] && grep -qh '^COVER: ' "${logs[@]}" 2>/dev/null; then
  {
    echo
    echo "# cover properties (hits summed over ${#logs[@]} runs)"
    grep -h '^COVER: ' "${logs[@]}" | awk '{n[$2] += $3} END {for (c in n) printf "%-28s %10d%s\n", c, n[c], (n[c] == 0 ? "  NOT HIT" : "")}' | sort
  } | tee -a "$summary"
  if [ "$cover_check" = 1 ] && grep -q 'NOT HIT' "$summary"; then
    echo "regress: cover properties never hit (see above)" | tee -a "$summary"; fail=1
  fi
fi

{
  echo
  echo "TOTAL: $n_runs runs, $((n_runs - n_fail)) passed, $n_fail failed  ($(( $(date +%s) - start_all ))s)"
  for c in "${rerun[@]}"; do echo "rerun: $c"; done
  echo "regress: $([ $fail -eq 0 ] && echo PASS || echo FAIL) ($ip)  summary: ${summary#$REPO_ROOT/}"
} | tee -a "$summary"
exit $fail
