// =============================================================================
// Module Name:  carrier_nco
// Description:  Triangle wave Numerically Controlled Oscillator (NCO).
//               Generates a bipolar, symmetric triangle carrier signal.
//
// Parameters:
//   - WORD_SIZE: Resolution of the output carrier (default 18 bits).
//   - ACC_WIDTH: Precision of the phase accumulator (default 32 bits).
//
// Architecture:
//   - Phase Accumulator: A free-running counter incremented by the Frequency 
//     Control Word (fcw) to determine output frequency.
//   - Triangle Mapping: A 4-quadrant piecewise linear logic that transforms 
//     the raw phase ramp into a rising and falling triangle waveform.
//
// Mathematical Basis:
//   - Output Frequency: f_out = fcw * f_clk / 2^32
// =============================================================================

module carrier_nco #(
    parameter WORD_SIZE = 18,
    parameter ACC_WIDTH = 32
)(
    input  wire clk,
    input  wire reset,
    input  wire clk_en,
    input  wire [ACC_WIDTH-1:0] fcw,
    output reg  signed [WORD_SIZE-1:0] carrier
);

    reg [ACC_WIDTH-1:0] phase_acc;

    // Use top 2 bits to identify the quadrant of the triangle
    // 00: Up (0 to MAX)
    // 01: Down (MAX to 0)
    // 10: Down (0 to -MAX)
    // 11: Up (-MAX to 0)
    wire [1:0] quadrant = phase_acc[ACC_WIDTH-1:ACC_WIDTH-2];
    
    // Extract the phase ramp (17 bits needed for 2^17-1 range)
    wire [WORD_SIZE-2:0] ramp = phase_acc[ACC_WIDTH-3 : ACC_WIDTH-WORD_SIZE-1];
  
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            phase_acc <= 0;
            carrier <= 0;
        end else begin
            phase_acc <= phase_acc + fcw;
            case (quadrant)
                2'b00: carrier <= $signed({1'b0, ramp});           // Up   0 -> 131071
                2'b01: carrier <= $signed(131071 - ramp);          // Down 131071 -> 0
                2'b10: carrier <= $signed(-{1'b0, ramp});          // Down 0 -> -131071
                2'b11: carrier <= $signed(-131071 + ramp);         // Up   -131071 -> 0
            endcase
        end
    end

endmodule