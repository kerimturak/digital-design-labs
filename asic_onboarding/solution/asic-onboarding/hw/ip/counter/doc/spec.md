# counter -- specification

Hello-world block of Lab L0. It exists to prove the repository and the flow.

## Parameters

| Parameter | Type | Default | Legal range | Description |
|---|---|---|---|---|
| `WIDTH` | int unsigned | 8 | >= 1 | width of `count` |
| `MAX` | int unsigned | `2**WIDTH-1` | 0 .. `2**WIDTH-1` | last value before the wrap |

`MAX` is evaluated after `WIDTH`, so overriding only `WIDTH` keeps the full range.
A `MAX` above `2**WIDTH-1` is illegal (it would be truncated to `WIDTH` bits).

## Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | clock, rising edge |
| `rst_n` | input | 1 | asynchronous reset, active low |
| `en` | input | 1 | count enable |
| `clr` | input | 1 | synchronous clear, priority over `en` |
| `count` | output | `WIDTH` | current value (registered) |
| `wrap` | output | 1 | one-cycle pulse when `count` goes from `MAX` to 0 (registered) |

## Behavior

On every rising edge of `clk` (with `rst_n` = 1):

| `clr` | `en` | `count` (next) | `wrap` (next) |
|---|---|---|---|
| 1 | x | 0 | 0 |
| 0 | 0 | `count` | 0 |
| 0 | 1, `count` != `MAX` | `count` + 1 | 0 |
| 0 | 1, `count` == `MAX` | 0 | 1 |

* `rst_n` = 0 sets `count` = 0 and `wrap` = 0 immediately (no clock edge needed).
* `wrap` is high in exactly the cycle in which `count` shows the 0 that follows `MAX`;
  it is never high for two consecutive cycles unless `MAX` = 0 and `en` stays 1
  (then the counter wraps on every enabled cycle).
* A clear while `count` == `MAX` and `en` = 1 gives `count` = 0 **without** a wrap pulse:
  the clear wins.
* Both outputs come directly from flip-flops (no combinational path from inputs to
  outputs).
