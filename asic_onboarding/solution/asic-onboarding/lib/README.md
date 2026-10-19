# lib/

Standard-cell libraries used from Lab P1 on. Provided by the coordinator, **never
committed** (`lib/*.lib`, `lib/*.db` are in .gitignore). `env.sh` / `env.csh` point the
flow at them through four variables:

| Variable | Used by | Default |
|---|---|---|
| `LIB_STD` | Yosys, OpenSTA (Liberty text); `lib2v.py` / `lib2lef.py` | `lib/sky130_fd_sc_hd__tt_025C_1v80.lib` |
| `LIB_DB`  | Fusion Compiler, PrimeTime, Formality (compiled `.db`) | `lib/sky130_fd_sc_hd__tt_025C_1v80.db` |
| `LIB_NDM`, `LIB_TF` | Fusion Compiler: NDM cell library + technology file of a real PDK | empty (bring-up library, see below) |
| `LIB_VERILOG` | `make gls`: the library's own Verilog cell models | empty (models generated from `LIB_STD`) |

## Synopsys cloud: `class.db` bring-up library (default there)

When the sky130 files are absent, `env.sh` falls back to the generic Synopsys training
library shipped with Design Compiler:
`/global/apps/syn/2025.06-SP4/libraries/syn/class.{lib,db}`.

It is **a flow bring-up library, not a technology**: ~100 cells (`IV`, `ND2`, `AO2`,
`MUX21H`, `FD1` D flip-flop, `FD2` with asynchronous clear, `FD4` with preset, ...), a
5 V *linear* delay model (intrinsic delay + resistance x load, no NLDM tables), area
without a unit, capacitance unit 0.1 fF, **no recovery/removal arcs** (the P2
recovery/removal reports are empty with it) and no Verilog models. Every number
obtained with it is in "class units" and much slower than sky130/SAED32: compare
trends between designs and configurations, never absolute values with the lab text.

What the flow does to make it usable (no action needed):

* **Fusion Compiler** links only NDM reference libraries with technology data and a
  physical view per cell. `flow/scripts/lib2lef.py` writes a placeholder LEF from
  `LIB_STD` into `build/lib/class.lef` (CLASS CORE macros on one dummy site, width from
  the Liberty area) and `flow/syn/fc_synth.tcl` creates the design library with
  `flow/syn/fc_bringup.tf` + that LEF; FC builds the NDM itself (library configuration).
  Synthesis runs non-physical (`set_non_physical_mode`, `compile_logical`): the dummy
  geometry is never used, area and timing come from the `.db`.
* **GLS** needs Verilog models: `flow/scripts/lib2v.py` writes zero-delay models of all
  cells from the Liberty `function` / `ff` / `latch` groups into `build/lib/class_cells.v`.
* **PrimeTime** and **Formality** read `class.db` directly.

## SAED32 (installed on the Synopsys cloud with the Lynx flow)

The Synopsys educational 32 nm library is available read-only under
`/global/apps/lynxnxt/2024.09/fpm_FC_saed32/SAED32_data/lib/` (rvt, lvt, hvt standard
cells with `.lib`/`.db` at many PVT corners, NDM, LEF, technology file, Verilog models,
and SRAM macros 32x32 / 64x32 / 2048x32 under `srams/`). To use it instead of `class`
(typical corner, regular Vt), after `source env.sh`:

```sh
S=/global/apps/lynxnxt/2024.09/fpm_FC_saed32/SAED32_data/lib/rvt
export LIB_STD=$S/liberty/db_nldm/saed32rvt_tt1p05v25c.lib
export LIB_DB=$S/liberty/db_nldm/saed32rvt_tt1p05v25c.db
export LIB_NDM=$S/ndm/saed32rvt_base_frame_timing.ndm
export LIB_TF=$S/ndm/tf/saed32nm_1p9m_mw.tf
export LIB_VERILOG=$S/verilog/saed32nm.v
```

(csh: `setenv` instead of `export`.) `syn.mk` then uses the SAED32 NDM directly, sets the
SDC driving cell to `INVX2_RVT` (pin `Y`) and the output load to 4 fF, and `make gls`
simulates with the foundry models. Verified on `counter` (synth, sta, gls). The build
directory does not encode the library: switching re-synthesizes in place (the synthesis
command line is a prerequisite), so run `make clean` or keep one library per session if
you want to keep both results.

## Team PDK / sky130

Put the files here with the sky130 names (or set the variables after sourcing env.sh).
For a PDK with NDM, set `LIB_NDM`/`LIB_TF`; with `.db` only, the bring-up path above is
used automatically. Add the driving cell of the PDK to the library table at the top of
`flow/mk/syn.mk` (`SDC_DRIVE_CELL`, `SDC_DRIVE_PIN`, `SDC_LOAD`) or pass them on the make
command line.
