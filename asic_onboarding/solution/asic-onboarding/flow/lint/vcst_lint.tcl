# flow/lint/vcst_lint.tcl -- generic VC SpyGlass lint run in vc_static_shell, used by
# flow/mk/lint.mk with LINT_TOOL=vcst. Block-independent; inputs from the environment:
#   LINT_FLAT    flat file list (+incdir+, +define+, absolute files)
#   LINT_TOP     top module
#   LINT_PARAMS  space-separated NAME=VALUE overrides of LINT_TOP (may be empty)
#   LINT_DEFINES space-separated NAME[=VALUE] macros (may be empty)
#   LINT_GOAL    lint goal (default lint_rtl)
#   LINT_WAIVER  optional waiver Tcl file (waive_lint commands), sourced before check_lint
#   LINT_REPORT  report file to write
# vc_static_shell runs in build/<ip>/<cfg>/lint/vcst (vcst_rtdb, logs land there).

set top  $::env(LINT_TOP)
set goal [expr {[info exists ::env(LINT_GOAL)] && $::env(LINT_GOAL) ne "" ? $::env(LINT_GOAL) : "lint_rtl"}]

set search_path "."
set link_library " "
set_app_var enable_lint true
configure_lint_methodology -path $::env(VC_STATIC_HOME)/auxx/monet/tcl/GuideWare/block/rtl_handoff/lint/ -goal $goal
configure_lint_setup -goal $goal

set defs ""
foreach d [split [string trim $::env(LINT_DEFINES)]] {
  if {$d ne ""} { append defs " +define+$d" }
}
set pvals ""
foreach p [split [string trim $::env(LINT_PARAMS)]] {
  if {$p ne ""} { append pvals " -pvalue+$top.$p" }
}

analyze -format sverilog -vcs "-f $::env(LINT_FLAT)$defs"
elaborate $top -vcs "$pvals"

if {[info exists ::env(LINT_WAIVER)] && $::env(LINT_WAIVER) ne ""} {
  source $::env(LINT_WAIVER)
}
check_lint
report_violations -app {lint} -verbose -file $::env(LINT_REPORT)
quit
