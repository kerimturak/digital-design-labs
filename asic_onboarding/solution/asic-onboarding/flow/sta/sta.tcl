# flow/sta/sta.tcl -- generic OpenSTA script (Lab P2, STA_TOOL=opensta)
# Run by flow/mk/sta.mk as:  sta -no_init -exit sta.tcl
# Environment: DUT_TOP NETLIST LIB (Liberty) SDC STA_OUT (report prefix) CLK_PERIOD
#              SDC_DRIVE_CELL SDC_DRIVE_PIN SDC_LOAD (read by the SDC)
# NOTE: OpenSTA is not installed on the Synopsys cloud; there the same reports come from
# PrimeTime (flow/sta/pt_sta.tcl, STA_TOOL=pt). This script follows the lab text and is
# kept for machines with the open-source tools.
set top $::env(DUT_TOP)
set out $::env(STA_OUT)                ;# prefix of the report files

read_liberty $::env(LIB)
read_verilog $::env(NETLIST)
link_design  $top
read_sdc     $::env(SDC)               ;# the SDC reads CLK_PERIOD itself
set sta_recovery_removal_checks_enabled 1

check_setup -verbose                                         > ${out}_check_setup.rpt
report_checks -path_delay max -group_path_count 5 -digits 3 \
    -fields {slew cap input_pins nets fanout}                > ${out}_setup.rpt
report_checks -path_delay min -group_path_count 5 -digits 3  > ${out}_hold.rpt
report_checks -path_delay max -to [all_registers -async_pins] > ${out}_recovery.rpt
report_checks -path_delay min -to [all_registers -async_pins] > ${out}_removal.rpt
report_check_types -max_slew -max_capacitance -max_fanout -violators > ${out}_drv.rpt

# one-line summaries on stdout (sta.mk turns them into <out>_summary.txt for sweep.sh)
report_worst_slack -max -digits 3
report_worst_slack -min -digits 3
report_wns -digits 3
report_tns -digits 3
report_clock_min_period
