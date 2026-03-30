// =============================================================================
// Module Name:  ipll
// Description:  Infinite Impulse Response (IIR) Phase-Locked Loop filter.
//               This module implements a 2nd-order IIR filter used to process 
//               the phase error signal (q_in) and compute a frequency offset.
//               It utilizes a Direct Form structure, taking numerator (B0, B1, B2)
//               and denominator (A1, A2) coefficients to shape the loop response.
//
// Operation:
//   - The error signal (q_in) is negated and passed through the filter.
//   - Delay elements (z1, z2) store previous input and output states for 
//     subsequent calculations.
//   - The filtered result is computed, truncated, and scaled from radians/sec 
//     to cycles/sample.
//   - The final output frequency word is the base CENTRE_FREQ adjusted by 
//     the calculated frequency error.
// =============================================================================

module ipll #(
    parameter WORD_SIZE = 18,
    parameter ACC_WIDTH = 32
)(
    input  wire clk,
    input  wire clk_en,
    input  wire reset,
    input  wire signed [WORD_SIZE-1:0] B0, B1, B2,
    input  wire signed [WORD_SIZE-1:0] A1, A2,
    input  wire signed [WORD_SIZE-1:0] q_in,
    output reg  signed [ACC_WIDTH-1:0] freq_out
);

    localparam CENTRE_FREQ = 32'sd361493081;
    localparam signed [10:0] RADSEC_TO_CYCPERSAM = 11'sd286; // -4s15

    // State variables
    reg signed [20:0] x_in;              // 4s17
    reg signed [20:0] x_z1, x_z2;        // 4s17
    reg signed [20:0] y_out, y_z1, y_z2; // 4s17 

    // Internal computation variables
    reg signed [38:0] b0_mult, b1_mult, b2_mult; // 4s37
    reg signed [38:0] a1_mult, a2_mult;          // 6s33
    reg signed [40:0] numerator_sum;             // 4s37
    reg signed [37:0] denominator_sum;           // 5s33
    reg signed [37:0] y_temp;                    // 5s33 
    reg signed [31:0] freq_err;                  // 0s32

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            x_in <= 21'sd0;
            x_z1 <= 21'sd0;
            x_z2 <= 21'sd0;
            y_z1 <= 21'sd0;
            y_z2 <= 21'sd0;
            freq_err <= 32'sd0;
        end else if (clk_en) begin 
            // Multiplication
            x_in = $signed(-q_in);
            
            b0_mult = B0 * (x_in);
            b1_mult = B1 * x_z1;
            b2_mult = B2 * x_z2;
            
            a1_mult = A1 * y_z1;
            a2_mult = A2 * y_z2;
            
			// Sum products
            numerator_sum = b0_mult + b1_mult + b2_mult;
            denominator_sum = (a1_mult + a2_mult);
            
            y_temp = {numerator_sum[40], numerator_sum[40:4]} - denominator_sum;
            y_out = $signed(y_temp[36:16]); // 5s33 -> 4s17
            
			// Scale back from Hz in 4s17 to cycles/sample in 0s32
            freq_err = y_out * RADSEC_TO_CYCPERSAM;
            
			// Update
            x_z2 <= x_z1;
            x_z1 <= x_in;
            y_z2 <= y_z1;
            y_z1 <= y_out;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            freq_out <= CENTRE_FREQ;
        end else begin
            freq_out <= CENTRE_FREQ + $signed(freq_err);
        end
    end

endmodule

