# flow/syn/fm_lec.tcl -- generic Formality equivalence check RTL vs netlist (Lab P1, optional).
# Run by flow/mk/syn.mk (make lec) as:  fm_shell -f fm_lec.tcl < /dev/null   (cwd = SYN_DIR/lec)
# Environment: DUT_TOP SYN_FLAT (flat RTL list) SYN_PARAMS SYN_DEFINES NETLIST LIB_DB
#              SVF (optional: guidance file written by Fusion Compiler)
# Prints "lec: SUCCEEDED" or "lec: FAILED" (syn.mk decides PASS/FAIL on that line).

proc env_or {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
    return $default
}
set top  $::env(DUT_TOP)
set prms [env_or SYN_PARAMS ""]
set svf  [env_or SVF ""]

# SVF guidance (register merging, inverted/constant registers, renaming) from the
# synthesis tool; synopsys_auto_setup applies the matching default settings.
set_app_var synopsys_auto_setup true
if {$svf ne "" && [file exists $svf]} { set_svf $svf }

read_db $::env(LIB_DB)

# Reference: the RTL, with the same SYNTHESIS define and parameters as synthesis.
set files {}
set incdirs {}
set defs [list SYNTHESIS {*}[env_or SYN_DEFINES ""]]
set fh [open $::env(SYN_FLAT) r]
foreach line [split [read $fh] "\n"] {
    set line [string trim $line]
    if {$line eq "" || [string match "//*" $line]} { continue }
    if {[regexp {^\+incdir\+(.*)$} $line -> d]} { lappend incdirs {*}[split $d +]; continue }
    if {[regexp {^\+define\+(.*)$} $line -> d]} { lappend defs {*}[split $d +]; continue }
    lappend files $line
}
close $fh
set_app_var search_path [concat $incdirs [get_app_var search_path]]
read_sverilog -r -define [join $defs " "] $files
if {$prms ne ""} {
    set_top r:/WORK/$top -parameter "{ [join [lmap p $prms {string map {= " = "} $p}] {, }] }"
} else {
    set_top r:/WORK/$top
}

# Implementation: the mapped netlist.
read_verilog -i $::env(NETLIST)
set_top i:/WORK/$top

match
report_unmatched_points -summary
set ok [verify]
report_failing_points
report_status
puts [expr {$ok ? "lec: SUCCEEDED ($top: RTL == netlist)" : "lec: FAILED ($top)"}]
exit
