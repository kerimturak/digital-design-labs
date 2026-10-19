# ASIC Onboarding Program — Master Specification

This file is the single source of truth for every lab document. Every lab
author must follow it. If a lab needs something that is not specified here,
choose the option most consistent with this file and note it in the
author's report.

Language of all documents: **English**. Tone and depth: same as the
original labs (precise, engineering-oriented, "explain why", tables for
interfaces/tests/assessment, short code listings, review questions).

---------------------------------------------------------------------------

## 1. Program structure

The program has a **common core** that every engineer does, in three
phases on the **same designs**, then **tracks** by role.

```
Common core (everyone, ~17 weeks)
  L0                     setup: repository, tools, flow skeleton
  Phase 1  RTL design    R1 seq_mul -> R2 sync_fifo -> R3 arb_mem -> R4 dcache
  Phase 2  Verification  V1 (seq_mul, sync_fifo) -> V2 (arb_mem) -> V3 (dcache)
  Phase 3  PD / PPA      P1 synthesis+GLS -> P2 STA -> P3 PPA scaling
Tracks (after the core)
  RTL track              T-RTL1 CDC library -> T-RTL2 multi-clock integration -> T-RTL3 timing-driven RTL
  DV track               T-MOD cache model -> T-DV1 layered class TB -> T-DV2 UVM
  Arch-modeling track    T-MOD cache model -> T-AM1 design-space exploration -> T-AM2 cycle-approximate model
```

Key principle: **a phase never re-teaches or pre-empts another phase.**

* R labs (design): RTL, coding rules, lint, micro-architecture, a *small
  directed smoke testbench written by the designer*. **No** SVA, no
  constrained random, no coverage, no synthesis, no STA in R labs
  (a one-line "this will be synthesized in P1" pointer is fine).
* V labs (verification): verify the R designs (unchanged unless a bug is
  found — bugs found are fixed in the RTL with a commit referencing the
  failing test). Random stimulus, plusargs, regression, SVA, scoreboards,
  classes, constrained random, functional coverage, testplans. **No**
  synthesis/STA.
* P labs (physical design / PPA): synthesize, gate-level simulate and time
  the R designs, using the V testbenches for GLS. **No** new verification
  features.
* Tracks may combine all three, because they are for engineers who already
  completed the core.

### 1.1 Lab table (IDs, titles, durations, Overleaf folder)

| Folder (Overleaf project) | ID | Title | Subtitle | Phase badge text | Badge color | Duration |
|---|---|---|---|---|---|---|
| 00_Program_Guide | — | Program Guide | (special doc) | — | — | — |
| 01_L0_Repo_and_Flow | L0 | Repository, Tools and Flow | Project Structure, File Lists, Make and Git Workflow | Common Core: Setup | phaseL | 0.5 week |
| 02_R1_Sequential_Multiplier | R1 | Sequential Multiplier | SystemVerilog RTL Constructs and Simulation--Synthesis-Safe Coding | Common Core: Phase 1 RTL Design | phaseR | 1.5 weeks |
| 03_R2_Sync_FIFO | R2 | Synchronous FIFO | Parameterized RTL and Simulation Semantics | Common Core: Phase 1 RTL Design | phaseR | 1 week |
| 04_R3_Arbitrated_Memory | R3 | Arbitrated Memory | Interfaces, Arrays and a Round-Robin Arbiter | Common Core: Phase 1 RTL Design | phaseR | 1.5 weeks |
| 05_R4_Data_Cache | R4 | Data Cache | Cache Micro-Architecture, Controller FSM and Performance Counters | Common Core: Phase 1 RTL Design | phaseR | 2 weeks |
| 06_V1_SelfChecking_TB_and_SVA | V1 | Self-Checking Testbench and Assertions | Randomization, Plusargs, Regression and SVA for seq\_mul and sync\_fifo | Common Core: Phase 2 Verification | phaseV | 2 weeks |
| 07_V2_Concurrent_TB | V2 | Verifying a Shared Resource | Virtual Interfaces, Dynamic Arrays, fork/join and Protocol Assertions | Common Core: Phase 2 Verification | phaseV | 1.5 weeks |
| 08_V3_Constrained_Random_Coverage | V3 | Constrained-Random Verification of the Cache | Classes, Constraints, Functional Coverage and Testplans | Common Core: Phase 2 Verification | phaseV | 2 weeks |
| 09_P1_Synthesis_and_GLS | P1 | Logic Synthesis and Gate-Level Simulation | Yosys, Standard Cells and Simulation--Synthesis Mismatches | Common Core: Phase 3 Physical Design | phaseP | 1.5 weeks |
| 10_P2_Static_Timing | P2 | Static Timing Analysis | Constraints, Timing Reports, Critical Paths and Fmax | Common Core: Phase 3 Physical Design | phaseP | 1.5 weeks |
| 11_P3_PPA_Scaling | P3 | Area, Timing and Scaling of Larger Blocks | Parameter Sweeps, Memories and PPA Trade-offs | Common Core: Phase 3 Physical Design | phaseP | 1.5 weeks |
| 12_TRTL1_CDC_Library | T-RTL1 | Clock Domain Crossing Library | Synchronizers, Asynchronous FIFO and Multi-Clock Verification | RTL Track | phaseT | 2 weeks |
| 13_TRTL2_MultiClock_Integration | T-RTL2 | Multi-Clock Integration | Controlling the Cache from a Second Clock Domain | RTL Track | phaseT | 1.5 weeks |
| 14_TRTL3_Timing_Driven_RTL | T-RTL3 | Timing-Driven RTL | Pipelining the Multiplier to a Frequency Target | RTL Track | phaseT | 2 weeks |
| 15_TMOD_Cache_Model | T-MOD | Transaction-Level Cache Model | Object-Oriented SystemVerilog and Reference Models | DV and Performance Tracks | phaseT | 1.5 weeks |
| 16_TDV1_Layered_TB | T-DV1 | Layered Class-Based Testbench | Generator, Driver, Monitors and a Model-Based Scoreboard | DV Track | phaseT | 2 weeks |
| 17_TDV2_UVM | T-DV2 | UVM Environment for the Cache | Agents, Sequences, Factory, Configuration and Phases | DV Track | phaseT | 3 weeks |
| 18_TAM1_Design_Space_Exploration | T-AM1 | Design-Space Exploration | Trace-Driven Simulation and Model--RTL Correlation | Architecture Modeling Track | phaseT | 1.5 weeks |
| 19_TAM2_Cycle_Approximate_Model | T-AM2 | Cycle-Approximate Timing Model | Timing in the Model, Calibration and Cycle Correlation | Architecture Modeling Track | phaseT | 2 weeks |

Cross-references in text: always write "Lab R1", "Lab V3", "Lab T-MOD", etc.
Never write "Lab 1 / Lab 6" (old numbering).

### 1.1a Reference solution

`solution/asic-onboarding/` is the finished training repository: every
design, testbench, verification environment, flow file, constraint,
script and model of every lab, with `doc/*.md` filled with real results,
runnable with the same `make` targets. `solution/README.md` maps each lab
to its files and commands. It is coordinator-only: it is not copied into
`repo-template/`, the Overleaf zips or anything given to engineers.

### 1.2 Designs and where they live

| Design | Created in | Verified in | Implemented (PPA) in | Path |
|---|---|---|---|---|
| `counter` (hello world) | L0 | — | — | `hw/ip/counter/` |
| `seq_mul`, `comb_mul`, `mul_pkg` | R1 | V1 | P1, P2 (T-RTL3 pipelines it) | `hw/ip/seq_mul/` |
| `sync_fifo` | R2 | V1 | P1, P2 | `hw/ip/sync_fifo/` |
| `mem_if` (interface), `arb_mem` | R3 | V2 | P3 | `hw/ip/arb_mem/` |
| `dcache`, `dcache_pkg` | R4 | V3 | P3 | `hw/ip/dcache/` |
| CDC primitives | T-RTL1 | T-RTL1 | T-RTL1 (SDC) | `hw/ip/cdc/` |
| `dcache_cdc_top` | T-RTL2 | T-RTL2 | T-RTL2 | `hw/top/dcache_cdc_top/` |
| `seq_mul_pipe` | T-RTL3 | T-RTL3 | T-RTL3 | `hw/ip/seq_mul/rtl/` (new module) |
| `cache_model_pkg` | T-MOD | T-MOD | — | `dv/model/cache_model/` |

---------------------------------------------------------------------------

## 2. Repository layout (canonical — every lab must use exactly these paths)

Inspired by OpenTitan (`hw/ip/<ip>/{rtl,dv,doc,data,lint}`, shared DV in
`hw/dv/sv`), Ibex (`syn/`, `lint/`, `dv/`), CVA6 (`verif/`, `pd/synth`,
`perf-model/`, `Flist.*` file lists using `${CVA6_REPO_DIR}`) and PULP
`common_cells` (`src/`, `test/`, `formal/`). Simplified for training.

```
asic-onboarding/                     one repository per engineer (fork of the template)
├── README.md                        how to set up, list of labs and status
├── env.sh                           `source env.sh` (bash, zsh): sets REPO_ROOT, LIB_DIR, PATH, tool defaults
├── env.csh                          same for csh / tcsh (`source env.csh`)
├── Makefile                         top level: `make <target> IP=<ip>` -> delegates to hw/ip/<ip>
├── .gitignore                       build/, lib/*.lib, *.vcd, *.fst
├── doc/
│   ├── reports/weekNN.md            weekly technical summaries
│   └── reviews/                     notes from review meetings
├── flow/                            design-independent build infrastructure
│   ├── mk/
│   │   ├── common.mk                REPO_ROOT, BUILD_DIR, CFG tag, flist expansion        (L0)
│   │   ├── lint.mk                  lint                                                  (L0)
│   │   ├── sim_verilator.mk         build, sim, waves                                     (L0; seeds/plusargs extended in V1)
│   │   ├── regress.mk               regress                                               (V1)
│   │   ├── syn.mk                   synth, gls                                            (P1)
│   │   ├── sta.mk                   sta                                                   (P2)
│   │   └── sim_<tool>.mk            commercial simulator for UVM, selected with SIM=      (T-DV2)
│   ├── syn/yosys_synth.tcl          generic Yosys script, reads env vars                  (P1)
│   ├── sta/sta.tcl                  generic OpenSTA script, reads env vars                (P2)
│   └── scripts/
│       ├── check_tools.sh           prints and checks tool versions                       (L0)
│       ├── flist_expand.sh          flattens a .f file (nested -f, ${REPO_ROOT}) to a file list (L0)
│       └── sweep.sh                 runs synth/sta over a list of PARAMS sets             (P3)
├── lib/                             technology files (SkyWater 130 nm liberty), provided, not committed
├── hw/
│   ├── ip/<ip>/                     one directory per block (see 2.1)
│   └── top/<top>/                   integration tops (T-RTL2)
├── dv/                              shared, design-independent verification code
│   ├── common/tb_utils_pkg.sv       report counters, TEST PASSED/FAILED, watchdog, plusarg helpers (V1)
│   ├── vip/mem_if/                  class-based (non-UVM) mem_if driver/monitor                  (T-DV1)
│   ├── uvm/mem_if_agent/            reusable UVM agent for mem_if                                (T-DV2)
│   └── model/                       SystemVerilog transaction-level models (DV reference + exploration)
│       ├── cache_model/             cache_model_pkg.sv and included class files                  (T-MOD)
│       ├── traces/                  trace files shared by model and RTL                          (T-AM1)
│       └── explore/                 model-only exploration testbenches, scripts, results         (T-AM1, T-AM2)
└── build/                           ALL generated output, never committed
    └── <ip>/<cfg>/{lint,sim,regress,syn,gls,sta}/
```

There is deliberately **no top-level `perf/` directory**: in the team, "performance
modeling" means the C++ performance models (Sniper and similar simulators) owned by the
performance team, which live elsewhere. The SystemVerilog models of this program are
verification-side models (T-MOD is the DV scoreboard reference; T-AM1/T-AM2 explore and
time it), so they live in `dv/model/`.

### 2.1 Per-IP layout

```
hw/ip/<ip>/
├── README.md              what the block is, how to run every target, results summary, known limitations
├── Makefile               IP variables + `include $(REPO_ROOT)/flow/mk/*.mk`
├── doc/
│   ├── spec.md            specification (interface, behavior)             R phase
│   ├── design.md          micro-architecture, block/FSM diagrams          R phase
│   ├── verification.md    results, bug log                                V phase
│   └── ppa.md             synthesis/timing results and analysis           P phase
├── rtl/
│   ├── <ip>_pkg.sv        (if any)
│   ├── <ip>.sv
│   └── <ip>.f             RTL file list: synthesizable files only
├── lint/<ip>.vlt          Verilator waivers, each with a justification comment
├── tb/                    R phase: designer's directed smoke testbench
│   ├── tb_<ip>.sv
│   └── tb.f
├── dv/                    V phase: verification environment (OpenTitan-style)
│   ├── testplan.md        features -> tests / assertions / cover items
│   ├── tb/tb_top.sv       testbench top module (clock, reset, DUT, interfaces, bind)
│   ├── env/               driver/monitor/scoreboard/ref model (tasks in V1/V2, classes in V3)
│   ├── tests/             test selection (+TEST=) or test classes
│   ├── sva/<ip>_sva.sv    assertion checker module, and <ip>_bind.sv
│   ├── cov/               coverage (V3)
│   └── dv.f
├── dv_layered/            T-DV1 only (dcache)
├── dv_uvm/                T-DV2 only (dcache): env/, seq_lib/, tests/, tb/
└── syn/
    ├── <ip>.sdc           timing constraints (P2)
    └── configs.txt        PARAMS sets used for sweeps (P3)
```

Interfaces that are part of a block's ports live in that block's `rtl/`
(e.g. `hw/ip/arb_mem/rtl/mem_if.sv`). Blocks that depend on other blocks
include their file list with a nested `-f` (e.g. `hw/ip/dcache/rtl/dcache.f`
contains `-f ${REPO_ROOT}/hw/ip/arb_mem/rtl/arb_mem.f` only if needed; the
dcache *testbench* file list includes arb_mem because the TB instantiates it).

### 2.2 File-list format

```
// hw/ip/sync_fifo/rtl/sync_fifo.f
+incdir+${REPO_ROOT}/hw/ip/sync_fifo/rtl
${REPO_ROOT}/hw/ip/sync_fifo/rtl/sync_fifo.sv
```

Rules: one entry per line, `//` comments, packages before users, only
`+incdir+`, `+define+` and nested `-f` besides file names, all paths start
with `${REPO_ROOT}` (as CVA6 `Flist.ariane` uses `${CVA6_REPO_DIR}`).
`flow/scripts/flist_expand.sh` resolves nested `-f` and `${REPO_ROOT}` for
tools that do not read `-f` (sv2v, Yosys).

### 2.3 Make interface (grows with the phases)

IP Makefile example:

```make
# hw/ip/sync_fifo/Makefile
IP        := sync_fifo
DUT_TOP   := sync_fifo
TB_TOP    ?= tb_sync_fifo
RTL_FLIST := rtl/sync_fifo.f
TB_FLIST  ?= tb/tb.f            # V phase: dv/dv.f, TB_TOP=tb_top
SDC       := syn/sync_fifo.sdc  # P2
PARAMS    ?= WIDTH=8 DEPTH=16
include $(REPO_ROOT)/flow/mk/common.mk
include $(REPO_ROOT)/flow/mk/lint.mk
include $(REPO_ROOT)/flow/mk/sim_verilator.mk
# include $(REPO_ROOT)/flow/mk/regress.mk   (V1)
# include $(REPO_ROOT)/flow/mk/syn.mk       (P1)
# include $(REPO_ROOT)/flow/mk/sta.mk       (P2)
```

| Target | Introduced | Function |
|---|---|---|
| `help` | L0 | list targets and variables with current values |
| `lint` | L0 | `verilator --lint-only -Wall` on the RTL file list |
| `build` | L0 | compile the simulation model |
| `sim` | L0 | run one test; exit code != 0 if log lacks `TEST PASSED` |
| `waves` | L0 | open last waveform in GTKWave |
| `clean` | L0 | delete `build/<ip>/` |
| `regress` | V1 | tests x seeds x PARAMS sets from `dv/regress.list`; summary table |
| `synth` | P1 | sv2v (`-DSYNTHESIS`) + Yosys, generic and sky130 |
| `gls` | P1 | V testbench on the synthesized netlist |
| `sta` | P2 | OpenSTA with `SDC`, `CLK_PERIOD` |
| `sweep` | P3 | synth+sta over `syn/configs.txt` → CSV |
| `cov` | V3 | merged coverage report (URG) of the last `COV=1` runs |
| `cdc` | T-RTL1 | structural CDC check with SpyGlass CDC (Synopsys cloud) |
| `lec` | P1 (optional) | Formality equivalence check RTL vs netlist (Synopsys cloud) |

| Variable | Introduced | Example |
|---|---|---|
| `PARAMS` | L0 | `WIDTH=32 DEPTH=5` → `-G` overrides of TB top; separate build dir per set |
| `DEFINES` | L0 | `MUL_XLEN=8` |
| `TEST` | L0 | `+TEST=` |
| `SEED` | L0 (used from V1) | `+verilator+seed+$(SEED)` and `+SEED=` |
| `PLUSARGS` | L0 | `+NUM_TXN=5000` |
| `WAVES` | L0 | `1` → FST/VCD dump |
| `LINT_TOP`, `LINT_FLIST` | L0 (needed R3) | lint a wrapper in lint/ (interface ports on top not accepted by Verilator) |
| `CLK_PERIOD` | P2 | ns |
| `SIM` | L0 | `verilator` (default) or `vcs`; common.mk includes `sim_$(SIM).mk`; with `UVM=1` (T-DV2), `TEST` becomes `+UVM_TESTNAME` |
| `LINT_TOOL` | L0 | `verilator` (default), `spyglass` (SpyGlass `lint/lint_rtl`), `vcst` (VC SpyGlass in VC Static) |
| `COV`, target `cov` | V3 | `COV=1` → VCS `-cm`; `make cov` → URG report |
| `UVM` | T-DV2 | `1` → VCS `-ntb_opts uvm-1.2` |
| `SYN_TOOL` | P1 | `yosys` (default) or `fc` (Fusion Compiler); `dc` where Design Compiler is licensed |
| `STA_TOOL` | P2 | `opensta` (default) or `pt` (PrimeTime) |
| `DV_ENV` | T-DV1 (dcache only) | `dv` (V3, default), `dv_layered` (T-DV1), `dv_uvm` (T-DV2): selects TB_FLIST/TB_TOP |

Build directory: `$(REPO_ROOT)/build/<ip>/<cfg>/<step>/`, where `<cfg>` is
derived from PARAMS and DEFINES, e.g. `WIDTH-32_DEPTH-5` (or `default`).
Logs: `build/<ip>/<cfg>/sim/<test>_s<seed>.log`.

### 2.4 Conventions

* Module = file name; one module per file; `_pkg`, `_if`, `_sva`, `_bind`
  suffixes; testbench tops `tb_<ip>` (R smoke) and `tb_top` (V).
* Clock `clk`, active-low async reset `rst_n`, handshake `valid`/`ready`.
* Coding style: lowRISC Verilog/SystemVerilog style guide (introduced in R1).
* Every simulation ends with exactly one line `TEST PASSED` or
  `TEST FAILED`, has a watchdog, and prints its configuration (PARAMS,
  TEST, SEED, plusargs) at the start.
* RTL contains assertions only inside `` `ifndef SYNTHESIS `` (V1 onward).
* Git: one branch per lab (`lab/r1-seq-mul`), merge request reviewed by
  the coordinator, tag at completion (`r1-done`). Labs never break earlier
  labs: `make lint sim` for every IP must still pass (CI-style check
  `make -C $(REPO_ROOT) check-all`, introduced in L0).

### 2.5 Tools

Verilator 5.x (lint, sim, GLS), sv2v, Yosys, OpenSTA, GTKWave, Git, make,
Python 3 (plots, CSV). SkyWater 130 nm `sky130_fd_sc_hd__tt_025C_1v80.lib`
in `lib/`. UVM (T-DV2): the team's commercial simulator or EDA Playground.
Tool caveats from the original labs (Verilator two-state, constrained
random solver, covergroup support) must be kept where relevant.

The labs stay open-source-first. The team works on the **Synopsys cloud**,
so every lab adds the Synopsys equivalent of each tool step in a
`\synopsysnote{}` box ("if you have these tools, use them"), and the flow
selects the tool with one make variable:

| Step | Open source | Synopsys cloud | Variable |
|---|---|---|---|
| Lint | Verilator `--lint-only` | SpyGlass `sg_shell` (`lint/lint_rtl`), VC SpyGlass (`vc_static_shell`) | `LINT_TOOL` |
| Simulation | Verilator | VCS | `SIM` |
| Waves | GTKWave | Verdi (FSDB) | `WAVES=1`, `make waves` |
| Coverage | (limited) | VCS `-cm` + URG / Verdi | `COV=1`, `make cov` |
| Formal | (SymbiYosys, optional) | VC Formal (`vcf`) | — |
| Synthesis | sv2v + Yosys | Fusion Compiler `fc_shell` (Design Compiler not licensed) | `SYN_TOOL` |
| Equivalence | — | Formality `fm_shell` | `make lec` |
| STA | OpenSTA | PrimeTime `pt_shell` | `STA_TOOL` |
| Power | — | PrimePower | — |
| CDC | review + simulation | SpyGlass CDC / VC SpyGlass CDC | `make cdc` |
| UVM | EDA Playground | VCS `-ntb_opts uvm-1.2` | `SIM=vcs UVM=1` |
| Library | sky130_fd_sc_hd | SAED32 kit at `/global/apps/lynxnxt/2024.09/fpm_FC_saed32/SAED32_data` (db, NDM, tf, Verilog models, SRAM macros) or the team PDK; `class.db` from the DC install for zero-setup bring-up | `LIB_STD`, `LIB_DB`, `LIB_NDM`, `LIB_TF`, `LIB_VERILOG` |

Installed when checked (2026-10-15), under `/global/apps/<tool>/<ver>/`:
VCS/Verdi 2024.09-SP1-1, SpyGlass 2025.06-SP1, VC Static 2024.09-SP2-4,
Fusion Compiler 2025.06-SP1, PrimeTime 2025.06, Formality 2026.03-SP2;
Verilator 5.013 and GTKWave 3.3.115 under `/global/apps/freeware/`
(Verilator 5.013 is below the 5.020 minimum and needs gcc ≥ 10 for
`--timing`; `env.sh` selects gcc 12.4). `env.sh`/`env.csh` set the cloud
defaults `SIM=vcs LINT_TOOL=spyglass SYN_TOOL=fc STA_TOOL=pt`.

---------------------------------------------------------------------------

## 3. Document template (every lab)

Preamble — exactly this (the shared `training.sty` is in the project):

```latex
\documentclass[11pt,a4paper]{article}
\usepackage{training}
\labsetup{R1}{Sequential Multiplier}
         {SystemVerilog RTL Constructs and Simulation--Synthesis-Safe Coding}
         {Common Core: Phase 1 RTL Design}{phaseR}
\begin{document}
\maketitle
\labobjective{...one or two sentences...}
\labinfo{1.5 weeks (approximately 25--30 hours)}
        {Lab L0}
        {\code{seq\_mul}, \code{comb\_mul} (new)}
        {V1 (verification), P1 and P2 (synthesis, timing), T-RTL3}
\tableofcontents
\newpage
...
\end{document}
```

Available macros (from training.sty): `\code{}`, `\repo{}`,
`\labobjective{}`, `\labinfo{}{}{}{}`, `\notebox{Title}{Text}`,
`\synopsysnote{Text}` (blue "On the Synopsys cloud" box),
`\testnote{Term}{Text}` (green "Test term" box); listing
styles `sv`, `shell`, `tcl`, `mk`, `plain`; colors `sectionblue`,
`regionfill`, `reactivefill`, `lightgray`, `dutfill`, `tbfill`, `memfill`;
TikZ styles `blk` (design), `memblk` (storage), `tbblk` (testbench),
`sig`, `bus`, `lbl`, `region`; tikz libraries positioning,
arrows.meta, fit, calc, shapes.geometric, shapes.multipart, backgrounds.

Every lab must contain:

* at least one **block diagram** of what it builds (design labs: DUT ports
  and internal boxes; verification labs: testbench architecture; PD labs:
  the tool flow; tracks: the structure of the design/model/environment);
* a `\testnote{}` box where a kind of test (smoke, directed, corner-case,
  exhaustive, random, constrained-random, back-pressure, error injection,
  regression, GLS, coverage closure, model correlation, ...) is first
  mentioned in that lab, consistent with the Program Guide section "Test
  Types Used in the Program", and a one-line purpose for every test name
  in its test tables;
* a `\synopsysnote{}` box next to every open-source tool command or tool
  table, with the Synopsys equivalent and the make variable that selects it. Do not add packages unless
unavoidable (then add them in the main.tex preamble, not the sty).

Section order:

1. **Overview** — context (why this matters in a real chip/team), what you
   build, "By the end of this lab you should be able to" (5–7 items).
   Mention in one short paragraph where this lab sits: what it builds on,
   which later lab reuses its output.
2. Topic/theory sections and the specification.
3. **Requirements / Tasks** (numbered, concrete, checkable).
4. **Repository and Flow** — the exact files/directories created or
   changed in this lab (repo paths from Section 2), new make
   targets/variables, example commands.
5. **Deliverables** — what must be in the merge request; README/doc/*.md
   contents.
6. **Assessment** — weights table summing to 100%.
7. **Review Questions** — 8–10.
8. **References**.

Length target: 450–900 lines of LaTeX per lab. Must compile with
`pdflatex` (twice) with no errors and no undefined references.

LaTeX pitfalls: escape `_`, `#`, `$`, `%`, `&` inside `\code{}`
(`\code{rst\_n}`, `\code{\#\#1}`, `\code{\$past}`); inside `lstlisting`
nothing is escaped. Do not use `\code{}` inside section titles — use
`\texttt{}` with escapes instead. Use `--` for ranges.

---------------------------------------------------------------------------

## 4. Content mapping (old material → new labs)

Old sources (Overleaf projects, now at `/tmp/.../scratchpad/src/`):
`A0` program, `A1` "Lab 1 seq_mul", `A2` "Lab 2 sim semantics + flow +
sync_fifo + SVA", `A3` "Lab 3 arb_mem", `A4` "Lab 4 dcache", `A5` "Lab 5
CDC", `A7` "Lab 6 class model + layered TB", `A8` "Lab 7 UVM". `A6` is empty.
Reuse the old text, listings and figures wherever they fit (they are
good); restructure, trim and re-point references. Do not lose technical
content — every topic of the old labs must land in exactly one new lab.

### L0 — Repository, Tools and Flow (new)
Tool installation & `check_tools.sh`; the repository layout of Section 2
with the rationale (why `rtl/`, `dv/`, `syn/` per IP; why shared `flow/`;
why `build/` is never committed); file lists (from A2 §File Lists, adapted
to `${REPO_ROOT}`); `common.mk`, `lint.mk`, `sim_verilator.mk`; compile-
time parameters vs runtime plusargs (A2 table, the concept only); Git
workflow; hello-world IP `counter` (parameterized up-counter with enable
and wrap) with a tiny smoke TB, to prove the flow. Mention FuseSoC/Bender
as what real projects use, as further reading.

### R1 — seq_mul (from A1)
Keep: overview, terminology & architecture (figures `diagram1.jpg`,
`diagram2.jpg`), design specification (ops, interface, behavior),
comb_mul description (it will be compared in P2), required SV constructs,
lowRISC style guide, Rules 1–12, lint checklist.
Testbench: **only a simple directed self-checking smoke TB** in
`tb/tb_seq_mul.sv` — tasks `apply_reset`, `do_mul(op,a,b)` (drive at
negedge, wait for handshake, compare against a reference function),
`report`; directed corner cases; exhaustive with `MUL_XLEN=8` (a simple
nested loop is fine); watchdog. Keep the race note briefly (drive on
negedge; R2 explains why). Move monitors/queues/back-pressure/10k-random/
assertions → V1. Move synthesis/GLS/STA/timing analysis/mismatch
experiments → P1/P2 (just say so).
Flow: `make lint`, `make sim`, `make sim DEFINES=MUL_XLEN=8 TEST=exhaustive`.
Mismatch: keep one *lint-level* exercise: show that Verilator lint flags
rules 1,3,4,7,12 on a deliberately bad file (no synthesis).

### R2 — sync_fifo (from A2)
Design spec of sync_fifo (any DEPTH ≥ 2, FWFT, full/empty from registers),
design note on pointer wrap for non-power-of-2 DEPTH; parameterization
(`parameter`, `localparam`, `$clog2`, overriding with `-G`, testbench top
passing params). Simulation semantics: all of A2 §Scheduling and Races
(regions figure, rising-edge walkthrough, race definition, TB–DUT race,
`<=` drive standard, `#0`, race_demo exercise). Smoke TB: directed
fill/drain/simultaneous tests using a SV queue as model, drive with `<=`.
SVA/randomization/regress → V1.

### R3 — arb_mem (from A3)
Design spec (block diagram, params, mem_if, protocol, arbitration, RTL
requirements), Interfaces section (modports; protocol assertions are
*mentioned* as belonging in the interface and are written in V2), packed
vs unpacked **synthesizable** arrays (static), the round-robin arbiter.
Smoke TB: directed single-master and conflict cases with a fixed sequence
using the interface from a module-level TB (no virtual interfaces / no
fork-join here — those are V2; a simple sequential directed test with both
masters driven from one initial block is fine). Waveform/timing diagram of
a conflict (WaveDrom) is required in doc/design.md. Synthesis note → P3.

### R4 — dcache (from A4)
Cache architecture, address fields, storage, policies, performance
metrics (AMAT), design spec (system structure, ports, behavior,
controller FSM figure), RTL requirements, out-of-scope. The memory side
uses `arb_mem` from R3 via file list (no copy). Performance counters in
RTL. Smoke TB: directed hit / clean miss / dirty miss / flush, plus two
directed patterns (sequential stride-1 over 4x capacity, conflict on one
index) to read the performance counters and compare with a **hand
prediction** of hit rate (keep the prediction exercise: it is
architecture). Stretch: 2-way set-associative (generate, LRU bit),
verification of the stretch is optional in V3 and its PPA in P3.
Classes/constrained random/coverage/three checks → V3. Synthesis → P3.

### V1 — seq_mul & sync_fifo verification (from A1 TB + A2 TB/rand/SVA)
Move the smoke TB into the full `dv/` structure: driver/monitor/ref
model/scoreboard tasks (A1 required structure table and skeleton,
updated to the `<=` standard from R2), back-pressure, handshake tests,
≥10k random with seed printing, plusargs (A2 code), `$urandom` etc. (A2
randomization table and pitfalls), reproducibility, `regress` target
(`dv/regress.list`), `dv/common/tb_utils_pkg.sv`. SVA: all of A2 §Assertions
(immediate vs concurrent, sampling, implication table, sampled-value
functions, assert/assume/cover, where assertions go incl. bind, required
assertions for both designs, cover properties, see-an-assertion-fire).
New: a short `dv/testplan.md` per IP (feature → test/assertion/cover) —
introduce the idea of a testplan (OpenTitan `data/<ip>_testplan.hjson`
as reference). Bug-hunt exercise: coordinator-provided buggy versions or
self-inserted bugs; show assertion fires before scoreboard.

### V2 — arb_mem verification (from A3)
Virtual interfaces, testbench arrays (dynamic/queue/associative,
operations, pitfalls), fork/join (table, patterns, loop variable pitfall,
shared data), TB structure table, tests & plusargs, scoreboard in DUT
acceptance order, statistics, protocol assertions in `mem_if`, design
assertions for the arbiter (bound from `dv/sva/`), cover properties,
assertion-fires-first exercise, testplan, regression over AW sets.
Clocking blocks: introduce briefly here (A2 promised "a later lab") as an
alternative to `<=` driving in the interface, optional to use.

### V3 — dcache verification (from A4)
Classes and constrained randomization (A4 section + rules + tool note),
verification strategy (transparency, three independent checks, tag
model, memory preload frontdoor/backdoor), tests & plusargs, functional
coverage (covergroup basics, required coverage plan, tool note fallback),
design assertions for dcache (A4 list, bound via `dv/sva/`), coverage
closure as completion criterion, testplan with coverage items, measured
performance table vs R4 hand predictions. Stretch: verify 2-way.

### P1 — Synthesis and GLS (from A1 steps 4–6 + mismatch experiment)
What synthesis does (elaboration, generic mapping, technology mapping,
optimization), sv2v and why, `flow/syn/yosys_synth.tcl` generic script
(env vars), `syn.mk` targets `synth` / `gls`, reading the Yosys log & `stat`
(latches, cell counts, area with liberty), standard cells & liberty basics
(what a .lib contains: cells, area, timing arcs, PVT corner tt_025C_1v80),
GLS with the V1 testbench and random init, the full A1 Mismatch Experiment
table (A–G), applied to seq_mul; synthesize seq_mul, comb_mul, sync_fifo
(two param sets). Map netlist cells back to RTL. `doc/ppa.md`.

### P2 — STA (from A1 Step 7 + Timing Analysis + A2 synth/timing)
STA concepts (paths, startpoints/endpoints, arrival/required, slack, WNS/
TNS, setup/hold, recovery/removal, ideal clock vs clock tree, wire load
absent), SDC per IP in `syn/<ip>.sdc` (create_clock, IO delays, set_load,
driving cell), generic `flow/sta/sta.tcl`, report anatomy (annotated
example report), all 8 A1 Timing Analysis questions, the seq vs comb
comparison table + paragraph, the improvement task, sync_fifo WIDTH/DEPTH
effect on critical path.

### P3 — PPA scaling (from A3 synth note, A4 Synthesis and Timing)
`sweep` target & `syn/configs.txt` → CSV + plot; arb_mem AW=2/4/6 area
and timing (memory from flops), dcache area breakdown (tag/valid/dirty vs
data; `synth -flatten` off / hierarchy-aware `stat`), critical path through
tag compare & why, SRAM macros vs flops and how a synchronous SRAM read
changes the controller (discussion), NUM_LINES/LINE_WORDS sweep, 2-way vs
direct-mapped if stretch done. A short "PPA report" per block in
`doc/ppa.md`; final summary presentation for the review.

### T-RTL1 — CDC library (from A5 Part A + verification + SDC)
CDC fundamentals (all), Part A blocks in `hw/ip/cdc/`, async FIFO,
handshake, verification of CDC logic (delay model, multi-clock TB,
assertions), timing constraints for CDC (on async_fifo).

### T-RTL2 — Multi-clock integration (from A5 Part B + experiment + report)
`hw/top/dcache_cdc_top/`, Part B table & requirements & checks, the
breaking-the-crossings experiment, the CDC crossing report, STA of the
top with two clocks.

### T-RTL3 — Timing-driven RTL (new)
Goal: make the multiplier meet a frequency target that `seq_mul` (P2) and
`comb_mul` cannot meet at the needed throughput. Design `seq_mul_pipe`:
a pipelined multiplier (e.g. N-stage pipelined array/partial-product
multiplier, or radix-4 Booth with a pipelined adder tree — specify one
baseline: N-stage pipeline where N is a parameter, one result per cycle
throughput, valid/ready with back-pressure via a skid buffer or
stall-all-stages, explained). Topics: pipelining & throughput vs latency,
retiming, register balancing, valid propagation, stall vs bubble,
skid buffers, Booth radix-4 (optional stretch), how to read the P2 critical
path and decide where to cut. Tasks: reuse V1 testbench (latency-agnostic,
handshake-based!), run P1/P2 flow, sweep N, table of N vs Fmax vs area vs
throughput, pick N for a given target (e.g. 250 MHz in sky130 tt — say the
coordinator sets the exact target). Optional: Yosys `abc -dff` / retiming
experiment vs manual pipelining.

### T-MOD — Cache model (from A7 OOP + model + model verification)
OOP SystemVerilog (handles/copies, inheritance/virtual/polymorphism,
abstract classes, parameterized classes & packages, $cast), the cache
model (transaction level, what it predicts and not, required API,
requirements, replacement policies), verifying the model
(hand traces, transparency, clone check). Location `dv/model/cache_model/`.
Model must run with no RTL. This lab is shared by the DV and architecture-modeling tracks.

### T-DV1 — Layered TB (from A7 testbench architecture etc.)
Testbench architecture (figure, components, communication, abstract
component), connecting the T-MOD model to the RTL (scoreboard algorithm,
ending the test), tests & blueprint pattern, bug-injection experiment
(compare with V3). Location `hw/ip/dcache/dv_layered/`, reusable mem_if
driver/monitor classes in `dv/vip/mem_if/`. Coverage from V3 reused.

### T-DV2 — UVM (from A8)
All of A8, re-pointed: "Lab 6" → T-DV1, "Lab 4" → V3/R4, "Lab 3" → R3/V2.
Locations: agent `dv/uvm/mem_if_agent/`, env `hw/ip/dcache/dv_uvm/{env,
seq_lib,tests,tb}` (OpenTitan layout), sim_<tool>.mk. Model from T-MOD
unchanged.

### T-AM1 — Design-space exploration (from A7 DSE + A4 performance experiment)
Trace format (text file: one access per line `R|W addr [data]`) in
`dv/model/traces/`; trace generators (sequential, random, conflict, loop,
plus a "realistic" mixed pattern e.g. array walk + stack-like hot
region); model-only `dv/model/explore/tb_explore.sv` sweeping configs; CSV +
plots (Python); questions from A7 DSE and A4 perf experiment (line size
vs pattern, policy vs loop pattern, AMAT); **model–RTL correlation**:
replay the same trace on the R4 RTL (a trace-driven TB top in
`dv/model/explore/`) and compare hit/miss/write-back counts exactly with the
RTL performance counters; model speed vs RTL speed; a one-page
recommendation memo for a cache configuration given an area budget
(use P3 area numbers).

### T-AM2 — Cycle-approximate model (new)
Extend the T-MOD model with timing: hit latency, refill latency per word,
write-back latency, memory latency parameters, blocking behavior → predict
cycles per access and total cycles / stall_cycles for a trace. Calibrate
parameters from RTL measurements (R4 counters, V3 latency stats),
correlate cycle counts with RTL on traces (error % per trace, target
e.g. < 2% for a blocking cache, explain residuals), "what-if" studies the
RTL cannot do quickly (memory latency 1..50 cycles, non-blocking with
1–4 MSHRs approximated analytically), sensitivity analysis, limits of
cycle-approximate vs cycle-accurate models. Reference: CVA6
`perf-model/` (Python model + `cycle_diff.py` comparing with RTL traces) as
an industrial example. Location `dv/model/explore/` and a timing extension
class in `dv/model/cache_model/` (derived class, the T-MOD model unchanged —
use inheritance/composition).
