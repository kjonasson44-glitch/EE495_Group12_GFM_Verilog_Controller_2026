// =============================================================================
// Module Name:  nco_dqz
// Description:  Numerically Controlled Oscillator (NCO) utilizing 
//               Quarter-Wave Symmetry Lookup Tables.
//
// Parameters:
//   - WORD_SIZE: 18 bits (Signed output resolution)
//   - ADDR_SIZE: 10 bits (ROM address depth per quadrant)
//   - ACC_SIZE:  32 bits (Phase accumulator width)
//
// Architecture:
//   - Accumulator: 32-bit adder provides a frequency resolution of 
//                  f_clk / 2^32.
//   - Phase Map:   Top 2 bits of phase_acc manage quadrant symmetry.
//                  Bit [31] : Sign selection
//                  Bit [30] : Address mirroring
//   - Look-up:     1024-word ROM (10-bit address) effectively yields 12-bit 
//                  phase resolution with symmetry logic.
//   - Latency:     3 Clock Cycles (1: Addr Gen, 2: ROM Access, 3: Sign Adj).
//
// Performance Metrics (Theoretical):
//   - SQNR:        ~110.1 dB (Based on 18-bit amplitude quantization)
//   - SFDR:        ~72.0 dB  (Based on 10-bit phase truncation)
//
// Target App:   Three-phase IPLL / Grid-Synchronization Control Loops.
// =============================================================================

module nco_dqz #(
    parameter WORD_SIZE = 18,
    parameter ADDR_SIZE = 10,
    parameter ACC_WIDTH = 32
)(
    input  wire clk,
    input  wire clk_en,
    input  wire reset,
    input  wire signed [ACC_WIDTH-1:0] fcw, 
    output wire signed [WORD_SIZE-1:0] sine,   // Changed to wire
    output wire signed [WORD_SIZE-1:0] cosine  // Changed to wire
);

localparam SIGN_BIT   = ACC_WIDTH - 1; // Bit 31
localparam MIRROR_BIT = ACC_WIDTH - 2; // Bit 30
localparam ADDR_START = ACC_WIDTH - 3; // Bit 29
localparam COS_OFFSET = 32'h4000_0000; 

// ----- Accumlators ----- //
reg  [ACC_WIDTH-1:0] phase_acc; 
wire [ACC_WIDTH-1:0] phase_cos;

// ----- Data ----- //
wire signed [WORD_SIZE-1:0] data_sin, data_cos;

// ----- Pipelines ----- //
reg sin_sign_pipe;
reg cos_sign_pipe;

// ----- Phase Accumulators ----- //
always @(posedge clk) begin
    if (reset) phase_acc <= 0;
    else if (clk_en) begin   
        phase_acc <= phase_acc + fcw;
    end
end

assign phase_cos = phase_acc - COS_OFFSET; 

// ----- Combinational Address Generation ----- //
// Eliminated 1 clock cycle of delay here
wire [ADDR_SIZE-1:0] addr_sin = phase_acc[MIRROR_BIT] ? ~phase_acc[ADDR_START:ADDR_START-ADDR_SIZE+1] : phase_acc[ADDR_START:ADDR_START-ADDR_SIZE+1];
wire [ADDR_SIZE-1:0] addr_cos = phase_cos[MIRROR_BIT] ? ~phase_cos[ADDR_START:ADDR_START-ADDR_SIZE+1] : phase_cos[ADDR_START:ADDR_START-ADDR_SIZE+1];

// ----- Sign Pipelining ----- //
// Only 1 pipeline stage needed now to match the 1-cycle ROM delay
always @* begin
    if (reset) begin
        sin_sign_pipe <= 0;
        cos_sign_pipe <= 0;
    end else begin
        sin_sign_pipe <= phase_acc[SIGN_BIT];
        cos_sign_pipe <= phase_cos[SIGN_BIT];
    end
end

sine_rom lut (
    .clk(clk),
    .addr_a(addr_sin),
    .data_a(data_sin),
    .addr_b(addr_cos),
    .data_b(data_cos)
);

// ----- Combinational Amplitude Negation ----- //
// Eliminated 1 clock cycle of delay here
assign cosine   = sin_sign_pipe ? -data_sin : data_sin;
assign sine = cos_sign_pipe ?  -data_cos : data_cos;

endmodule