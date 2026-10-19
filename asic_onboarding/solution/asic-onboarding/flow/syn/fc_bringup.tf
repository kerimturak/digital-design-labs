/* flow/syn/fc_bringup.tf -- minimal Synopsys technology file for LOGIC synthesis with
 * Fusion Compiler when the library has no technology file / LEF / NDM (e.g. the generic
 * class.db used for flow bring-up on the Synopsys cloud).
 *
 * Fusion Compiler only links reference libraries that carry technology data and a
 * physical view of every cell. fc_synth.tcl passes this file to create_lib together with
 * the placeholder LEF written by flow/scripts/lib2lef.py (site "bringup_core" below); FC
 * then builds the NDM cell library from LEF + .db itself. Units, one site and two routing
 * layers are all that create_lib/lm_shell require. Nothing here is a real process: the
 * flow runs non-physical (set_non_physical_mode, compile_logical, zero wire load), so no
 * geometry is ever used. A real PDK (SAED32, team PDK) brings its own .tf/NDM: set
 * LIB_NDM (see lib/README.md) and this file is not read.
 */
Technology {
  name                 = "bringup"
  unitLengthName       = "micron"
  lengthPrecision      = 10000
  gridResolution       = 5
  unitTimeName         = "ns"
  timePrecision        = 1000
  unitCapacitanceName  = "pf"
  capacitancePrecision = 1000
  unitResistanceName   = "kohm"
  resistancePrecision  = 1000
  unitVoltageName      = "V"
  voltagePrecision     = 1000
  unitCurrentName      = "mA"
  currentPrecision     = 1000
  unitPowerName        = "mw"
  powerPrecision       = 1000
  unitInductanceName   = "nh"
  inductancePrecision  = 100
}
Tile "bringup_core" {
  width  = 0.05
  height = 1.0
}
Layer "M1" {
  layerNumber  = 1
  maskName     = "metal1"
  pitch        = 0.2
  defaultWidth = 0.1
  minWidth     = 0.1
  minSpacing   = 0.1
  minArea      = 0.01
}
Layer "VIA1" {
  layerNumber  = 2
  maskName     = "via1"
  minWidth     = 0.1
  minSpacing   = 0.1
}
Layer "M2" {
  layerNumber  = 3
  maskName     = "metal2"
  pitch        = 0.2
  defaultWidth = 0.1
  minWidth     = 0.1
  minSpacing   = 0.1
  minArea      = 0.01
}
ContactCode "VIA12" {
  contactCodeNumber   = 1
  cutLayer            = "VIA1"
  lowerLayer          = "M1"
  upperLayer          = "M2"
  cutWidth            = 0.1
  cutHeight           = 0.1
  upperLayerEncWidth  = 0.02
  upperLayerEncHeight = 0.02
  lowerLayerEncWidth  = 0.02
  lowerLayerEncHeight = 0.02
  minCutSpacing       = 0.1
  isDefaultContact    = 1
}
