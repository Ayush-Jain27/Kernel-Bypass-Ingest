// -----------------------------------------------------------------------------
// blink: M0 bring-up heartbeat.
//
// Divides the incoming clock down to a human-visible rate and drives a binary
// counter onto the LEDs. Its only job is to prove, independently of anything on
// the PS side, that the PL is clocked, configured, and driving real pins.
//
// A counting pattern is used rather than a single toggling LED because it also
// makes the divider ratio observable: if the clock is not what you think it is,
// a counter shows it immediately whereas a lone blink does not.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module blink #(
    // Frequency of `clk`. On the AUP-ZU3 this is pl_clk0 out of the PS.
    parameter int unsigned CLK_HZ = 100_000_000,
    // How often the LED counter advances.
    parameter int unsigned TICK_HZ = 2,
    parameter int unsigned NUM_LEDS = 8
) (
    input  logic                clk,
    input  logic                rst_n,   // active low, from pl_resetn0
    output logic [NUM_LEDS-1:0] led      // active high on this board
);

    localparam int unsigned DIV = CLK_HZ / TICK_HZ;
    // $clog2(DIV) bits hold 0..DIV-1 for any DIV, since 2**$clog2(DIV) >= DIV.
    localparam int unsigned CW = (DIV <= 1) ? 1 : $clog2(DIV);

    localparam logic [CW-1:0] DIV_MAX = CW'(DIV - 1);

    logic [CW-1:0] div_q;
    logic          tick;

    assign tick = (div_q == DIV_MAX);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            div_q <= '0;
        end else begin
            div_q <= tick ? '0 : (div_q + 1'b1);
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            led <= '0;
        end else if (tick) begin
            led <= led + 1'b1;
        end
    end

endmodule
