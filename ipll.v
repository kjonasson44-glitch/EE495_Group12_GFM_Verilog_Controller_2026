module ipll #(
	parameter WORD_SIZE = 18,
	parameter ACC_WIDTH = 32
)(
	input  wire clk,
	input  wire clk_en,
	input  wire reset,
	input  wire signed [WORD_SIZE-1:0] q_in,
	output reg  signed [ACC_WIDTH-1:0] freq_out
);

// ----- System Coefficients ----- //
// CURRENT HZ (please change when you change this): 60 Hz (for a 2^32 accumulator)
localparam CENTRE_FREQ = 32'sd357913941;
// 60 Hz - 32'sd357913941;
// 59 Hz - 32'sd351948709;
// 61 Hz - 32'sd363879174;
// 59.75 Hz - 32'sd356422634;
// 60.25 Hz - 32'sd359405250;

// Current Case:
// kp = 40, ki = 1000, Jeq = 0.1, Deq = 1.2
// Cannot set D less than 0.125 - but you will never want to do that anyway

// Numerator coefficients (feedforward) 
localparam signed [17:0] B0 =  18'sd14359; // -2s20
localparam signed [17:0] B1 = 18'sd490; // -2s20
localparam signed [17:0] B2 =  -18'sd13869; // -2s20

// Denominator coefficients (feedback) 
localparam signed [17:0] A1 = -18'sd126997; //2s16

localparam signed [17:0] A2 = 18'sd61522; //2s16

localparam signed [10:0] RADSEC_TO_CYCPERSAM = 11'sd286; // -4s15 - 2*pi*1/720

// State variables - delay elements
reg signed [20:0] x_in;  // Input - 4s17
reg signed [20:0] x_z1, x_z2;  // Input delays: x[n-1], x[n-2] - 4s17 - need to sign extend for max gain
reg signed [20:0] y_out, y_z1, y_z2;  // Output delays: y[n-1], y[n-2] - 4s17 

// Internal computation variables (extended precision for multiplication)
reg signed [38:0] b0_mult, b1_mult, b2_mult;  // Numerator products - 4s37
reg signed [38:0] a1_mult, a2_mult;           // Denominator products - 6s33
reg signed [40:0] numerator_sum; 				// Numerator - 4s37
reg signed [37:0] denominator_sum;				// Denominator = about (6s33 - 2*6s33), worst case holds -12, which needs 4 int bits, so 5s33
reg signed [37:0] y_temp;							// 4s37 - 5s33 - need to sign extend and truncate numerator to match - so y_temp is 5s33 - in rad/sec
reg signed [31:0] freq_err; // Freq err is in cycles/sample, and is a 0s32 number

// Emergency Shutoff: If q is greater than 0.75 - shut off

always @(posedge clk or posedge reset) begin
	if (reset) begin
		// Reset all delay elements
		x_in <= 21'sd0;
		x_z1 <= 21'sd0;
		x_z2 <= 21'sd0;
		y_z1 <= 21'sd0;
		y_z2 <= 21'sd0;
		freq_err <= 32'sd0;

	end else if (clk_en) begin //if (clk_en) 
			// ==========================================
			// Stage 1: Multiply coefficients
			// ==========================================
			
			x_in = $signed(-q_in); 
			
			// Numerator: b0*x[n] + b1*x[n-1] + b2*x[n-2]
			b0_mult = B0 * (x_in);
			b1_mult = B1 * x_z1;
			b2_mult = B2 * x_z2;
			
			// Denominator: -a1*y[n-1] - a2*y[n-2]
			a1_mult = A1 * y_z1;
			a2_mult = A2 * y_z2;
			
			
			// ==========================================
			// Stage 2: Sum products
			// ==========================================
			
			// Sum numerator products
			numerator_sum = b0_mult + b1_mult + b2_mult;
			
			// Sum denominator products (feedback)
			denominator_sum = (a1_mult + a2_mult);
						
			// ==========================================
			// Stage 3: Combine and scale
			// ==========================================
			
			// Direct Form I: y[n] = numerator_sum - denominator_sum
			// (Note: A coefficients are already negated)
			y_temp = {numerator_sum[40], numerator_sum[40:4]} - denominator_sum; // Output is a 5s33, but will never be more than 4s17 due to max gain, so can truncate down here
			y_out = $signed(y_temp[36:16]);
			
			// Scale back from Hz in 4s17 to cycles/samp in 0s32
			// y_temp truncated from 5s33 to 4s17
			freq_err = y_out * RADSEC_TO_CYCPERSAM;
			
			// ==========================================
			// Update delay elements
			// ==========================================
			x_z2 <= x_z1;
			x_z1 <= x_in;
			y_z2 <= y_z1;
			y_z1 <= y_out;
	end
end

// ----- Frequency Output ----- //
always @(posedge clk or posedge reset) begin
	if (reset) begin
		freq_out <= CENTRE_FREQ;
	end else begin
		freq_out <= CENTRE_FREQ + $signed(freq_err); // Subtracting this also didn't work - go figure
	end
end

endmodule

