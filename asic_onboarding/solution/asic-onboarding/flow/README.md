# flow/

Design-independent build infrastructure: make rules (`mk/`), tool scripts (`lint/`,
`syn/`, `sta/`) and helper scripts (`scripts/`). **No file here may mention a block
name.** Adding a block never requires a change here. Owner: everyone, reviewed by the
coordinator.

```
flow/
├── mk/
│   ├── common.mk          paths, CFG tag, BUILD_DIR, file lists, tool selection, help, clean   (L0)
│   ├── lint.mk            lint: LINT_TOOL = verilator | spyglass | vcst | vcs                 (L0; vcs: T-MOD)
│   ├── sim_verilator.mk   build, sim, waves, cov with Verilator          (SIM=verilator)      (L0)
│   ├── sim_vcs.mk         build, sim, waves, cov with VCS/Verdi/URG      (SIM=vcs)            (L0, T-DV2 UVM)
│   ├── regress.mk         regress                                                              (V1)
│   ├── syn.mk             synth, gls: SYN_TOOL = yosys | fc                                    (P1)
│   ├── sta.mk             sta: STA_TOOL = opensta | pt                                         (P2)
│   └── cdc.mk             cdc: structural CDC check with SpyGlass CDC                          (T-RTL1)
├── lint/
│   ├── spyglass_lint.prj  SpyGlass lint/lint_rtl run (sg_shell -tcl), reads env vars          (L0)
│   └── vcst_lint.tcl      VC SpyGlass lint_rtl run (vc_static_shell), reads env vars          (L0)
├── cdc/
│   └── spyglass_cdc.prj   SpyGlass CDC run (sg_shell -tcl): goals, SGDC, reads env vars       (T-RTL1)
├── syn/
│   ├── yosys_synth.tcl    Yosys script (SYN_TOOL=yosys; not installed on the cloud)           (P1)
│   ├── fc_synth.tcl       Fusion Compiler script (SYN_TOOL=fc)                                (P1)
│   ├── fc_bringup.tf      minimal technology file: FC with a .db-only library                (P1)
│   └── fm_lec.tcl         Formality RTL-vs-netlist check (make lec)                           (P1)
├── sta/
│   ├── sta.tcl            OpenSTA script (STA_TOOL=opensta; not installed on the cloud)       (P2)
│   └── pt_sta.tcl         PrimeTime script (STA_TOOL=pt)                                      (P2)
└── scripts/
    ├── check_tools.sh     tool versions per phase (R|V|P), open-source and Synopsys columns    (L0)
    ├── flist_expand.sh    flattens a .f file (nested -f, ${REPO_ROOT}, +incdir+, +define+)     (L0)
    ├── regress.sh         runs a dv/regress.list through 'make build' / 'make sim' (regress.mk) (V1)
    ├── sweep.sh           synth/sta over a list of PARAMS sets                                 (P3)
    ├── plot_sweep.py      area / Fmax plots of a sweep CSV (PNG via matplotlib, else SVG)      (P3)
    ├── lib2v.py           zero-delay Verilog cell models from a .lib, for GLS                  (P1)
    ├── lib2lef.py         placeholder LEF from a .lib, for FC with a .db-only library          (P1)
    └── liberty.py         small Liberty reader used by lib2v.py / lib2lef.py                   (P1)
```

## Quick start

```sh
source env.sh                                  # bash/zsh  (csh/tcsh: source env.csh)
check_tools.sh R
make -C hw/ip/counter help                     # targets + variables with current values
make -C hw/ip/counter lint
make -C hw/ip/counter sim
make -C hw/ip/counter sim PARAMS="WIDTH=4 MAX=9" WAVES=1
make -C hw/ip/counter waves PARAMS="WIDTH=4 MAX=9"
make sim IP=counter TEST=smoke                 # same, from the repository root
make check-all                                 # lint + sim of every block, PASS/FAIL table
```

## Environment (`env.sh` / `env.csh`)

| Variable | Set to | Used by |
|---|---|---|
| `REPO_ROOT` | directory of env.sh (bash: `BASH_SOURCE`, zsh: `${(%):-%x}`; csh: `$_` or cwd) | everything |
| `LIB_DIR` | `$REPO_ROOT/lib` | P1+ |
| `LIB_STD` | `lib/sky130_fd_sc_hd__tt_025C_1v80.lib`; if absent and installed, the Synopsys generic `class.lib` | syn/sta (Liberty) |
| `LIB_DB` | `lib/sky130_fd_sc_hd__tt_025C_1v80.db`; if absent and installed, `class.db` | fc / pt (compiled .db) |
| `PATH` | + `$REPO_ROOT/flow/scripts` (+ cloud tool dirs, see below) | |
| `PYTHON` | first python3 >= 3.8 found (`python3`, `python3.12` … `python3.8`) | helper/plot scripts: call `$(PYTHON)`, not `python3` |
| `SIM` | `vcs` if `vcs` is in PATH, else `verilator` | common.mk |
| `LINT_TOOL` | `verilator` if Verilator >= 5.020, else `spyglass` (sg_shell), else `vcst`, else `verilator` | lint.mk |
| `SYN_TOOL` | `yosys` if installed, else `fc` if `fc_shell`, else `yosys` | syn.mk (P1) |
| `STA_TOOL` | `opensta` if `sta` installed, else `pt` if `pt_shell`, else `opensta` | sta.mk (P2) |

Every value already set in the environment is kept, and every one can be overridden on
the make command line (`make sim SIM=verilator`). `ENV_QUIET=1` silences the summary.

### Synopsys cloud defaults

The only machine-specific code in the repository is the clearly marked *Synopsys cloud
block* of `env.sh`/`env.csh`; each entry is guarded by an existence check, so the files
work unchanged elsewhere. **Makefiles never contain absolute tool paths.**

| Item | Location (added only if present and not already in PATH) |
|---|---|
| Verilator 5.013 | `/global/apps/freeware/verilator/5.013/bin` |
| GTKWave 3.3.115 | `/global/apps/freeware/gtkwave/3.3.115/bin` |
| VC Static (VC SpyGlass) | `/global/apps/vcstatic/2024.09-SP2-4/bin`, `VC_STATIC_HOME` |
| SpyGlass 2025.06-SP1 | `SPYGLASS_HOME=/global/apps/spyglass/2025.06-SP1/SPYGLASS_HOME`, `$SPYGLASS_HOME/bin` |
| PrimeTime / Fusion Compiler / Formality | `/global/apps/{pt/2025.06,fc/2025.06-SP1,fm/2026.03-SP2}/bin` |
| VCS / Verdi | already in PATH via the site setup |
| C++ for Verilator models | `VERILATOR_CXX=/global/apps/freeware/gcc/12.4.0/bin/g++`, `VERILATOR_LDFLAGS=-Wl,-rpath,…/lib64` (only when the default g++ is < 10: `--timing` needs C++20 coroutines; RHEL 8 has g++ 8.5; gcc-toolset-13 was rejected because it lacks `libatomic.so`) |
| Bring-up library | `LIB_STD=/global/apps/syn/2025.06-SP4/libraries/syn/class.lib`, `LIB_DB=…/class.db` |

On the cloud this gives `SIM=vcs LINT_TOOL=spyglass SYN_TOOL=fc STA_TOOL=pt`.
Design Compiler is **not** licensed there; only its library directory is used.
**`class.lib/.db` is a flow bring-up library, not a technology**: it lets synth/sta run
end to end. The coordinator substitutes SAED32 or the team PDK by putting the files in
`lib/` (sky130 names) or setting `LIB_STD`/`LIB_DB` after sourcing env.sh.

## Block Makefile contract

```make
# hw/ip/<ip>/Makefile -- set every variable BEFORE the includes
IP        := sync_fifo
DUT_TOP   := sync_fifo
TB_TOP    ?= tb_sync_fifo
RTL_FLIST := rtl/sync_fifo.f          # relative to the block directory, or absolute
TB_FLIST  ?= tb/tb.f                  # V phase: dv/dv.f with TB_TOP=tb_top
PARAMS    ?= WIDTH=8 DEPTH=16
TEST      ?= smoke
# SDC     := syn/sync_fifo.sdc       (P2)
include $(REPO_ROOT)/flow/mk/common.mk     # also includes sim_$(SIM).mk
include $(REPO_ROOT)/flow/mk/lint.mk
include $(REPO_ROOT)/flow/mk/sim_verilator.mk   # optional (L0 text); inert unless SIM=verilator
# include $(REPO_ROOT)/flow/mk/regress.mk   (V1)
# include $(REPO_ROOT)/flow/mk/syn.mk       (P1)
# include $(REPO_ROOT)/flow/mk/sta.mk       (P2)
```

All `.mk` files are include-guarded, so including one twice is harmless. Target
prerequisites are expanded when a `.mk` is read, which is why block variables must come
first. `hw/top/<top>/Makefile` follows the same contract (`IP := <top>`).

## Targets

| Target | File | Function |
|---|---|---|
| `help` | common.mk | targets and variables with their current values (default goal) |
| `clean` | common.mk | delete `build/<ip>/` (all configurations) |
| `lint` | lint.mk | lint `LINT_FLIST` with top `LINT_TOP` using `LINT_TOOL`; fails on Verilator warnings / SpyGlass errors |
| `build` | sim_*.mk | compile the model of `TB_TOP` (RTL + TB); rebuilt when sources, headers in incdirs, waivers or the command line change |
| `sim` | sim_*.mk | build if needed, run `TEST` with `SEED`, log to `build/<ip>/<cfg>/sim/<test>_s<seed>.log`; exit != 0 unless the run exits 0, the log has `TEST PASSED` and no `TEST FAILED` |
| `waves` | sim_*.mk | open the wave of the last `sim WAVES=1` run (same PARAMS/DEFINES): GTKWave (FST) or Verdi (FSDB) |
| `cov` | sim_*.mk | coverage report of `sim COV=1` runs: URG (vcs) or verilator_coverage |
| `check-all` | top Makefile | `CHECK_STEPS` (default `lint sim`) of every `hw/ip/*/Makefile`, `hw/top/*/Makefile` and `dv/model/*/Makefile`, PASS/FAIL table, logs in `build/check-all/`, exit != 0 on any failure |
| `regress` / `synth`, `gls` / `sta` / `sweep` | V1 / P1 / P2 / P3 | added by regress.mk, syn.mk, sta.mk |
| `cdc` | cdc.mk (T-RTL1) | SpyGlass CDC goals `CDC_GOALS` on `CDC_FLIST`/`CDC_TOP` with `CDC_SGDC`; fails on SpyGlass fatals/errors; `CDC_EXPECT=fail` inverts (negative test) |

Top level: `make <target> IP=<ip>` or `TOP=<top>` delegates to the block (IP/TOP are not
passed down; all other variables are). `IP=<name>` looks in `hw/ip/` first, then in
`hw/top/` (T-RTL2: `make sim IP=dcache_cdc_top`). Without IP/TOP: `help`, `clean` (all of build/),
`check-all`.

## Variables

| Variable | Default | Meaning |
|---|---|---|
| `IP`, `DUT_TOP`, `TB_TOP` | block / `$(IP)` / `tb_$(IP)` | block name, design top, testbench top |
| `RTL_FLIST`, `TB_FLIST` | `rtl/$(IP).f`, `tb/tb.f` | file lists (relative to the block dir or absolute) |
| `PARAMS` | — | `WIDTH=16 DEPTH=5`: TB-top parameter overrides (Verilator `-G`, VCS `-pvalue+<TB_TOP>.`); part of the CFG tag |
| `DEFINES` | — | `MUL_XLEN=8`: `+define+`; part of the CFG tag |
| `TEST` | `smoke` | `+TEST=`; with `UVM=1` also `+UVM_TESTNAME=` |
| `SEED` | random per make call (1 … 2^30), printed | `+SEED=` and `+verilator+seed+` / `+ntb_random_seed=` |
| `PLUSARGS` | — | extra runtime arguments, e.g. `+NUM_TXN=5000` |
| `WAVES` | `0` | `1`: Verilator FST (`--trace-fst`) / VCS FSDB (`-kdb -debug_access+all` + UCLI `fsdbDumpvars`) |
| `COV` | `0` | `1`: VCS `-cm $(COV_METRICS)` into `build/<ip>/<cfg>/cov/simv.vdb`, `-cm_name <test>_s<seed>`; Verilator `--coverage` |
| `COV_METRICS` | `line+cond+fsm+tgl+branch+assert` | VCS coverage metrics |
| `UVM` | `0` | `1`: `-ntb_opts uvm-1.2` (SIM=vcs only; error with Verilator) |
| `LINT_TOP`, `LINT_FLIST` | `DUT_TOP`, `RTL_FLIST` | lint a wrapper instead (R3: interface ports) |
| `LINT_PARAMS`, `LINT_DEFINES` | `PARAMS`, `DEFINES` | configuration that is linted |
| `LINT_WAIVER` | `lint/<ip>.vlt` (verilator), `lint/<ip>.awl` (spyglass), `lint/<ip>.vcst.tcl` (vcst), if present | waiver file, one justification comment per waiver |
| `LINT_GOAL` | `lint/lint_rtl` (spyglass), `lint_rtl` (vcst) | lint goal |
| `LINT_FAIL_ON` | `error` | spyglass/vcst: `warning` makes warnings fatal too (Verilator: every -Wall warning is fatal) |
| `SIM`, `LINT_TOOL`, `SYN_TOOL`, `STA_TOOL` | `verilator`, `verilator`, `yosys`, `opensta` (env.sh may preset) | tool selection |
| `VERILATOR_FLAGS`, `VERILATOR_CXX`, `VERILATOR_LDFLAGS` | — | extra Verilator build options / C++ compiler / link flags |
| `VCS_FLAGS`, `SIMV_FLAGS` | — | extra VCS compile / simv runtime options |
| `WAVE_VIEWER` | `gtkwave` | viewer for Verilator waves |
| `CHECK_STEPS` | `lint sim` | top Makefile: steps of check-all |
| `CLK_PERIOD`, `SDC` | — | P2 (sta.mk) |
| `DV_ENV` | — | dcache only (T-DV1): set in the block Makefile, selects TB_FLIST/TB_TOP |
| `SIM_PER_TB` | `0` | `1` (set by a block with several testbenches, T-RTL1 `hw/ip/cdc`): `SIM_DIR` = `build/<ip>/<cfg>/sim/<TB_TOP>/` |
| `CDC_TOP`, `CDC_FLIST`, `CDC_PARAMS` | `LINT_TOP`, `LINT_FLIST`, `LINT_PARAMS` | top, file list and parameters of `make cdc` |
| `CDC_SGDC` | `syn/<CDC_TOP>.sgdc` | SpyGlass constraints: `clock -domain`, `reset`, `abstract_port -clock`, `fifo -memory` |
| `CDC_GOALS` | `cdc/cdc_setup_check cdc/cdc_verify_struct` | goals run in order (add `cdc/cdc_verify` for the formal checks) |
| `CDC_FAIL_ON`, `CDC_EXPECT`, `CDC_WAIVER` | `error`, `pass`, `lint/<ip>_cdc.awl` if present | verdict rule, expected verdict, waiver file |

Derived (read-only, defined in common.mk for every .mk to use):

| Variable | Value |
|---|---|
| `CFG` | `$(subst =,-,…)` of `PARAMS DEFINES` joined by `_`, or `default` (e.g. `WIDTH-4_MAX-9`) |
| `BUILD_DIR` | `$(REPO_ROOT)/build/$(IP)/$(CFG)` |
| `LINT_DIR SIM_DIR COV_DIR REGRESS_DIR SYN_DIR GLS_DIR STA_DIR` | `$(BUILD_DIR)/{lint,sim,cov,regress,syn,gls,sta}` |
| `PARAM_FLAGS`, `DEFINE_FLAGS` | `-G<P>=<V>…`, `+define+<D>…` |
| `TEST_ID`, `SIM_LOG` | `<test>_s<seed>`, `$(SIM_DIR)/$(TEST_ID).log` |
| `IP_DIR` | absolute block directory |
| `RTL_FLIST_ABS TB_FLIST_ABS LINT_FLIST_ABS` | absolute file lists |

Helper functions in common.mk: `$(call flist_files,<f>)`, `$(call flist_incdirs,<f>)`,
`$(call flist_deps,<f>)` (prerequisites), `$(call flist_flat,<f>,<out.f>)` (recipe line
writing a flat list for tools that do not expand `${REPO_ROOT}`), `$(call flow_on,$(VAR))`
(1/yes/on/true test), `$(call flow_abs,<path>)`, and
`$(call flow_run_sim,<cmd>,<version>)` (log header + tee + PASS/FAIL check; use it for
any new simulator so pass/fail is decided identically everywhere).

### Build directory layout

```
build/<ip>/<cfg>/
├── lint/   lint_<tool>.log, lint_flat.f, spyglass/ (spyglass-1/...), vcst/ (vcst_rtdb), vcst_report.txt
├── sim/    <test>_s<seed>.log, .fst/.fsdb, last.fst|last.fsdb (+ last.daidir)
│           verilator[_trace][_cov]/   vcs[_dbg][_cov][_uvm]/   one model dir per build variant
│           (SIM_PER_TB=1: all of the above in sim/<TB_TOP>/)
├── cov/    simv.vdb, urg_report/ (vcs); *.dat, annotated/ (verilator)
├── cdc/    cdc_spyglass.log, cdc_flat.f, spyglass/spyglass-1/consolidated_reports/<top>_cdc_<goal>/
└── regress/ syn/ gls/ sta/        (later phases)
build/check-all/<ip|top>_<block>_<step>.log
```

## Adding a tool

* **Simulator** `foo`: create `flow/mk/sim_foo.mk`, wrapped in
  `ifeq ($(SIM),foo)` + an include guard; define `build`, `sim`, `waves` (and `cov`) using
  `SIM_DIR` (model dir per variant), `PARAMS`/`DEFINE_FLAGS`, `TB_FLIST_ABS`, `TB_TOP`,
  `SEED`, `TEST`, `PLUSARGS`, `WAVES`, `COV`; run with `$(call flow_run_sim,…)`; register
  `HELP_TARGETS`/`HELP_<t>`/`HELP_VARS`. `make sim SIM=foo` then works for every block.
  Detection belongs in env.sh, never an absolute path in the .mk.
* **Lint tool**: add an `else ifeq ($(LINT_TOOL),foo)` branch to lint.mk and, for Tcl
  tools, a script in `flow/lint/` that reads `LINT_FLAT LINT_TOP LINT_PARAMS
  LINT_DEFINES LINT_GOAL LINT_WAIVER` from the environment; outputs under `LINT_DIR`;
  fail the target on errors.
* **Synthesis / STA (P1/P2 authors)**: one `syn.mk` / `sta.mk` that dispatches on
  `SYN_TOOL` (`yosys`|`fc`) / `STA_TOOL` (`opensta`|`pt`) exactly like lint.mk, with the
  generic scripts in `flow/syn/` and `flow/sta/` reading environment variables
  (`LIB_STD`/`LIB_DB`, `SDC`, `CLK_PERIOD`, the flat file list from `flist_flat`,
  `DUT_TOP`, `PARAMS`), writing only under `SYN_DIR`/`GLS_DIR`/`STA_DIR`. Use `LIB_DB`
  for fc/pt and `LIB_STD` for Yosys/OpenSTA. GLS reuses `sim_$(SIM).mk` conventions
  (`flow_run_sim`). Register targets with `HELP_TARGETS`.
* **regress.mk (V1)**: loop over `dv/regress.list` × seeds × PARAMS sets by calling
  `$(MAKE) sim TEST=… SEED=… PARAMS=…` (each PARAMS set gets its own CFG dir), summary
  table under `REGRESS_DIR`; with `COV=1` all runs share `$(COV_DIR)/simv.vdb`.

## Synthesis, GLS, STA, sweeps (P1-P3)

| Target | Function |
|---|---|
| `synth` | `SYN_TOOL=fc`: Fusion Compiler `compile_logical` to `LIB_DB` (non-physical); `yosys`: sv2v + Yosys to `LIB`. Netlist `syn/<top>.v`, reports, `syn/<top>_summary.txt`; fails on latches |
| `gls` | V testbench without the RTL modules + netlist + cell models (`LIB_VERILOG`, or `build/lib/<lib>_cells.v` from lib2v.py) with `SIM` (vcs / verilator), `+define+GLS`, random power-up state (`GLS_INIT=random`, VCS `GLS_INIT=x`) |
| `lec` | Formality, RTL vs netlist, with the FC SVF (optional) |
| `sta` | `STA_TOOL=pt`: PrimeTime, `opensta`: OpenSTA; `SDC` at `CLK_PERIOD`; `sta/<top>_p<T>_*.rpt` + `_summary.txt` |
| `sweep` | every PARAMS line of `CONFIGS` (default `syn/configs.txt`): synth + sta iterated to Tmin; `build/<ip>/sweep/<top>_sweep.csv` + plots |
| `print-VAR` | value of a make variable (sweep.sh asks for `SYN_DIR`/`STA_DIR`) |

Variables: `SYN_FLATTEN` (1), `SYN_CLK_PERIOD` (10.0: fixed synthesis constraint, so one
netlist is timed at any `CLK_PERIOD`), `SDC` (synthesis and STA; a prerequisite of the
netlist), `STA_SDC` (default `SDC`: analysis only, `make sta STA_SDC=x.sdc` does not
re-synthesize), `SYN_IF_PARAMS` (parameters of interface ports of the top, e.g.
`cpu.AW=10`: elaborate does not derive them), `CLK_PERIOD` (10.0), `CONFIGS`,
`SYN_WIRE_LOAD` (see below), `LIB_STD`/`LIB_DB`/`LIB_NDM`/`LIB_TF`/`LIB_VERILOG` (lib/README.md),
`SDC_DRIVE_CELL`/`SDC_DRIVE_PIN`/`SDC_LOAD` (library values read by the SDC files; set per
library in syn.mk). With the cloud's `class.db` the flow builds a placeholder LEF
(`build/lib/<lib>.lef`) and Verilog models (`build/lib/<lib>_cells.v`) once per library.

## Structural CDC check (`cdc.mk`, Lab T-RTL1)

`make cdc` runs SpyGlass CDC (`sg_shell -tcl flow/cdc/spyglass_cdc.prj < /dev/null`, ending
with `exit -force`, run directory `build/<ip>/<cfg>/cdc/spyglass/`) on `CDC_FLIST` with top
`CDC_TOP`, `+define+SYNTHESIS`, the block's SGDC file and the goals `CDC_GOALS`
(default `cdc/cdc_setup_check cdc/cdc_verify_struct`; `enable_fifo` is set for the verify
goals so that `fifo -memory` constraints are honored). It prints every Fatal/Error/Warning
of each goal and the number of synchronized crossings, and fails on any fatal or error
(`CDC_FAIL_ON=warning`: also on warnings). A block enables it with
`include $(REPO_ROOT)/flow/mk/cdc.mk` and an SGDC file per top:

```make
CDC_TOP    ?= cdc_lib_lint            # hw/ip/cdc: a wrapper with all library blocks
CDC_FLIST  ?= lint/lint.f
CDC_SGDC   ?= syn/cdc_lib_lint.sgdc   # clock -name clk_a -domain dom_a ... / reset / abstract_port / fifo
include $(REPO_ROOT)/flow/mk/cdc.mk
```

`CDC_EXPECT=fail` turns the target into a negative test: it passes only if SpyGlass reports
an error (T-RTL1 shows this on `hw/ip/cdc/dv/negative/cdc_bad_crossing.sv`, a missing
synchronizer -> `Ac_unsync01/02`). VC SpyGlass CDC (`vc_static_shell`) is the alternative
tool; it is not wired into the flow.

## Lint of class-based code (`LINT_TOOL=vcs`, Lab T-MOD)

SpyGlass and VC SpyGlass lint synthesizable RTL only (SpyGlass reports syntax fatals on
classes; VC SpyGlass black-boxes a class-based top and then reports 0 messages -- a false
pass). `LINT_TOOL=vcs` compiles `LINT_FLIST`/`LINT_TOP` with VCS `+lint=all` and fails on
any `Error-`; `Lint-`/`Warning-` messages are warnings (`LINT_FAIL_ON=warning`: fatal).
`dv/model/cache_model/Makefile` selects it (with `LINT_FAIL_ON := warning`). The top-level
`check-all` also runs every `dv/model/*/Makefile` (T-MOD: `dv/model/cache_model`, `lint` + `sim`
with `TEST=hand`).

**FC and PrimeTime timing differ (wire load).** Fusion Compiler's logical flow
(`compile_logical`) times with zero interconnect; PrimeTime, without parasitics, applies the
library's wire-load model (class.lib: `wire_load_selection` by area, e.g. a fanout-1 net
~1.9 cap units instead of 1.0 pin cap). On class.db PT therefore reports paths up to ~20-25 %
slower than FC's own report for the same netlist (a netlist closed by FC at 15 ns: -3.2 ns in
PT, T-RTL3 finding). PrimeTime is the sign-off number. Options: `SYN_WIRE_LOAD=<model>`
(e.g. `20x20`, the largest class.lib model) makes FC synthesize *and* PrimeTime analyze with
that same explicit model (verified on counter: FC honours it, 31 -> 35 cells); or keep the
default and over-constrain synthesis (`SYN_CLK_PERIOD` ~20 % below the target). All
reference numbers in the ppa.md files use the default (FC zero wire load, PT automatic
selection, PT numbers reported).

The sweep CSV is `build/<ip>/sweep/<top>_sweep.csv` for `CONFIGS=syn/configs.txt` and
`<top>_<configs-name>_sweep.csv` for any other list (e.g. `dcache_configs_2way_sweep.csv`).

## Notes and known limitations

* `WAVES=1` needs no testbench code: Verilator gets a generated `flow_wave_dump` module
  bound into `TB_TOP` (`$dumpfile/$dumpvars` from `+WAVE_FILE=`); VCS gets a generated
  UCLI do-file (`fsdbDumpvars 0 <TB_TOP> +all; run; quit`) and `+fsdbfile+`.
* Verilator 5.013 on the cloud is older than the program minimum 5.020
  (check_tools reports TOO OLD). It lints and simulates the L0/R designs; newer
  `--timing`, randomization and coverage features of later labs may need SIM=vcs.
* VCS is run with `-no_save` to avoid the ASLR re-execution of simv.
* SpyGlass/VC SpyGlass run with stdin from `/dev/null` (both tools wait at a prompt after
  a fatal Tcl error otherwise); `sg_shell` needs `exit -force` at the end of the script.

## Regression (`regress.mk`, Lab V1)

A block enables it with `include $(REPO_ROOT)/flow/mk/regress.mk` (after common.mk) and a
list `dv/regress.list` (`REGRESS_LIST`). The work is done by `flow/scripts/regress.sh`;
every run is an ordinary `make sim`, so a regression run and a hand run are identical.

```
# hw/ip/sync_fifo/dv/regress.list
# config <name> [VAR=value ...]             compile-time configuration (own build dir)
config default
config w32d5    PARAMS="WIDTH=32 DEPTH=5"
config w1d2     PARAMS="WIDTH=1 DEPTH=2"
# test <name> <seeds> <configs> [+plusargs]  <configs>: * or a comma list
test smoke         1  *
test random        5  *        +NUM_TXN=10000 +BP_PCT=30
test exhaustive    1  xlen8
```

```sh
make -C hw/ip/sync_fifo regress                      # whole list, seeds 1..N
make regress IP=sync_fifo                            # same, from the root
make -C hw/ip/sync_fifo regress REGRESS_CONFIGS=w32d5 REGRESS_TESTS=random,smoke
make -C hw/ip/sync_fifo regress REGRESS_SEED_BASE=$(date +%s)   # nightly: fresh seeds
make -C hw/ip/sync_fifo regress REGRESS_JOBS=8       # parallel runs per configuration
make -C hw/ip/sync_fifo regress SIM=verilator        # any other variable reaches every run
```

| Variable | Default | Meaning |
|---|---|---|
| `REGRESS_LIST` | `dv/regress.list` | list (relative to the block or absolute) |
| `REGRESS_SEED_BASE` | `0` | seeds are `BASE+1 … BASE+N` |
| `REGRESS_JOBS` | `1` | parallel runs within one configuration (each configuration is built first) |
| `REGRESS_CONFIGS`, `REGRESS_TESTS` | all | comma lists to run a subset |
| `REGRESS_COVER_CHECK` | `1` | fail if a reported cover property was never hit |
| `REGRESS_SUMMARY` | `build/<ip>/regress_summary.txt` | summary table |

`PARAMS`, `DEFINES`, `TEST`, `SEED` come only from the list; `PLUSARGS` given on the command
line are appended to the list's plusargs; all other variables (`SIM`, `COV`, `WAVES`,
`TB_TOP`, `VERILATOR_FLAGS`, ...) reach every run. Output:

```
# regress: sync_fifo  list=hw/ip/sync_fifo/dv/regress.list  SIM=vcs  seeds=1..  2026-10-15 05:05:38
config     test                 seed  result   time  log
default    smoke                   1  PASS       1s  build/sync_fifo/WIDTH-8_DEPTH-16/sim/smoke_s1.log
w32d5      random                  3  FAIL       2s  build/sync_fifo/WIDTH-32_DEPTH-5/sim/random_s3.log
...
# cover properties (hits summed over 40 runs)
c_full                                312
...
TOTAL: 40 runs, 39 passed, 1 failed  (61s)
rerun: make -C hw/ip/sync_fifo sim PARAMS=WIDTH=32\ DEPTH=5 TEST=random SEED=3 PLUSARGS="+NUM_TXN=10000 +BP_PCT=30"
regress: FAIL (sync_fifo)  summary: build/sync_fifo/regress_summary.txt
```

The make output of each run is in `build/<ip>/regress/<config>/<test>_s<seed>.out` (useful
when the build failed: result `BUILD`), the simulation log where it always is. Exit code
!= 0 if any run failed. Lines `COVER: <label> <hits>` printed by the testbench
(`tb_utils_pkg::report()`) are summed over the runs.

## Shared testbench utilities (`dv/common/tb_utils_pkg.sv`, Lab V1)

Add `${REPO_ROOT}/dv/common/tb_utils_pkg.sv` to the testbench file list (before the
testbench) and `import tb_utils_pkg::*;`:

| Item | Use |
|---|---|
| `check(ok, msg)` | count a check; on failure print `ERROR: [time] CHECK FAILED: msg` and count an error |
| `sva_fail(label)` | assertion action: `a_x: assert property (...) else tb_utils_pkg::sva_fail("a_x");` |
| `cover_declare('{"c_a","c_b"})`, `cover_hit(label)` | cover properties: `c_a: cover property (...) tb_utils_pkg::cover_hit("c_a");` |
| `report()` | `COVER:` lines, `REPORT: checks=.. errors=..`, then exactly one `TEST PASSED` / `TEST FAILED` (zero checks = FAILED); called once |
| `watchdog(limit)` | `fork watchdog(1ms); join_none` -- TEST FAILED if the test is still running at `limit` |
| `get_seed()`, `get_int_arg(name, dflt)`, `get_str_arg(name, dflt)` | plusargs `+SEED=`, `+<name>=` |
| `n_checks`, `n_errors`, `max_errors` (20) | counters; the run stops after `max_errors` errors |

Errors are printed with `$display`, never `$error`: Verilator stops at the first `$error`,
and VCS continues after an assertion's default `$error` and would still print TEST PASSED --
hence the explicit `else sva_fail(...)` on every assertion.

## Changes for Lab V1 in `sim_verilator.mk`

`VLT_CHECK_FLAGS ?= --assert --coverage-user --x-assign unique --x-initial unique` at build
time and `VLT_INIT_ARGS ?= +verilator+rand+reset+2` at run time: Verilator 5.013 ignores
every SVA assertion without `--assert` (verified: a failing property passes silently), runs
cover-property actions only with `--coverage-user`, and with the last two options gives
uninitialized flip-flops random values derived from `SEED` (a missing reset shows up as a
seed-dependent failure). VCS needs nothing: it is four-state (uninitialized = X) and
assertions are always on.

