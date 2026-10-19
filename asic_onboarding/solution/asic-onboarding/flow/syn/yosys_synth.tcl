# flow/syn/yosys_synth.tcl -- generic synthesis script (Lab P1, SYN_TOOL=yosys)
# Run by flow/mk/syn.mk as:  yosys -c yosys_synth.tcl
# Environment: DUT_TOP SYN_SRC (single Verilog-2005 file written by sv2v) LIB (Liberty)
#              SYN_DIR SYN_PARAMS ("WIDTH=8 DEPTH=16") SYN_FLATTEN (1 default, 0 keep hierarchy)
# NOTE: Yosys and sv2v are not installed on the Synopsys cloud; there synthesis runs in
# Fusion Compiler (flow/syn/fc_synth.tcl, SYN_TOOL=fc). This script follows the lab text
# and is kept for machines with the open-source tools. The tie-cell names of hilomap are
# sky130's; with another library set SYN_TIECELL="<cell> <hi pin> <lo pin>".
yosys -import
set top  $::env(DUT_TOP)
set src  $::env(SYN_SRC)
set lib  $::env(LIB)
set out  $::env(SYN_DIR)
set prms [expr {[info exists ::env(SYN_PARAMS)]  ? $::env(SYN_PARAMS)  : ""}]
set flat [expr {[info exists ::env(SYN_FLATTEN)] ? $::env(SYN_FLATTEN) : 1}]
set tie  [expr {[info exists ::env(SYN_TIECELL)] ? $::env(SYN_TIECELL) : "sky130_fd_sc_hd__conb_1 HI LO"}]

# 1. Read and elaborate with the requested parameter values (PARAMS)
read_verilog -defer $src
set chp {}
foreach p $prms { lassign [split $p =] n v; lappend chp -chparam $n $v }
hierarchy -check -top $top {*}$chp
yosys rename -top $top          ;# plain module name, whatever the PARAMS

# 2. Generic synthesis (Yosys internal gates)
set sargs [list -top $top]
if {$flat} { lappend sargs -flatten }
synth {*}$sargs
tee -o $out/${top}_stat_generic.rpt stat
write_verilog -noattr $out/${top}_generic.v

# 3. Technology mapping to the Liberty library
dfflibmap -liberty $lib
abc -liberty $lib
setundef -zero
lassign $tie tcell thi tlo
hilomap -singleton -hicell $tcell $thi -locell $tcell $tlo
splitnets
opt_clean -purge
check
tee -o $out/${top}_stat.rpt stat -liberty $lib
write_verilog -noattr -noexpr -nohex -nodec $out/${top}.v
write_verilog $out/${top}_src.v ;# keeps (* src *) attributes, for mapping to RTL
