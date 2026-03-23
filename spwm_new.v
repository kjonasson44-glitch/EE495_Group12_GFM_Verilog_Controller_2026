module spwm_new #(
    parameter WORD_SIZE = 18,
    parameter ACC_WIDTH = 32
)(
    input  wire clk,
    input  wire clk_en,
    input  wire reset,
    input  wire [ACC_WIDTH-1:0] freq_in,      // Frequency for the fundamental sine wave
    input  wire [ACC_WIDTH-1:0] carrier_fcw,  // Frequency control for the triangle carrier
    input  wire signed [WORD_SIZE-1:0] q_in, d_in,
	 input  wire signed [15:0] V_scale,
	 input wire [ACC_WIDTH-1:0] phase_acc_dqz,
    output reg  pwm_u, pwm_v, pwm_w
);

    // ----- Internal Signals -----
    wire signed [WORD_SIZE-1:0] sine, cosine;
    wire signed [WORD_SIZE-1:0] carrier_val;
	 
	 (* noprune *) wire signed [WORD_SIZE-1:0] a_out;
	 
    (* noprune *) wire signed [WORD_SIZE-1:0] b_out;
	 
    (* noprune *) wire signed [WORD_SIZE-1:0] c_out;
	 
	 // We must read 120 V RMS to see what our actual reference level is. 
	 // Until then I will assume it is what we have now - 16384. 
	 // When it is 16384 - we want our output to be full scale. 
	 // Since 16384 is 0.5 in 1s15, we multiply by this 1s15 number, then take the top 18 bits? 
	 //  Maybe we wanna take the second from top 18 bits? 
	 
	 (* noprune *) wire signed [33:0] a_out_mult;
	 assign a_out_mult = a_out*V_scale;
	 
	 (* noprune *) wire signed [17:0] a_fin;
	 assign a_fin = a_out_mult[31:14];
	 
    (* noprune *) wire signed [33:0] b_out_mult;
	 assign b_out_mult = b_out*V_scale;
	 
	 (* noprune *) wire signed [17:0] b_fin;
	 assign b_fin = b_out_mult[31:14];
	 
    (* noprune *) wire signed [33:0] c_out_mult;
	 assign c_out_mult = c_out*V_scale;
	 
	 (* noprune *) wire signed [17:0] c_fin;
	 assign c_fin = c_out_mult[31:14];

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
		  .phase_acc_dqz(phase_acc_dqz),
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
            pwm_u <= (a_fin > $signed(carrier_val)); 
            pwm_v <= (b_fin > $signed(carrier_val));
            pwm_w <= (c_fin > $signed(carrier_val));
        end
    end


endmodule