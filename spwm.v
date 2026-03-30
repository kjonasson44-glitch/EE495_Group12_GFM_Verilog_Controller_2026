// =============================================================================
// Module Name:  spwm
// Description:  Three-Phase Sinusoidal Pulse Width Modulation (SPWM) Generator 
//               using a Triangular Carrier and NCO-based Reference.
//
// Parameters:
//   - WORD_SIZE: 18 bits (Internal signal resolution)
//   - ACC_WIDTH: 32 bits (Phase accumulator width for NCOs)
//
// Architecture:
//   - Reference:   Uses an internal NCO (nco_spvm) to generate three-phase 
//                  fundamental sinusoids (a_out, b_out, c_out).
//   - Scaling:     Implements a signed multiplier for modulation index control 
//                  via the 'scale' input.
//   - Carrier:     Integrates a dedicated carrier NCO (carrier_gen) to produce 
//                  a high-frequency triangular waveform.
//   - Comparison:  Digital comparator logic generates PWM pulses (u, v, w) 
//                  by comparing scaled sine references against the carrier. 
//
// Performance Metrics:
//   - Resolution:  18-bit fixed-point precision for reference waveforms.
//   - Control:     Independent frequency control for both fundamental (freq_in) 
//                  and carrier frequency (carrier_fcw).
//
// =============================================================================

module spwm #(
    parameter WORD_SIZE = 18,
    parameter ACC_WIDTH = 32
)(
    input  wire clk,
    input  wire clk_en,
    input  wire reset,
    input  wire [ACC_WIDTH-1:0] freq_in,      // Frequency for the fundamental sine wave
    input  wire [ACC_WIDTH-1:0] carrier_fcw,  // Frequency control for the triangle carrier
    input  wire [ACC_WIDTH-1:0] phase_acc_dqz,
    input  wire signed [WORD_SIZE-1:0] q_in, d_in,
    input  wire signed [15:0] scale,
    output reg  pwm_u, pwm_v, pwm_w
);

    // ----- Internal Signals -----
    wire signed [WORD_SIZE-1:0] sine, cosine;
    wire signed [WORD_SIZE-1:0] carrier_val;
	
	(* noprune *) wire signed [WORD_SIZE-1:0] a_out;
    (* noprune *) wire signed [WORD_SIZE-1:0] b_out;
    (* noprune *) wire signed [WORD_SIZE-1:0] c_out;

	(* noprune *) wire signed [33:0] a_out_mult = a_out*scale;
    (* noprune *) wire signed [33:0] b_out_mult = b_out*scale;
    (* noprune *) wire signed [33:0] c_out_mult = c_out*scale;

	(* noprune *) wire signed [17:0] a_fin = a_out_mult[31:14];
	(* noprune *) wire signed [17:0] b_fin = b_out_mult[31:14];
	(* noprune *) wire signed [17:0] c_fin = c_out_mult[31:14];

    // --- Fundamental Phase Generation (NCO) ---
    nco_spwm #(
        .WORD_SIZE(WORD_SIZE),
        .ACC_WIDTH(ACC_WIDTH)
    ) nco_inst (
        .clk(clk),
        .clk_en(clk_en),
        .reset(reset),
        .fcw(freq_in),
        .sine(sine),
        .phase_acc_dqz(phase_acc_dqz),
        .a_out(a_out),
        .b_out(b_out),
        .c_out(c_out)
    );

    // --- Triangular Carrier Generation (NCO) ---
    carrier_nco #(
        .WORD_SIZE(WORD_SIZE),
        .ACC_WIDTH(ACC_WIDTH)
    ) carrier_gen (
        .clk(clk),
        .reset(reset),
        .clk_en(clk_en),
        .fcw(carrier_fcw),
        .carrier(carrier_val)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pwm_u <= 1'b0;
            pwm_v <= 1'b0;
            pwm_w <= 1'b0;
        end else begin
            pwm_u <= (a_fin > $signed(carrier_val)); 
            pwm_v <= (b_fin > $signed(carrier_val));
            pwm_w <= (c_fin > $signed(carrier_val));
        end
    end

endmodule