module amplitude_finder (
    input wire clk,           // 25 MHz
    input wire reset,
    input wire signed [15:0] adc_in, 
    output reg [15:0] amplitude
);

    reg [15:0] abs_val;
    reg [19:0] decay_cnt;
    parameter DECAY_RATE = 20'd208333; // Adjust for tracking speed - Decay's every 6/720 seconds (120 hz) - Ensures half cycle per decay 
	 // Decay of about 100 seems reasonable, but I will do 150 just to be safe
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            abs_val   <= 16'd0;
            amplitude <= 16'd0;
            decay_cnt <= 20'd0;
        end else begin
            // 1. Rectification (Absolute Value)
            abs_val <= (adc_in[15]) ? -adc_in : adc_in;

            // 2. Peak Capture
            if (abs_val > amplitude) begin
                amplitude <= abs_val;
                decay_cnt <= 20'd0; // Reset decay timer on new peak
            end 
            // 3. Slow Decay (allows tracking when amplitude drops)
            else begin
                if (decay_cnt >= DECAY_RATE) begin
                    if (amplitude > 0) amplitude <= amplitude - 10'd150; // Randomly chose this decay - it was wrong
						  // Decay rate is fairly interesting actually, but my testbench simulates a surge to 1.5*nominal in under a second
						  // Which I am just assuming is a normal number
						  // Trying to account for something worse then this would just involve increasing this decay factor. 
                    decay_cnt <= 20'd0;
                end else begin
                    decay_cnt <= decay_cnt + 1'b1;
                end
            end
        end
    end
endmodule