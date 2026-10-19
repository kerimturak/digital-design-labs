#!/usr/bin/env bash
# flow/scripts/sweep.sh <configs.txt> <out.csv> <start_period_ns>        (Lab P3)
# Called by 'make sweep' from a block directory; needs DUT_TOP (and MAKE) in the
# environment. For every PARAMS line of configs.txt ('#' comments, blank lines ignored):
#   1. make synth sta PARAMS=<line> CLK_PERIOD=<p>, iterated T <- T - slack until the
#      setup slack is ~0 (the SDC scales the I/O delays with T, so one step is exact only
#      for register-to-register paths; the error shrinks by the I/O fraction per step)
#   2. one more sta at the final period, to verify it (that run's slack is in the CSV)
#   3. one CSV row from the key/value summaries written by syn.mk and sta.mk
# It does not know where the build directories are or which tools run: it asks make
# (print-SYN_DIR / print-STA_DIR) and reads <top>_summary.txt / <top>_p<T>_summary.txt,
# which every SYN_TOOL / STA_TOOL branch writes in the same format.
set -euo pipefail
cfgs=$1; csv=$2; start=$3
make=${MAKE:-make}
top=${DUT_TOP:?DUT_TOP not set}
tol=0.005          # ns: stop when |slack| is below this
maxit=8

kv() { awk -v k="$1" '$1 == k { $1 = ""; sub(/^ /, ""); print; exit }' "$2"; }

echo "params,cells,flops,area,seq_fraction,tmin_ns,fmax_mhz,slack_at_tmin,startpoint,endpoint,path_type,library" > "$csv"
grep -v -E '^\s*(#|$)' "$cfgs" | while read -r params; do
  syn_dir=$($make -s --no-print-directory print-SYN_DIR PARAMS="$params")
  sta_dir=$($make -s --no-print-directory print-STA_DIR PARAMS="$params")
  p=$start
  for ((i = 1; i <= maxit; i++)); do
    $make -s --no-print-directory synth sta PARAMS="$params" CLK_PERIOD="$p" > /dev/null
    slack=$(kv slack_max "$sta_dir/${top}_p${p}_summary.txt")
    next=$(awk -v p="$p" -v s="$slack" 'BEGIN { n = p - s; if (n < 0.05) n = 0.05; printf "%.3f", n }')
    echo "sweep: $params  iteration $i  T=$p  slack=$slack  -> T=$next"
    done_=$(awk -v s="$slack" -v t="$tol" 'BEGIN { print (s < t && s > -t) ? 1 : 0 }')
    p=$next
    [ "$done_" = 1 ] && break
  done
  # verification run at the final period
  $make -s --no-print-directory sta PARAMS="$params" CLK_PERIOD="$p" > /dev/null
  sum=$sta_dir/${top}_p${p}_summary.txt
  syn=$syn_dir/${top}_summary.txt
  fmax=$(awk -v p="$p" 'BEGIN { printf "%.1f", 1000 / p }')
  echo "\"$params\",$(kv cells "$syn"),$(kv flops "$syn"),$(kv area "$syn"),$(kv seq_fraction "$syn"),$p,$fmax,$(kv slack_max "$sum"),$(kv startpoint "$sum"),$(kv endpoint "$sum"),$(kv path_type "$sum"),$(kv library "$syn")" >> "$csv"
  echo "sweep: $params  Tmin=$p ns  Fmax=$fmax MHz  (verified slack $(kv slack_max "$sum"))"
done
echo "sweep: $csv"
