// =============================================================================
// Module Name:  srf_pll
// Description:  Synchronous Rotating Frame Phase-Lock Loop (SRF-PLL).
//               This module is used for grid synchronization by estimating the 
//               frequency and phase of a three-phase system.
//
// Operation:
//   - The SRF-PLL operates on the q-axis voltage from a DQ transformation.
//   - A Proportional-Integral (PI) controller acts as a loop filter to drive 
//     the q-axis component to zero.
//   - When q-axis error is zero, the rotating d-axis is aligned with the utility 
//     voltage vector, indicating the system is phase-locked.
//   - The PI output adjusts the Center Frequency to produce a Frequency 
//     Control Word (FCW) for a downstream NCO.
//
// Mathematical Basis:
//   - Error Signal: negative q_in
//   - PI Control:   Output = Kp * error + Ki * integral of error
//   - Output FCW:   freq_out = Center_Freq + PI_Output
// =============================================================================

module srf_pll (
    input wire clk,                  // 25 MHz system clock
    input wire reset,                // Active low reset
    input wire clk_en,               // 720 Hz sampling strobe
    input wire signed [17:0] q_in,   // q-axis voltage error
    output reg signed [31:0] freq_out // Output frequency word for NCO
);

    // Parameters and Constants 
    // Center Frequency: ~60 Hz at 720 Hz sampling rate 
    localparam signed [31:0] CENTER_FREQ = 32'sd357913942;

    // PI Controller Gains
    localparam signed [31:0] KP = 32'sd2000;
    localparam signed [31:0] KI = 32'sd100;

    // Internal Registers
    reg signed [47:0] integrator;
    reg signed [47:0] prop_term;
    reg signed [47:0] pi_output;

    // Control Logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            integrator <= 48'd0;
            freq_out   <= CENTER_FREQ;
            prop_term  <= 48'd0;
            pi_output  <= 48'd0;
        end else begin
            // PLL operates at the 720 Hz sampling rate
            if (clk_en) begin
                
                // Proportional Term Calculation
                prop_term <= -q_in * KP;

                // Integral Term Calculation (Euler Forward)
                integrator <= integrator + (-q_in * KI);
                
                // PI Output Summation
                pi_output <= prop_term + integrator;

                // Final Output Calculation
                // freq_out = Center_Freq + PI_Output 
                freq_out <= CENTER_FREQ + $signed(pi_output[31:0]);
                
            end
        end
    end

endmodule