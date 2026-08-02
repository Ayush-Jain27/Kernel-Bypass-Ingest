// -----------------------------------------------------------------------------
// Self-checking testbench for blink.
//
// Runs the DUT with a small divider so the behaviour under test is reachable in
// a few hundred cycles rather than a few hundred million. The parameters are the
// only thing that changes between here and the board.
//
// Checks:
//   1. reset drives the LEDs to zero and holds them there
//   2. the counter advances exactly every DIV clocks, not approximately
//   3. it wraps cleanly at the top of the LED range
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module blink_tb;

    localparam int unsigned CLK_HZ   = 100;
    localparam int unsigned TICK_HZ  = 10;
    localparam int unsigned NUM_LEDS = 4;
    localparam int unsigned DIV      = CLK_HZ / TICK_HZ;   // 10 clocks per tick

    localparam time CLK_PERIOD = 10ns;

    logic                clk;
    logic                rst_n;
    logic [NUM_LEDS-1:0] led;

    int unsigned errors = 0;

    blink #(
        .CLK_HZ   (CLK_HZ),
        .TICK_HZ  (TICK_HZ),
        .NUM_LEDS (NUM_LEDS)
    ) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .led   (led)
    );

    // ---- clock ----
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // ---- helpers ----
    task automatic check(input logic cond, input string msg);
        if (!cond) begin
            errors++;
            $error("[%0t] FAIL: %s", $time, msg);
        end
    endtask

    // ---- stimulus and checks ----
    initial begin
        logic [NUM_LEDS-1:0] prev;

        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        #1;
        check(led === '0, $sformatf("LEDs should be 0 during reset, got %0h", led));

        // Hold reset a while longer and confirm nothing creeps.
        repeat (DIV * 2) @(posedge clk);
        #1;
        check(led === '0, $sformatf("LEDs should stay 0 while held in reset, got %0h", led));

        // Release reset on the falling edge. Driving rst_n on the same posedge
        // the DUT samples is a race: whether the release is seen on that edge or
        // the next one depends on scheduler order, which shifts the first tick
        // by one clock. That is a stimulus artefact, not a design property, and
        // it will silently reappear in every future testbench if not handled
        // here as a matter of habit.
        @(negedge clk);
        rst_n = 1'b1;

        // Check 2: the counter must advance exactly every DIV clocks.
        // After release, the first tick lands DIV clocks later.
        for (int unsigned t = 0; t < 3 * (1 << NUM_LEDS); t++) begin
            prev = led;

            // For DIV-1 clocks the output must not move.
            for (int unsigned c = 0; c < DIV - 1; c++) begin
                @(posedge clk);
                #1;
                check(led === prev,
                      $sformatf("tick %0d: LEDs moved early at sub-cycle %0d (%0h -> %0h)",
                                t, c, prev, led));
            end

            // On the DIV'th clock it must advance by exactly one, wrapping.
            @(posedge clk);
            #1;
            check(led === NUM_LEDS'(prev + 1),
                  $sformatf("tick %0d: expected %0h, got %0h",
                            t, NUM_LEDS'(prev + 1), led));
        end

        // Check 3: reset must still work after running.
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        #1;
        check(led === '0, $sformatf("LEDs should return to 0 on re-assert of reset, got %0h", led));

        $display("");
        if (errors == 0) begin
            $display("================ blink_tb PASSED ================");
        end else begin
            $display("================ blink_tb FAILED: %0d error(s) ================", errors);
        end
        $display("");
        $finish;
    end

    // Safety net so a broken DUT cannot hang the run.
    initial begin
        #1ms;
        $display("================ blink_tb FAILED: timeout ================");
        $fatal(1, "timeout");
    end

endmodule
