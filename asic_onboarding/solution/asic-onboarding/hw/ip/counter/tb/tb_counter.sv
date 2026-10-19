// tb_counter -- directed smoke testbench of counter (Lab L0).
//
// Inputs are driven on the falling edge of clk, outputs are checked on the next falling
// edge, i.e. half a cycle after the rising edge that updated them (no race with the DUT;
// Lab R2 explains why). The expected values come from a reference model in this file.
//
// Plusargs: +TEST=<name> (default smoke), +SEED=<n> (printed only; random stimulus
// starts in Lab V1).
// Last line of every run: exactly one "TEST PASSED" or "TEST FAILED (...)".

module tb_counter #(
  parameter int WIDTH = 8,
  parameter int MAX   = 2**WIDTH - 1
);

  // Cycles of the "count through two wraps" phase, as required by the lab.
  localparam int NumCountCycles = 2 * (MAX + 1) + 3;
  // Watchdog: generous bound on the cycles of the whole test, scales with MAX.
  localparam int TimeoutCycles  = 4 * (MAX + 1) + 1000;
  localparam logic [WIDTH-1:0] MaxVal = WIDTH'(MAX);

  logic             clk = 1'b0;
  logic             rst_n;
  logic             en;
  logic             clr;
  logic [WIDTH-1:0] count;
  logic             wrap;

  int unsigned n_errors = 0;
  int unsigned n_checks = 0;
  int unsigned n_wraps  = 0;   // wrap pulses observed since the last clear_wrap_count()

  // Reference model state: expected outputs after the most recent rising edge.
  logic [WIDTH-1:0] exp_count;
  logic             exp_wrap;

  initial forever #5 clk = ~clk;   // 100 MHz

  counter #(
    .WIDTH(WIDTH),
    .MAX  (MAX)
  ) dut (
    .clk  (clk),
    .rst_n(rst_n),
    .en   (en),
    .clr  (clr),
    .count(count),
    .wrap (wrap)
  );

  // ---------------------------------------------------------------------------------------
  // Checking (the first 10 mismatches are printed, all are counted)
  // ---------------------------------------------------------------------------------------
  function automatic void check(input string what);
    n_checks++;
    if (wrap === 1'b1) n_wraps++;
    if (count !== exp_count || wrap !== exp_wrap) begin
      n_errors++;
      if (n_errors <= 10) $display("ERROR: %0t %s: count=%0d wrap=%b, expected count=%0d wrap=%b",
               $time, what, count, wrap, exp_count, exp_wrap);
    end
  endfunction

  // One clock cycle: called at a falling edge; drives en/clr, advances the reference model
  // across the next rising edge, waits for the following falling edge and checks.
  task automatic cycle(input logic en_i, input logic clr_i, input string what);
    en  = en_i;
    clr = clr_i;
    exp_wrap = 1'b0;
    if (clr_i) begin
      exp_count = '0;
    end else if (en_i) begin
      if (exp_count == MaxVal) begin
        exp_count = '0;
        exp_wrap  = 1'b1;
      end else begin
        exp_count = exp_count + 1'b1;
      end
    end
    @(negedge clk);
    check(what);
  endtask

  // Asynchronous reset: assert between clock edges, check that the outputs clear
  // immediately (without a clock edge), hold for a few cycles, release at a falling edge.
  task automatic apply_reset();
    en  = 1'b0;
    clr = 1'b0;
    #2;
    rst_n = 1'b0;
    #1;
    exp_count = '0;
    exp_wrap  = 1'b0;
    check("async reset");
    repeat (3) @(negedge clk);
    check("in reset");
    rst_n = 1'b1;
  endtask

  // ---------------------------------------------------------------------------------------
  // Test
  // ---------------------------------------------------------------------------------------
  task automatic test_smoke();
    int exp_wraps;

    // 1. Reset, then en = 0: the counter holds 0.
    apply_reset();
    repeat (3) cycle(1'b0, 1'b0, "idle after reset");

    // 2. Count for 2*(MAX+1)+3 cycles: every value is checked, wrap must pulse exactly
    //    twice (MAX >= 3; for tiny MAX the expected number follows from the cycle count).
    n_wraps = 0;
    for (int i = 0; i < NumCountCycles; i++) cycle(1'b1, 1'b0, "count");
    exp_wraps = NumCountCycles / (MAX + 1);
    n_checks++;
    if (n_wraps != exp_wraps) begin
      n_errors++;
      $display("ERROR: wrap pulsed %0d times in %0d enabled cycles, expected %0d",
               n_wraps, NumCountCycles, exp_wraps);
    end

    // 3. en toggling: the counter holds while en = 0.
    cycle(1'b0, 1'b0, "hold");
    cycle(1'b1, 1'b0, "count");
    cycle(1'b0, 1'b0, "hold");
    cycle(1'b0, 1'b0, "hold");
    cycle(1'b1, 1'b0, "count");

    // 4. clr: clears without en, has priority over en, and a clear at MAX gives no wrap.
    cycle(1'b0, 1'b1, "clr");
    cycle(1'b1, 1'b0, "count after clr");
    cycle(1'b1, 1'b1, "clr with en (priority)");
    while (exp_count != MaxVal) cycle(1'b1, 1'b0, "count to MAX");
    cycle(1'b1, 1'b1, "clr at MAX (no wrap)");
    cycle(1'b1, 1'b0, "count after clr at MAX");

    // 5. Wrap directly after a clear (MAX = 0 wraps on every enabled cycle).
    while (exp_count != MaxVal) cycle(1'b1, 1'b0, "count to MAX");
    cycle(1'b1, 1'b0, "wrap");
    cycle(1'b0, 1'b0, "hold after wrap");

    // 6. Asynchronous reset in the middle of counting.
    cycle(1'b1, 1'b0, "count");
    apply_reset();
    cycle(1'b1, 1'b0, "count after reset");
    cycle(1'b0, 1'b0, "hold");
  endtask

  initial begin
    string test = "smoke";
    int unsigned seed = 0;
    void'($value$plusargs("TEST=%s", test));
    void'($value$plusargs("SEED=%d", seed));
    $display("CONFIG: TEST=%s SEED=%0d WIDTH=%0d MAX=%0d", test, seed, WIDTH, MAX);

    rst_n     = 1'b1;
    en        = 1'b0;
    clr       = 1'b0;
    exp_count = '0;
    exp_wrap  = 1'b0;

    if (WIDTH < 1 || WIDTH > 20 || MAX < 0 || MAX > 2**WIDTH - 1) begin
      // The test runs ~2*(MAX+1) cycles: WIDTH > 20 takes too long for a smoke test.
      $display("TEST FAILED (unsupported configuration WIDTH=%0d MAX=%0d)", WIDTH, MAX);
      $finish;
    end

    case (test)
      "smoke": test_smoke();
      default: begin
        $display("TEST FAILED (unknown test '%s')", test);
        $finish;
      end
    endcase

    if (n_errors == 0) $display("TEST PASSED (%0d checks)", n_checks);
    else               $display("TEST FAILED (%0d errors in %0d checks)", n_errors, n_checks);
    $finish;
  end

  // Watchdog: a hung test must end with TEST FAILED, not run forever.
  initial begin
    repeat (TimeoutCycles) @(posedge clk);
    $display("TEST FAILED (timeout after %0d cycles)", TimeoutCycles);
    $finish;
  end

endmodule
