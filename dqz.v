// =============================================================================
// Module Name:  DESMOS_dqz
// Description:  Direct-Quadrature-Zero (dqz) Transformation module utilizing 
//               a simplified Clarke-Park pipeline.
//
// Parameters:
//   - WORD_SIZE: 18 bits (Signed output resolution)
//
// Architecture:
//   - Clarke Stage: Reducer logic converts 3-phase (abc) inputs to 2-phase 
//                   stationary (alpha-beta) coordinates using fixed-point
//                   coefficients for 1/3 and 1/sqrt(3).
//   - Park Stage:   Rotating transformation via hardware multipliers, 
//                   projecting alpha-beta onto the d-q rotating frame.
//   - Arithmetic:   Signed fixed-point operations with manual bit-shifting
//                   to maintain precision across intermediate products.
//   - Latency:      Combinational (0 Clock Cycles). Input-to-output path 
//                   depends on multiplier propagation delay.
//
// Mathematical Basis:
//   - alpha = 2/3 * a - 1/3 * (b + c)
//   - beta  = 1/sqrt(3) * (b - c)
//   - d     = alpha*cos(theta) - beta*sin(theta) 
//   - q     = beta*cos(theta) + alpha*sin(theta)
//
// Performance Metrics (Theoretical):
//   - Precision:    Maintains high dynamic range by utilizing 36-bit 
//                   intermediate products before truncation.
//
// Target App:   Motor Control (FOC), Three-phase Inverters, Grid-Tie Systems.
// =============================================================================
// We are assuming the voltage vector (and generator) rotates counter clockwise
module dqz #(
	parameter WORD_SIZE = 18,
	parameter ACC_WIDTH = 32
)(
	input  wire clk,
	input  wire clk_en,
	input  wire reset,
	//input  wire [WORD_SIZE-1:0] sine, cosine, // 1s17
	input  wire signed [WORD_SIZE-3:0] a_in, // 1s15 15:0
	input  wire signed [WORD_SIZE-3:0] b_in,
	input  wire signed [WORD_SIZE-3:0] c_in,
	input  wire signed [ACC_WIDTH-1:0] freq_in,
	output reg signed [WORD_SIZE-1:0] d_out, 
	output reg signed [WORD_SIZE-1:0] q_out,  // 2s16
	output wire [ACC_WIDTH-1:0] phase_acc_dqz
);

	wire signed [WORD_SIZE-1:0] sine, cosine;

	nco_dqz nco_inst (
		.clk(clk),
		.clk_en(clk_en),
		.reset(reset),
		.fcw(freq_in),
		.sine(sine),
		.cosine(cosine),
		.phase_acc_dqz(phase_acc_dqz)
	);
	
	reg [3:0] delay_counter;

always @ (posedge clk or posedge reset)
if (reset) begin
delay_counter <= 4'd0;
end
else if (clk_en) begin
delay_counter <= 4'd0;
end
else begin
delay_counter <= delay_counter + 4'd1;
end


always @ (posedge clk or posedge reset)
if (reset) begin
d_out <= 18'd0;
q_out <= 18'd0;
end
else if (delay_counter == 4'd2) begin
d_out <= $signed(inter_d[2*WORD_SIZE-1:WORD_SIZE]); // 2s16
q_out <= $signed(inter_q[2*WORD_SIZE-1:WORD_SIZE]); // 2s16
end

	localparam signed THIRD		 = 18'sh1_5555; // 0s18
	localparam signed SQRT_THIRD = 18'sh1_279A; // 1s17

(* noprune *)	wire signed [WORD_SIZE-1:0] alpha = (a_in <<< 1) - b_in - c_in;
(* noprune *)	wire signed [WORD_SIZE-1:0] beta  = c_in - b_in;

(* noprune *)	wire signed [2*WORD_SIZE-1:0] third_alpha     = THIRD * alpha; //3s33
(* noprune *)	wire signed [2*WORD_SIZE-1:0] sqrt_third_beta = SQRT_THIRD * beta; //4s32

	// ----- Direct Axis ----- //
	wire signed [2*WORD_SIZE-1:0] alpha_cos = $signed(third_alpha[34:17]) * cosine; 
	wire signed [2*WORD_SIZE-1:0] beta_sin  = $signed(sqrt_third_beta[33:16]) * sine; 
	wire signed [2*WORD_SIZE-1:0] inter_d   = alpha_cos - beta_sin; 


	// ----- Quadrature Axis ----- //
	wire signed [2*WORD_SIZE-1:0] alpha_sin = $signed(third_alpha[34:17]) * sine; 
	wire signed [2*WORD_SIZE-1:0] beta_cos  = $signed(sqrt_third_beta[33:16]) * cosine; 
	wire signed [2*WORD_SIZE-1:0] inter_q   = alpha_sin + beta_cos;

endmodule