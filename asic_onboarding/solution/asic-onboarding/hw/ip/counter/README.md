# counter

Parameterized up-counter with enable, synchronous clear and a registered wrap pulse --
the hello-world block of Lab L0. Specification: [doc/spec.md](doc/spec.md),
micro-architecture: [doc/design.md](doc/design.md).

| Path | Contents |
|---|---|
| `rtl/counter.sv`, `rtl/counter.f` | RTL and its file list (synthesizable files only) |
| `tb/tb_counter.sv`, `tb/tb.f` | directed smoke testbench, file list = `-f rtl/counter.f` + TB |
| `Makefile` | block variables + include of the shared flow |

No lint waivers are needed (`lint/` is empty): the RTL is clean under
`verilator --lint-only -Wall`, SpyGlass `lint/lint_rtl` and VC SpyGlass `lint_rtl`.

## How to run

```sh
source env.sh                                   # once per shell, in the repository root
make -C hw/ip/counter lint                      # LINT_TOOL=verilator|spyglass|vcst
make -C hw/ip/counter sim                       # TEST=smoke, random SEED, PARAMS=WIDTH=8
make -C hw/ip/counter sim PARAMS="WIDTH=4 MAX=9" WAVES=1
make -C hw/ip/counter waves PARAMS="WIDTH=4 MAX=9"
make sim IP=counter TEST=smoke                  # from the repository root
make -C hw/ip/counter sim SIM=verilator         # or SIM=vcs
```

Outputs: `build/counter/<cfg>/{lint,sim}/`, e.g. `build/counter/WIDTH-4_MAX-9/sim/smoke_s<seed>.log`.

## Smoke test (`TEST=smoke`, the only test)

Inputs change on the falling edge; outputs are compared on the next falling edge with a
reference model in the testbench. First line `CONFIG: TEST=… SEED=… WIDTH=… MAX=…`,
last line exactly one `TEST PASSED (<n> checks)` or `TEST FAILED (…)`.

1. Asynchronous reset (outputs checked without a clock edge), idle with `en` = 0.
2. `en` = 1 for `2*(MAX+1)+3` cycles: every value checked, `wrap` must pulse exactly
   twice (`NumCountCycles/(MAX+1)` for `MAX` < 3).
3. `en` toggling: the value holds while `en` = 0.
4. `clr` alone, `clr` with `en` (priority), `clr` at `MAX` (no wrap pulse).
5. Wrap directly after a clear; asynchronous reset in the middle of counting.
6. Watchdog: `4*(MAX+1)+1000` cycles -> `TEST FAILED (timeout …)`. Unsupported
   configurations (`WIDTH` > 20, `MAX` > `2**WIDTH-1`) end with `TEST FAILED`.

## Results

| Command | Verilator 5.013 | VCS 2024.09-SP1-1 |
|---|---|---|
| `sim` (WIDTH=8) | PASS, 1047 checks | PASS, 1047 checks |
| `sim PARAMS="WIDTH=4 MAX=9" WAVES=1` | PASS, 63 checks, FST | PASS, 63 checks, FSDB |
| `lint` | PASS (verilator), PASS (SpyGlass 0 errors / 0 warnings), PASS (VC SpyGlass 0 / 0) | |
| deliberate bug: wrap at `MAX-1` | `TEST FAILED (271 errors in 1047 checks)`, `make sim` exit 2 | ERROR lines + `TEST FAILED`, `make sim` exit 2; `make check-all` FAIL |

## Known limitations

* `WIDTH` <= 20 in the smoke test (run time grows with `2**WIDTH`).
* Verilator 5.013 needs g++ >= 10 for `--timing`; env.sh selects GCC 12.4 on the cloud.
