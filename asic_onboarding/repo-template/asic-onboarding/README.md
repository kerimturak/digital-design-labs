# asic-onboarding

Training repository of the ASIC onboarding program. One copy per engineer.

```
source env.sh                 # every session
flow/scripts/check_tools.sh R # tool check (R, V or P phase)
make check-all                # lint + smoke sim of every block
make sim IP=<ip> TEST=<test>  # one block, one test
```

| Directory | Contents | Created in |
|---|---|---|
| `flow/` | design-independent make rules and tool scripts | L0, extended in V1, P1, P2, P3 |
| `hw/ip/<ip>/` | one block: rtl/ tb/ dv/ syn/ lint/ doc/ | R1–R4 (rtl, tb), V1–V3 (dv), P1–P3 (syn) |
| `hw/top/` | integration tops | T-RTL2 |
| `dv/` | shared verification code (utilities, VIP, UVM agents) | V1, T-DV1, T-DV2 |
| `dv/model/` | SystemVerilog cache model, traces, exploration (no top-level `perf/`: that name is reserved for the team's C++ performance models) | T-MOD, T-AM1, T-AM2 |
| `lib/` | standard-cell libraries (provided, not committed) | P1 |
| `build/` | all generated output (never committed) | — |

## Lab status

| Lab | Branch | Status |
|---|---|---|
| L0 Repository, Tools and Flow | lab/l0-setup | |
| R1 Sequential Multiplier | lab/r1-seq-mul | |
| R2 Synchronous FIFO | lab/r2-sync-fifo | |
| R3 Arbitrated Memory | lab/r3-arb-mem | |
| R4 Data Cache | lab/r4-dcache | |
| V1 Self-Checking TB and Assertions | lab/v1-selfcheck-sva | |
| V2 Verifying a Shared Resource | lab/v2-arb-mem-dv | |
| V3 Constrained-Random Verification of the Cache | lab/v3-dcache | |
| P1 Synthesis and GLS | lab/p1-synthesis | |
| P2 Static Timing Analysis | lab/p2-sta | |
| P3 PPA Scaling | lab/p3-ppa | |
| T-RTL1 / T-RTL2 / T-RTL3 | lab/trtl1-cdc, lab/trtl2-dcache-cdc, lab/trtl3-seq-mul-pipe | |
| T-MOD | lab/tmod-cache-model | |
| T-DV1 / T-DV2 | lab/tdv1-layered-tb, lab/tdv2-uvm | |
| T-AM1 / T-AM2 | lab/tam1-dse, lab/tam2-cycle-model | |

## Tool versions
(output of `check_tools.sh`)
