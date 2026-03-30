// =============================================================================
// Module Name:  nco_spwm
// Description:  Slave Numerically Controlled Oscillator (NCO) designed for 
//               three-phase reference generation. This module operates in 
//               synchronization with a master dqz reference and incorporates 
//               active phase lead correction to compensate for loop drift.
//
// Parameters:
//   - WORD_SIZE: 18 bits (Signed output resolution for high-fidelity waves).
//   - ADDR_SIZE: 10 bits (ROM address depth per quadrant).
//   - ACC_WIDTH: 32 bits (Phase accumulator width).
//
// Architecture:
//   - Slave Synchronization: Phase accumulation is slaved to an external 
//               'phase_acc_dqz' reference to ensure grid alignment.
//   - Phase Correction: Uses 'LEAD' to offset propagation delays and
//               system-level phase drift.
//   - Polyphase Generation: Uses 120-degree (32'h5555_5555) and 240-degree 
//               (32'hAAAA_AAAA) offsets to generate balanced three-phase 
//               outputs (a_out, b_out, c_out).
//   - Dual ROM Architecture: Employs two independent Quarter-Wave Symmetry 
//               Lookup Tables to provide simultaneous four-channel 
//               sinusoidal data.
//   - Quadrant Symmetry: Top 2 bits of the corrected phase manage sign 
//               selection and address mirroring for memory efficiency.
//
// Performance Metrics:
//   - SQNR:     ~110.1 dB (Based on 18-bit amplitude quantization).
//   - SFDR:     ~72.0 dB  (Based on 10-bit phase truncation).
//   - Resolution: 32-bit frequency resolution (f_clk / 2^32).
// =============================================================================

module nco_spwm #(
    parameter WORD_SIZE = 18,
    parameter ADDR_SIZE = 10,
    parameter ACC_WIDTH = 32
)(
    input  wire clk,
    input  wire clk_en,
    input  wire reset, 
    input  wire [ACC_WIDTH-1:0] phase_acc_dqz,
    input  wire signed [ACC_WIDTH-1:0] fcw,
    input  wire signed [ACC_WIDTH-1:0] freq_in_dqz,
    output wire signed [WORD_SIZE-1:0] sine,
    output wire signed [WORD_SIZE-1:0] a_out,
    output wire signed [WORD_SIZE-1:0] b_out, // Phase B
    output wire signed [WORD_SIZE-1:0] c_out  // Phase C
);

    localparam SIGN_BIT   = ACC_WIDTH - 1; // Bit 31
    localparam MIRROR_BIT = ACC_WIDTH - 2; // Bit 30
    localparam ADDR_START = ACC_WIDTH - 3; // Bit 29
    
    // Existing Phase Offsets
    localparam COS_OFFSET = 32'h4000_0000; // Cos offset
    localparam LEAD = 32'd178956971; // Correction for lead
    
    // 3-Phase Offsets (120 and 240 degrees)
    localparam PHASE_B_OFFSET = 32'h5555_5555; // 120 degrees
    localparam PHASE_C_OFFSET = 32'hAAAA_AAAA; // 240 degrees (or -120)

    // ----- Accumulators ----- //
    reg  [ACC_WIDTH-1:0] phase_acc; 
    wire [ACC_WIDTH-1:0] phase_acc_lead; 
    wire [ACC_WIDTH-1:0] phase_cos;
    wire [ACC_WIDTH-1:0] phase_b;
    wire [ACC_WIDTH-1:0] phase_c;

    // ----- Data ----- //
    wire signed [WORD_SIZE-1:0] data_sin, data_cos;
    wire signed [WORD_SIZE-1:0] data_b, data_c;

    // ----- Pipelines ----- //
    reg sin_sign_pipe;
    reg cos_sign_pipe;
    reg b_sign_pipe;
    reg c_sign_pipe;

    // ----- Phase Accumulators ----- //
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            phase_acc <= 0;
        end else if (clk_en) begin
			phase_acc <= phase_acc_dqz;
		end else begin
            phase_acc <= phase_acc + fcw;
        end
    end

    assign phase_acc_lead = phase_acc - LEAD;
    assign phase_cos = phase_acc_lead - COS_OFFSET; 
    assign phase_b   = phase_acc_lead - PHASE_B_OFFSET; // Phase B Shift
    assign phase_c   = phase_acc_lead - PHASE_C_OFFSET; // Phase C Shift

    // ----- Combinational Address Generation ----- //
    wire [ADDR_SIZE-1:0] addr_sin = phase_acc_lead[MIRROR_BIT] ? 
        ~phase_acc_lead[ADDR_START:ADDR_START-ADDR_SIZE+1] : phase_acc_lead[ADDR_START:ADDR_START-ADDR_SIZE+1];
        
    wire [ADDR_SIZE-1:0] addr_cos = phase_cos[MIRROR_BIT] ? 
        ~phase_cos[ADDR_START:ADDR_START-ADDR_SIZE+1] : phase_cos[ADDR_START:ADDR_START-ADDR_SIZE+1];
        
    wire [ADDR_SIZE-1:0] addr_b = phase_b[MIRROR_BIT] ? 
        ~phase_b[ADDR_START:ADDR_START-ADDR_SIZE+1] : phase_b[ADDR_START:ADDR_START-ADDR_SIZE+1];
        
    wire [ADDR_SIZE-1:0] addr_c = phase_c[MIRROR_BIT] ? 
        ~phase_c[ADDR_START:ADDR_START-ADDR_SIZE+1] : phase_c[ADDR_START:ADDR_START-ADDR_SIZE+1];

    // ----- Sign Selection ----- //
    always @(*) begin
        if (reset) begin
            sin_sign_pipe <= 0;
            cos_sign_pipe <= 0;
            b_sign_pipe   <= 0;
            c_sign_pipe   <= 0;
        end else begin
            sin_sign_pipe <= phase_acc_lead[SIGN_BIT];
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