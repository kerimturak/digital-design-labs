# flow/sta/pt_sta.tcl -- generic PrimeTime script (Lab P2, STA_TOOL=pt).
# Run by flow/mk/sta.mk as:  pt_shell -f pt_sta.tcl < /dev/null    (cwd = STA_DIR/pt)
# Environment: DUT_TOP NETLIST LIB_DB SDC STA_OUT (report prefix) CLK_PERIOD
#              SDC_DRIVE_CELL SDC_DRIVE_PIN SDC_LOAD (read by the SDC)
# Same reports as the OpenSTA script flow/sta/sta.tcl, PrimeTime commands:
#   <out>_check_setup.rpt  check_timing (unconstrained endpoints, missing clocks)
#   <out>_setup.rpt        report_timing -delay_type max, 5 worst endpoints
#   <out>_hold.rpt         report_timing -delay_type min
#   <out>_recovery.rpt     async reset release checks (setup-like)
#   <out>_removal.rpt      async reset release checks (hold-like)
#   <out>_drv.rpt          report_constraint: max_transition / max_capacitance / max_fanout
#   <out>_qor.rpt          report_qor (WNS, TNS, violating paths, cell counts per group)
#   <out>_summary.txt      key/value numbers for sweep.sh

set top $::env(DUT_TOP)
set out $::env(STA_OUT)

set search_path [list . [file dirname $::env(LIB_DB)]]
set link_path   [list * $::env(LIB_DB)]
read_verilog $::env(NETLIST)
link_design  $top
source -echo $::env(SDC)
# Same wire-load model as synthesis when one was chosen (SYN_WIRE_LOAD, see syn.mk);
# otherwise PrimeTime selects the library's model automatically (class.lib: by area).
if {[info exists ::env(SYN_WIRE_LOAD)] && $::env(SYN_WIRE_LOAD) ne ""} {
    set_wire_load_model -name $::env(SYN_WIRE_LOAD)
}
# Recovery/removal arcs of the asynchronous reset pins are timed (PrimeTime default;
# set explicitly because the lab asks for those checks).
set_app_var timing_disable_recovery_removal_checks false
update_timing -full

redirect ${out}_check_setup.rpt { check_timing -verbose }
redirect ${out}_setup.rpt {
    report_timing -delay_type max -max_paths 5 -nworst 1 -slack_lesser_than 1e9 -input_pins -nets \
        -transition_time -capacitance -significant_digits 3 -nosplit
}
redirect ${out}_hold.rpt {
    report_timing -delay_type min -max_paths 5 -nworst 1 -slack_lesser_than 1e9 -input_pins -significant_digits 3 -nosplit
}
# Asynchronous checks are in the path group **async_default** (no group: no async pins).
set has_async [sizeof_collection [get_path_groups -quiet **async_default**]]
redirect ${out}_recovery.rpt {
    if {$has_async} { report_timing -group **async_default** -delay_type max -max_paths 3 -slack_lesser_than 1e9 -significant_digits 3 -nosplit } \
    else { puts "no recovery checks: no asynchronous reset/set pins, or the library has no recovery/removal arcs" }
}
redirect ${out}_removal.rpt {
    if {$has_async} { report_timing -group **async_default** -delay_type min -max_paths 3 -slack_lesser_than 1e9 -significant_digits 3 -nosplit } \
    else { puts "no removal checks: no asynchronous reset/set pins, or the library has no recovery/removal arcs" }
}
redirect ${out}_drv.rpt {
    report_constraint -all_violators -max_transition -max_capacitance -max_fanout -nosplit
}
redirect ${out}_qor.rpt { report_qor }

# --- summary ------------------------------------------------------------------------
# Setup: worst path over the clock group (register and port paths); recovery is kept
# separate (it is reset release, not the data path that limits Fmax).
proc path_info {path} {
    set sp [get_attribute $path startpoint]
    set ep [get_attribute $path endpoint]
    set a [expr {[get_attribute $sp object_class] eq "port" ? "in" : "reg"}]
    set b [expr {[get_attribute $ep object_class] eq "port" ? "out" : "reg"}]
    # report instance names (the flip-flop), as OpenSTA's Startpoint:/Endpoint: lines do
    set spn [expr {$a eq "in"  ? [get_object_name $sp] : [get_object_name [get_cells -of_objects $sp]]}]
    set epn [expr {$b eq "out" ? [get_object_name $ep] : [get_object_name [get_cells -of_objects $ep]]}]
    return [list $spn $epn ${a}2${b}]
}
set clk_groups [get_path_groups -quiet [get_object_name [all_clocks]]]
set pmax [get_timing_paths -delay_type max -max_paths 1 -slack_lesser_than 1e9 -group $clk_groups]
set pmin [get_timing_paths -delay_type min -max_paths 1 -slack_lesser_than 1e9 -group $clk_groups]
# Several clocks (e.g. T-RTL1 async_fifo): one path per group comes back -> keep the worst.
set pmax [index_collection [sort_collection $pmax slack] 0]
set pmin [index_collection [sort_collection $pmin slack] 0]
set smax [get_attribute $pmax slack]
set smin [get_attribute $pmin slack]
set tns 0.0
foreach_in_collection p [get_timing_paths -delay_type max -max_paths 100000 -nworst 1 \
                            -slack_lesser_than 0 -group $clk_groups] {
    set tns [expr {$tns + [get_attribute $p slack]}]
}
lassign [path_info $pmax] sp ep ptype
set fh [open ${out}_summary.txt w]
puts $fh "tool pt"
puts $fh "period $::env(CLK_PERIOD)"
puts $fh [format "slack_max %.3f" $smax]
puts $fh [format "tns %.3f" $tns]
puts $fh [format "slack_min %.3f" $smin]
puts $fh "startpoint $sp"
puts $fh "endpoint $ep"
puts $fh "path_type $ptype"
puts $fh [format "arrival %.3f" [get_attribute $pmax arrival]]
close $fh
puts [format "pt_sta: %s period=%s setup slack=%.3f tns=%.3f hold slack=%.3f critical %s -> %s (%s)" \
          $top $::env(CLK_PERIOD) $smax $tns $smin $sp $ep $ptype]
exit
