# flow/syn/fc_synth.tcl -- generic Fusion Compiler logic synthesis (Lab P1, SYN_TOOL=fc).
# Run by flow/mk/syn.mk as:   fc_shell -f fc_synth.tcl < /dev/null   (cwd = SYN_DIR/fc_<top>)
# Design-independent: everything comes from the environment (set by syn.mk):
#
#   DUT_TOP      module to synthesize               SYN_DIR     output directory
#   SYN_FLAT     flat file list (+incdir+, +define+, absolute files; flist_expand.sh --flat)
#   SYN_PARAMS   "WIDTH=8 DEPTH=16" (PARAMS)          SYN_DEFINES "MUL_XLEN=8" (DEFINES)
#   SYN_IF_PARAMS  parameters of interface ports of the top: "cpu.AW=10 cpu.DW=32"
#   SYN_FLATTEN  1: flatten (default)  0: keep the hierarchy (per-module area, Lab P3)
#   LIB_DB       compiled Liberty (.db) used for mapping and timing
#   LIB_NDM      optional: NDM cell library of a real PDK (SAED32, team PDK), with LIB_TF
#                its technology file. If empty, a
#                bring-up NDM is built on the fly from LIB_DB + SYN_LEF + SYN_TF:
#   SYN_LEF      placeholder LEF from flow/scripts/lib2lef.py      SYN_TF  flow/syn/fc_bringup.tf
#   SYN_SDC      constraints (the IP's syn/<ip>.sdc); empty: 10 ns clock on port clk
#   CLK_PERIOD   period read by the SDC (syn.mk passes SYN_CLK_PERIOD)
#
# Outputs in SYN_DIR, all named by DUT_TOP:
#   <top>.v               mapped netlist (input of gls, sta, lec)
#   <top>.svf             guidance for Formality (make lec)
#   <top>_qor.rpt  <top>_area.rpt  <top>_stat.rpt (cell references)  <top>_timing.rpt
#   <top>_check.rpt       check_design / unconstrained / latches
#   <top>_summary.txt     key/value numbers read by sweep.sh (cells flops latches area ...)
# The script exits with an error (non-zero status via syn.mk) on any latch.

proc env_or {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
    return $default
}
set top     $::env(DUT_TOP)
set out     $::env(SYN_DIR)
set flat_f  $::env(SYN_FLAT)
set prms    [env_or SYN_PARAMS ""]
# Parameters of interface ports of the top module ("cpu.AW=10 cpu.DW=32"): elaborate does
# not derive them from the module parameters, an interface port keeps its own defaults.
set ifprms  [env_or SYN_IF_PARAMS ""]
set defs    [env_or SYN_DEFINES ""]
set flatten [env_or SYN_FLATTEN 1]
set lib_db  $::env(LIB_DB)
set lib_ndm [env_or LIB_NDM ""]
set sdc     [env_or SYN_SDC ""]

# --- 1. Libraries -------------------------------------------------------------------
# Logical synthesis only: no floorplan, zero wire load, compile_logical.
set_non_physical_mode
set_app_options -name lib.configuration.local_output_dir -value [pwd]/clib
set search_path   [list . [file dirname $lib_db]]
set link_library  [list * $lib_db]
set target_library [list $lib_db]
if {$lib_ndm ne ""} {
    # Real PDK: NDM cell libraries (frames + timing) and the technology file (LIB_TF).
    set targs {}
    if {[env_or LIB_TF ""] ne ""} { set targs [list -technology $::env(LIB_TF)] }
    create_lib {*}$targs -ref_libs $lib_ndm ${top}_lib
} else {
    # Bring-up library (.db only): FC builds the NDM itself from the placeholder LEF and
    # the .db (library configuration, lm_shell); see lib2lef.py and fc_bringup.tf.
    create_lib -technology $::env(SYN_TF) -ref_libs [list $::env(SYN_LEF)] ${top}_lib
}
set_svf $out/${top}.svf

# --- 2. Read and elaborate ----------------------------------------------------------
set files {}
set incdirs {}
set fdefs [list SYNTHESIS]
foreach d $defs { lappend fdefs $d }
set fh [open $flat_f r]
foreach line [split [read $fh] "\n"] {
    set line [string trim $line]
    if {$line eq "" || [string match "//*" $line] || [string match "#*" $line]} { continue }
    if {[regexp {^\+incdir\+(.*)$} $line -> d]} { lappend incdirs {*}[split $d +]; continue }
    if {[regexp {^\+define\+(.*)$} $line -> d]} { lappend fdefs {*}[split $d +]; continue }
    lappend files $line
}
close $fh
set search_path [concat $incdirs $search_path]
analyze -format sverilog -define $fdefs $files

set eargs {}
set allprms [concat $prms $ifprms]
if {$allprms ne ""} { lappend eargs -parameters [join $allprms ","] }
elaborate $top {*}$eargs
# elaborate names the design <top>_<P1><V1>... ; synthesize it under the plain name, so
# the testbench instantiates the netlist exactly like the RTL (only parameters differ).
set elab [regsub {\.design$} [regsub {^.*:} [get_object_name [current_design]] ""] ""]
set_top_module $elab
if {$elab ne $top} { rename_module $elab $top }

# --- 3. Constraints -----------------------------------------------------------------
if {$sdc ne ""} {
    source -echo $sdc
} else {
    create_clock -name clk -period 10.0 [get_ports clk]
}
# Wire load: PrimeTime applies the library's wire-load model to every net (class.lib:
# selection by area); FC's logical flow uses zero interconnect. SYN_WIRE_LOAD=<model>
# asks FC to use the same model during synthesis (see flow/README.md).
if {[env_or SYN_WIRE_LOAD ""] ne ""} { set_wire_load_model -name $::env(SYN_WIRE_LOAD) }
# No test-ready (scan) mapping: plain flip-flops, as in the Yosys flow (FC would otherwise
# map every register to a scan flip-flop, ready for DFT insertion).
set regs [all_registers]
if {[sizeof_collection $regs] > 0} { set_scan_element false $regs }

# --- 4. Synthesis -------------------------------------------------------------------
if {$flatten} {
    if {[sizeof_collection [get_cells -quiet -filter "is_hierarchical==true"]] > 0} {
        ungroup_cells -all -flatten
    }
} else {
    set_app_options -name compile.flow.autoungroup -value false
}
compile_logical
change_names -rules verilog -hierarchy

# --- 5. Checks and reports ----------------------------------------------------------
set latches [all_registers -level_sensitive]
set nlatch  [sizeof_collection $latches]
redirect $out/${top}_check.rpt {
    puts "=== check_design"
    check_design -checks {design_mismatch}
    puts "=== check_timing (unconstrained endpoints, missing clocks)"
    check_timing
    puts "=== latches: $nlatch"
    foreach_in_collection l $latches { puts "  latch [get_object_name $l] ([get_attribute $l ref_name])" }
}
redirect $out/${top}_qor.rpt    { report_qor }
redirect $out/${top}_area.rpt   { if {$flatten} { report_area } else { report_area -hierarchy } }
redirect $out/${top}_stat.rpt   { report_reference -nosplit }
redirect $out/${top}_timing.rpt { report_timing -max_paths 5 -nosplit }

# key/value summary for sweep.sh: same keys in every SYN_TOOL branch
set leaves  [get_cells -hierarchical -filter "is_hierarchical==false"]
set seqs    [filter_collection $leaves "is_sequential==true"]
set area 0.0
set seq_area 0.0
foreach_in_collection c $leaves { set area [expr {$area + [get_attribute $c area]}] }
foreach_in_collection c $seqs   { set seq_area [expr {$seq_area + [get_attribute $c area]}] }
set fh [open $out/${top}_summary.txt w]
puts $fh "tool fc"
puts $fh "library [file rootname [file tail $lib_db]]"
puts $fh "cells [sizeof_collection $leaves]"
puts $fh "flops [expr {[sizeof_collection $seqs] - $nlatch}]"
puts $fh "latches $nlatch"
puts $fh [format "area %.3f" $area]
puts $fh [format "seq_area %.3f" $seq_area]
puts $fh [format "seq_fraction %.3f" [expr {$area > 0 ? $seq_area / $area : 0}]]
close $fh

write_verilog -exclude {pg_objects physical_only_cells} $out/${top}.v
set_svf -off
puts "fc_synth: $top -> $out/${top}.v  cells=[sizeof_collection $leaves] area=[format %.3f $area] latches=$nlatch"
if {$nlatch > 0} {
    puts "Error: fc_synth: $nlatch latch(es) inferred in $top, see $out/${top}_check.rpt"
    exit 1
}
exit 0
