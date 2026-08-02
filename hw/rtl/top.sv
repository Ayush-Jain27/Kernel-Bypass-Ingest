// -----------------------------------------------------------------------------
// Top level.
//
// The block design holds the processing system and nothing else. All custom
// fabric logic lives here, in SystemVerilog, instantiated alongside the BD
// wrapper. Vivado's module-reference flow will not accept SystemVerilog as the
// top of a referenced module, and more importantly this keeps the PL design
// readable as source rather than as a diagram.
//
// M0: a heartbeat on the LEDs, clocked from pl_clk0.
// M1 onward: the traffic generator, the free-running cycle counter, the parse
// and filter stage and the DMA front end all land here.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module top (
    output logic [7:0] led
);

    // Clock and reset out of the PS. pl_clk0 is configured to 100 MHz by the
    // block design, and it is the reference every fabric cycle count in this
    // project is denominated in.
    logic pl_clk0;
    logic pl_resetn0;

    sys_wrapper u_sys (
        .pl_clk0    (pl_clk0),
        .pl_resetn0 (pl_resetn0)
    );

    blink #(
        .CLK_HZ   (100_000_000),
        .TICK_HZ  (2),
        .NUM_LEDS (8)
    ) u_blink (
        .clk   (pl_clk0),
        .rst_n (pl_resetn0),
        .led   (led)
    );

endmodule
