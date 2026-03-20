module spwm #(
    parameter WORD_SIZE = 18,
    parameter ACC_WIDTH = 32
)(
    input  wire clk,
    input  wire clk_en,
    input  wire reset,
    input  wire [ACC_WIDTH-1:0] freq_in,      // Frequency for the fundamental sine wave
    input  wire [ACC_WIDTH-1:0] carrier_fcw,  // Frequency control for the triangle carrier
    input  wire signed [WORD_SIZE-1:0] q_in, d_in,
    output reg  pwm_u, pwm_v, pwm_w
);

    // ----- Internal Signals -----
    wire signed [WORD_SIZE-1:0] sine, cosine;
    wire signed [WORD_SIZE-1:0] carrier_val;
	 
	 (* noprune *) wire signed [WORD_SIZE-1:0] a_out;
	 
    (* noprune *) wire signed [WORD_SIZE-1:0] b_out;
	 
    (* noprune *) wire signed [WORD_SIZE-1:0] c_out;

    // ----- 1. Fundamental Phase Generation (NCO) -----
    nco_spvm #(
        .WORD_SIZE(WORD_SIZE),
        .ACC_WIDTH(ACC_WIDTH)
    ) nco_inst (
        .clk(clk),
        .clk_en(clk_en),
        .reset(reset),
        .fcw(freq_in),
        .sine(sine),
        .a_out(a_out),
		  .b_out(b_out),
		  .c_out(c_out)
    );

    // ----- 2. Triangular Carrier Generation (NCO) -----
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
            pwm_u <= (a_out > $signed(carrier_val)); 
            pwm_v <= (b_out > $signed(carrier_val));
            pwm_w <= (c_out > $signed(carrier_val));
        end
    end


endmodule