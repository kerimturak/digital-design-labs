# counter -- design

```
             +-------------------------------+
  en  -----> |  next-state logic             |   count_d   +---------+  count_q
  clr -----> |  clr ? 0 :                    | ----------> | D     Q |----------> count
             |  en  ? (count_q==MAX ? 0      |             |  >clk   |
             |              : count_q + 1)   |   wrap_d    +---------+  wrap_q
             |       : count_q               | ----------> | D     Q |----------> wrap
             |  wrap_d = !clr & en &         |             |  >clk   |
             |           (count_q == MAX)    |             +---------+
             +-------------------------------+                  ^ rst_n (async, active low)
                     ^ count_q (feedback)
```

* One `always_comb` block computes `count_d` and `wrap_d`; every output gets a default
  first, so no latch can be inferred. One `always_ff` with asynchronous active-low reset
  holds `count_q` and `wrap_q` (lowRISC `_d`/`_q` naming).
* `MAX` is converted once to a `WIDTH`-bit localparam (`MaxVal`), so the comparison has
  equal operand widths (clean under `verilator -Wall`).
* `wrap` is registered rather than decoded from `count == 0`: a decode would also be high
  after reset and after a clear, and it would be a combinational output.
* Cost: `WIDTH` + 1 flip-flops, a `WIDTH`-bit incrementer and a `WIDTH`-bit equality
  compare. (Synthesis starts in Lab P1; this block is not synthesized in the program.)
