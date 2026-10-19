# Reference solution — coordinator only

`solution/asic-onboarding/` is the finished training repository: every lab done, in the
layout of `spec/SPEC.md` §2, runnable with the same `make` targets the labs teach.
Do **not** give this folder to engineers: it is not part of `repo-template/`, of the
Overleaf zips or of the PDFs. Use it to answer questions, to check an engineer's numbers
in a review, and to try out lab changes before publishing them.

Results quoted in the labs' review answers are in each block's `doc/*.md`; they were
produced with the Synopsys-cloud tools and the `class.db` bring-up library (see
"Tools" below), so absolute area/timing numbers differ from sky130 — compare trends.

## Quick start

```sh
cd solution/asic-onboarding
source env.sh                      # bash/zsh;  csh/tcsh: source env.csh
flow/scripts/check_tools.sh P      # shows open-source and Synopsys tools found
make check-all                     # lint + default test of every block (hw/ip, hw/top, dv/model)
make help IP=dcache                # targets and variables of one block
```

Cloud defaults set by `env.sh`: `SIM=vcs LINT_TOOL=spyglass SYN_TOOL=fc STA_TOOL=pt`.
Override on the command line, e.g. `make sim IP=counter SIM=verilator`.

## Lab → files → commands

| Lab | Where the solution is | Commands that reproduce it |
|---|---|---|
| L0 | `env.sh`, `env.csh`, `Makefile`, `flow/mk/{common,lint,sim_verilator,sim_vcs}.mk`, `flow/lint/`, `flow/scripts/{check_tools,flist_expand}.sh`, `flow/README.md`, `hw/ip/counter/` | `make -C hw/ip/counter lint sim`; `make check-all` |
| R1 | `hw/ip/seq_mul/rtl/{mul_pkg,seq_mul,comb_mul}.sv`, `tb/tb_seq_mul.sv`, `doc/{spec,design,answers}.md` | `make -C hw/ip/seq_mul lint`; `make -C hw/ip/seq_mul sim TB_TOP=tb_seq_mul TB_FLIST=tb/tb.f TEST=exhaustive DEFINES=MUL_XLEN=8` (see its README) |
| R2 | `hw/ip/sync_fifo/rtl/`, `tb/tb_sync_fifo.sv`, `tb/race_demo.sv`, `doc/` | see `hw/ip/sync_fifo/README.md` (three PARAMS sets) |
| R3 | `hw/ip/arb_mem/rtl/{mem_if,arb_mem}.sv`, `lint/` wrapper + waivers, `tb/tb_arb_mem.sv`, `doc/design.md` (WaveDrom) | `make -C hw/ip/arb_mem sim TB_TOP=tb_arb_mem TB_FLIST=tb/tb.f PARAMS="AW=2"` |
| R4 | `hw/ip/dcache/rtl/`, `tb/tb_dcache.sv`, `doc/design.md` (FSM, predictions, WAYS=2 stretch) | `make -C hw/ip/dcache sim DV_ENV=tb TEST=all` |
| V1 | `dv/common/tb_utils_pkg.sv`, `flow/mk/regress.mk`, `flow/scripts/regress.sh`, `hw/ip/{seq_mul,sync_fifo}/dv/`, `doc/verification.md` | `make -C hw/ip/seq_mul regress`; `make -C hw/ip/sync_fifo regress` |
| V2 | `hw/ip/arb_mem/dv/`, protocol SVA in `rtl/mem_if.sv` | `make -C hw/ip/arb_mem regress` |
| V3 | `hw/ip/dcache/dv/` (classes, constraints, `cov/`, `sva/`), `flow/scripts/cov_merge.py` | `make -C hw/ip/dcache regress COV=1`; `make -C hw/ip/dcache cov` |
| P1 | `flow/mk/syn.mk`, `flow/syn/{fc_synth.tcl,yosys_synth.tcl,fm_lec.tcl,fc_bringup.tf}`, `flow/scripts/{lib2v,lib2lef,liberty}.py`, `hw/ip/*/doc/ppa.md` | `make -C hw/ip/seq_mul synth gls`; optional `lec` (Formality — never ran: licenses always in use) |
| P2 | `flow/mk/sta.mk`, `flow/sta/{pt_sta.tcl,sta.tcl}`, `hw/ip/*/syn/*.sdc` | `make -C hw/ip/seq_mul sta CLK_PERIOD=...` |
| P3 | `flow/scripts/{sweep.sh,plot_sweep.py}`, `hw/ip/{arb_mem,dcache}/syn/configs.txt`, `doc/ppa.md` | `make -C hw/ip/dcache sweep` |
| T-RTL1 | `hw/ip/cdc/`, `dv/common/clk_rst_gen.sv`, `flow/mk/cdc.mk`, `flow/cdc/spyglass_cdc.prj` | `make -C hw/ip/cdc regress`; `make -C hw/ip/cdc cdc` |
| T-RTL2 | `hw/top/dcache_cdc_top/` | `make sim TOP=dcache_cdc_top`; `make -C hw/top/dcache_cdc_top cdc sta` (see its README) |
| T-RTL3 | `hw/ip/seq_mul/rtl/{seq_mul_pipe.sv,seq_mul_pipe.f}`, `dv/sva/seq_mul_pipe_*`, `syn/configs_pipe.txt`, `doc/trtl3.md` | `make -C hw/ip/seq_mul regress DEFINES=MUL_PIPE ...` (see `doc/trtl3.md`) |
| T-MOD | `dv/model/cache_model/` (package, 14 classes, `tb/`) | `make -C dv/model/cache_model regress` |
| T-DV1 | `dv/vip/mem_if/`, `hw/ip/dcache/dv_layered/`, `doc/tdv1.md` | `make -C hw/ip/dcache regress DV_ENV=dv_layered COV=1`; bugs: `dv_layered/bugs/run_bugs.sh` |
| T-DV2 | `dv/uvm/mem_if_agent/`, `hw/ip/dcache/dv_uvm/`, `doc/tdv2.md` | `make -C hw/ip/dcache sim DV_ENV=dv_uvm TEST=dcache_smoke_test`; `regress DV_ENV=dv_uvm` |
| T-AM1 | `dv/model/traces/`, `dv/model/explore/` (tb_explore, tb_replay, scripts, `results/`, `doc/recommendation.md`) | `make -C dv/model/explore explore plots correlate` |
| T-AM2 | `dv/model/cache_model/{cache_timing_pkg.sv,...}`, `dv/model/explore/{calibrate,cycle_check,cycle_diff,whatif,sensitivity}.py`, `doc/cycle_model.md` | `make -C dv/model/explore calibrate cycles whatif` |

Every block's `README.md` lists all of its targets, tests and the results obtained.

## Tools

| Step | Used for the solution | Open-source alternative kept in the flow |
|---|---|---|
| Lint | SpyGlass `lint/lint_rtl` (`LINT_TOOL=spyglass`), VC SpyGlass (`vcst`), VCS `+lint=all` for class code (`vcs`) | Verilator `--lint-only -Wall` |
| Simulation | VCS 2024.09 (`SIM=vcs`), Verdi for waves, URG for coverage | Verilator (cloud has 5.013 < 5.020: R-lab smoke TBs run, V/T environments need VCS) |
| Synthesis | Fusion Compiler 2025.06 (`SYN_TOOL=fc`) — Design Compiler is not licensed | Yosys + sv2v (scripts kept, not installed on the cloud) |
| Equivalence | Formality (`make lec`) | — |
| STA | PrimeTime 2025.06 (`STA_TOOL=pt`) | OpenSTA (script kept) |
| CDC | SpyGlass CDC (`make cdc`) | review + simulation |
| Library | default `class.db`/`class.lib` from the DC install (bring-up), Verilog cell models generated by `flow/scripts/lib2v.py`; SAED32 kit at `/global/apps/lynxnxt/2024.09/fpm_FC_saed32/SAED32_data` via `LIB_NDM`/`LIB_TF`/`LIB_VERILOG` (see `lib/README.md`) | sky130_fd_sc_hd |

Known tool notes (details in `flow/README.md` and the per-lab notes):
- Verilator 5.013: `--timing` needs g++ ≥ 10 (env.sh selects gcc 12.4); its timing mode
  lets a monitor woken at a clock edge see post-edge values, so V-lab environments fail
  there — re-check with Verilator ≥ 5.020.
- Fusion Compiler (non-physical, zero wire load) and PrimeTime (class.lib wire-load model)
  correlate poorly on this library: over-constrain synthesis, sign off with PrimeTime.
- `REGRESS_JOBS>1` must not be combined with editing sources during the run (parallel
  rebuilds of the same simv).
