// counter -- parameterized up-counter with enable, synchronous clear and a wrap pulse.
//
// Hello-world block of Lab L0: it exists to prove the repository and the flow.
// Specification: hw/ip/counter/doc/spec.md, micro-architecture: doc/design.md.
//
// * count runs 0, 1, ..., MAX, 0, ... on every rising edge of clk with en = 1.
// * clr is a synchronous clear and has priority over en (no wrap pulse on a clear).
// * wrap is a registered one-cycle pulse: it is high in the cycle in which count has
//   just gone from MAX to 0.
// * rst_n is an asynchronous, active-low reset: count = 0, wrap = 0.

module counter #(
  parameter int unsigned WIDTH = 8,               // counter width in bits, >= 1
  parameter int unsigned MAX   = 2**WIDTH - 1     // last value before the wrap, <= 2**WIDTH-1
) (
  input  logic             clk,
  input  logic             rst_n,
  input  logic             en,
  input  logic             clr,
  output logic [WIDTH-1:0] count,
  output logic             wrap
);

  // MAX as a WIDTH-bit value, so that the compare below has equal operand widths.
  localparam logic [WIDTH-1:0] MaxVal = WIDTH'(MAX);

  logic [WIDTH-1:0] count_d, count_q;
  logic             wrap_d, wrap_q;

  // Next-state logic. Every output of the always_comb block gets a default first, so no
  // latch can be inferred.
  always_comb begin
    count_d = count_q;
    wrap_d  = 1'b0;
    if (clr) begin
      count_d = '0;
    end else if (en) begin
      if (count_q == MaxVal) begin
        count_d = '0;
        wrap_d  = 1'b1;
      end else begin
        count_d = count_q + 1'b1;
      end
    end
  end

  // State registers: asynchronous active-low reset.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count_q <= '0;
      wrap_q  <= 1'b0;
    end else begin
      count_q <= count_d;
      wrap_q  <= wrap_d;
    end
  end

  assign count = count_q;
  assign wrap  = wrap_q;

endmodule
