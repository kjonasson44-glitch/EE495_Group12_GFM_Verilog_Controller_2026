module inverter_top #(
    parameter WORD_SIZE = 18,
    parameter ACC_WIDTH = 32
)(  
    input wire clk,
    input wire clk_en,
    input wire reset,
    input wire [ACC_WIDTH-1:0] freq_in,
    input wire [ACC_WIDTH-1:0] carrier_fcw,
    input wire signed [WORD_SIZE-1:0] d_in,
    input wire signed [WORD_SIZE-1:0] q_in,
	 input wire [ACC_WIDTH-1:0] phase_acc_dqz,

    output wire u_high, u_low,
    output wire v_high, v_low,
    output wire w_high, w_low
);

localparam DEAD_TIME_CYCLES = 125; //1250;

wire pwm_u, pwm_v, pwm_w;

// 1. Instantiate the SPWM Modulator
spwm #(
    .WORD_SIZE(WORD_SIZE),
    .ACC_WIDTH(ACC_WIDTH)
) modulator (
    .clk(clk),
    .clk_en(clk_en),
    .reset(reset),
    .freq_in(freq_in),
    .carrier_fcw(carrier_fcw),
    .q_in(q_in),
    .d_in(d_in),
    .pwm_u(pwm_u),
    .pwm_v(pwm_v),
    .pwm_w(pwm_w),
	 .phase_acc_dqz(phase_acc_dqz)
);

// 2. Phase U Dead-Time - Phase a
inverter_interface #(
    .DEAD_TIME_CYCLES(DEAD_TIME_CYCLES)
) dead_time_u (
    .clk(clk),
    .reset(reset),
    .pwm_in(pwm_u),
    .gate_h(u_high),
    .gate_l(u_low)
);

// 2. Phase V Dead-Time - Phase b
inverter_interface #(
    .DEAD_TIME_CYCLES(DEAD_TIME_CYCLES)
) dead_time_v (
    .clk(clk),
    .reset(reset),
    .pwm_in(pwm_v),
    .gate_h(v_high),
    .gate_l(v_low)
);

// 2. Phase W Dead-Time - Phase c
inverter_interface #(
    .DEAD_TIME_CYCLES(DEAD_TIME_CYCLES)
) dead_time_w (
    .clk(clk),
    .reset(reset),
    .pwm_in(pwm_w),
    .gate_h(w_high),
    .gate_l(w_low)
);

endmodule
