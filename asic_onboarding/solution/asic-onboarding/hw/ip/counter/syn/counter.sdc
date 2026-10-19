# hw/ip/counter/syn/counter.sdc -- constraints for counter (flow check of P1/P2 on the L0 block)
# Read by OpenSTA, PrimeTime and Fusion Compiler. The period comes from make
# (CLK_PERIOD); the library-dependent values (driving cell, load) come from
# flow/mk/syn.mk (SDC_DRIVE_CELL, SDC_DRIVE_PIN, SDC_LOAD), defaults are sky130.
proc sdc_env {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
    return $default
}
set period     $::env(CLK_PERIOD)                    ;# ns, from make CLK_PERIOD=...
set io_delay   [expr {0.2 * $period}]                ;# 20% of the cycle used outside the block
set drive_cell [sdc_env SDC_DRIVE_CELL sky130_fd_sc_hd__inv_2]
set drive_pin  [sdc_env SDC_DRIVE_PIN  Y]
set out_load   [sdc_env SDC_LOAD       0.01]         ;# library cap units: a few cell inputs

create_clock -name clk -period $period [get_ports clk]
set_clock_uncertainty 0.10 [get_clocks clk]          ;# margin for jitter and future clock skew
set_clock_transition  0.15 [get_clocks clk]          ;# slew of the ideal clock

# All inputs except the clock (rst_n keeps its delay: it gives recovery/removal a check).
# Collections (PrimeTime, FC) need remove_from_collection; OpenSTA returns Tcl lists.
if {[llength [info commands remove_from_collection]]} {
    set non_clk_in [remove_from_collection [all_inputs] [get_ports clk]]
} else {
    set non_clk_in [lsearch -inline -all -not -exact [all_inputs] [get_ports clk]]
}
set_input_delay  $io_delay -clock clk $non_clk_in
set_output_delay $io_delay -clock clk [all_outputs]

set_driving_cell -lib_cell $drive_cell -pin $drive_pin $non_clk_in   ;# inputs driven by a real inverter
set_load $out_load [all_outputs]
set_max_fanout 20 [current_design]                   ;# design rule, reported by the DRV check
