// =============================================================================
// Module Name:  nco_spvm
// Description:  Numerically Controlled Oscillator (NCO) utilizing 
//               Quarter-Wave Symmetry Lookup Tables.
//
// Revision History:
// -----------------------------------------------------------------------------
// Version | Date       | Author   | Description
// -----------------------------------------------------------------------------
// 1.0     | 2026-01-06 | HW_Dev   | Initial release. Pipelined architecture with 
//                                 3-cycle latency (Addr Gen, ROM, Sign Adj).
// 1.1     | 2026-02-26 | HW_Dev   | Optimized for Type I PLL. Converted Addr Gen
//                                 and Sign Adj to combinational logic to reduce 
//                                 latency. Added clk_en support.
// 1.2     | 2026-03-09 | AI       | Added 120-degree phase offsets for b_out 
//                                 and c_out via a secondary ROM instance.
// -----------------------------------------------------------------------------
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
//   - Latency:     Reduced (Combinational Addr Gen & Sign Adj).
//
// Performance Metrics (Theoretical):
//   - SQNR:        ~110.1 dB (Based on 18-bit amplitude quantization)
//   - SFDR:        ~72.0 dB  (Based on 10-bit phase truncation)
//
// Target App:   Three-phase IPLL / Grid-Synchronization Control Loops.
// =============================================================================

module nco_spvm #(
    parameter WORD_SIZE = 18,
    parameter ADDR_SIZE = 10,
    parameter ACC_WIDTH = 32
)(
    input  wire clk,
    input  wire clk_en,
    input  wire reset,
    input  wire signed [ACC_WIDTH-1:0] fcw, 
	 input wire [ACC_WIDTH-1:0] phase_acc_dqz,
    output wire signed [WORD_SIZE-1:0] sine,   
    output wire signed [WORD_SIZE-1:0] a_out,
    output wire signed [WORD_SIZE-1:0] b_out, // Added Phase B
    output wire signed [WORD_SIZE-1:0] c_out  // Added Phase C
);

    localparam SIGN_BIT   = ACC_WIDTH - 1; // Bit 31
    localparam MIRROR_BIT = ACC_WIDTH - 2; // Bit 30
    localparam ADDR_START = ACC_WIDTH - 3; // Bit 29
    
    // Existing Phase Offsets
    localparam COS_OFFSET = 32'h4000_0000; // Cos offset is different here - DO NOT TOUCH
    localparam LEAD_CORRECTION = 32'd178956971; // Correction for SPVM lead
    
    // New 3-Phase Offsets (120 and 240 degrees)
    localparam PHASE_B_OFFSET = 32'h5555_5555; // 120 degrees
    localparam PHASE_C_OFFSET = 32'hAAAA_AAAA; // 240 degrees (or -120)

    // ----- Accumulators ----- //
    reg  [ACC_WIDTH-1:0] phase_acc_old; 
    wire [ACC_WIDTH-1:0] phase_acc; 
    wire [ACC_WIDTH-1:0] phase_cos;
    wire [ACC_WIDTH-1:0] phase_b; // Added
    wire [ACC_WIDTH-1:0] phase_c; // Added

    // ----- Data ----- //
    wire signed [WORD_SIZE-1:0] data_sin, data_cos;
    wire signed [WORD_SIZE-1:0] data_b, data_c; // Added

    // ----- Pipelines ----- //
    reg sin_sign_pipe;
    reg cos_sign_pipe;
    reg b_sign_pipe; // Added
    reg c_sign_pipe; // Added

    // ----- Phase Accumulators ----- //
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            phase_acc_old <= phase_acc_dqz;
        end else if (clk_en) begin
				phase_acc_old <= phase_acc_dqz;
			end
		  else begin   
            // Note: clk_en was commented out in your original, leaving it as you had it
            phase_acc_old <= phase_acc_old + fcw;
        end
		   // phace_acc_old must be updated to phase_acc from dqz on every clk 
    end

    assign phase_acc = phase_acc_old; // - LEAD_CORRECTION
    assign phase_cos = phase_acc - COS_OFFSET; 
    assign phase_b   = phase_acc - PHASE_B_OFFSET; // Phase B Shift
    assign phase_c   = phase_acc - PHASE_C_OFFSET; // Phase C Shift

    // ----- Combinational Address Generation ----- //
    wire [ADDR_SIZE-1:0] addr_sin = phase_acc[MIRROR_BIT] ? 
        ~phase_acc[ADDR_START:ADDR_START-ADDR_SIZE+1] : phase_acc[ADDR_START:ADDR_START-ADDR_SIZE+1];
        
    wire [ADDR_SIZE-1:0] addr_cos = phase_cos[MIRROR_BIT] ? 
        ~phase_cos[ADDR_START:ADDR_START-ADDR_SIZE+1] : phase_cos[ADDR_START:ADDR_START-ADDR_SIZE+1];
        
    wire [ADDR_SIZE-1:0] addr_b = phase_b[MIRROR_BIT] ? 
        ~phase_b[ADDR_START:ADDR_START-ADDR_SIZE+1] : phase_b[ADDR_START:ADDR_START-ADDR_SIZE+1];
        
    wire [ADDR_SIZE-1:0] addr_c = phase_c[MIRROR_BIT] ? 
        ~phase_c[ADDR_START:ADDR_START-ADDR_SIZE+1] : phase_c[ADDR_START:ADDR_START-ADDR_SIZE+1];

    // ----- Sign Selection ----- //
    always @* begin
        if (reset) begin
            sin_sign_pipe <= 0;
            cos_sign_pipe <= 0;
            b_sign_pipe   <= 0;
            c_sign_pipe   <= 0;
        end else begin
            sin_sign_pipe <= phase_acc[SIGN_BIT];
            cos_sign_pipe <= phase_cos[SIGN_BIT];
            b_sign_pipe   <= phase_b[SIGN_BIT];
            c_sign_pipe   <= phase_c[SIGN_BIT];
        end
    end

    // ROM 1: Handles Phase A and Cosine
    sine_rom lut_a_cos (
        .clk(clk),
        .addr_a(addr_sin),
        .data_a(data_sin),
        .addr_b(addr_cos),
        .data_b(data_cos)
    );

    // ROM 2: Handles Phase B and Phase C
    sine_rom lut_b_c (
        .clk(clk),
        .addr_a(addr_b),
        .data_a(data_b),
        .addr_b(addr_c),
        .data_b(data_c)
    );

    // ----- Combinational Amplitude Negation ----- //
    assign a_out = sin_sign_pipe ? -data_sin : data_sin;
    assign sine  = cos_sign_pipe ? -data_cos : data_cos;
    assign b_out = b_sign_pipe   ? -data_b   : data_b;
    assign c_out = c_sign_pipe   ? -data_c   : data_c;

endmodule