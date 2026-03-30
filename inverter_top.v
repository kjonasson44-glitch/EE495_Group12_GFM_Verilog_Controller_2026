// =============================================================================
// Module Name:  inverter_top
// Description:  Top-level Three-Phase Inverter Controller. Integrates 
//               Sinusoidal PWM (SPWM) generation with hardware-specific 
//               gate drive interfacing. 
//
// Parameters:
//   - WORD_SIZE: 18 bits (Signed resolution for d-q and modulation signals).
//   - ACC_WIDTH: 32 bits (Phase accumulator resolution for NCOs).
//   - DEAD_TIME_CYCLES: 125 (Number of clock cycles for shoot-through 
//                           protection between high/low gate signals). 
//
// Architecture:
//   - Modulation:  Instantiates 'spwm_new' to transform d-q voltage references 
//                  and frequency control words into three-phase PWM 
//                  switching patterns. 
//   - Interfacing: Employs 'inverter_interface' modules for each phase (U, V, W) 
//                  to generate complementary gate signals.
//   - Protection:  Implements mandatory dead-time insertion for every phase to 
//                  prevent short-circuit.
//
// Performance Metrics:
//   - Phase Resolution: Supports 32-bit frequency and phase precision.
//   - Scalability:      External scale input allows for real-time modulation 
//                       index adjustment and overmodulation control. 
// =============================================================================

module inverter_top #(
    parameter WORD_SIZE = 18,
    parameter ACC_WIDTH = 32
)(  
    input wire clk,
    input wire clk_en,
    input wire reset,
    input wire [ACC_WIDTH-1:0] freq_in,
    input wire [ACC_WIDTH-1:0] carrier_fcw,
	input wire [ACC_WIDTH-1:0] phase_acc_dqz,
    input wire signed [WORD_SIZE-1:0] d_in,
    input wire signed [WORD_SIZE-1:0] q_in,
	input wire signed [15:0] scale,
    output wire u_high, u_low,
    output wire v_high, v_low,
    output wire w_high, w_low
);

    localparam DEAD_TIME_CYCLES = 125;
    wire pwm_u, pwm_v, pwm_w;

    // Instantiate SPWM
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
        .scale(scale),
        .phase_acc_dqz(phase_acc_dqz),
        .pwm_u(pwm_u),
        .pwm_v(pwm_v),
        .pwm_w(pwm_w)
    );

    // Phase U Dead-Time - Phase A
    inverter_interface #(
        .DEAD_TIME_CYCLES(DEAD_TIME_CYCLES)
    ) dead_time_u (
        .clk(clk),
        .reset(reset),
        .pwm_in(pwm_u),
        .gate_h(u_high),
        .gate_l(u_low)
    );

    // Phase V Dead-Time - Phase A
    inverter_interface #(
        .DEAD_TIME_CYCLES(DEAD_TIME_CYCLES)
    ) dead_time_v (
        .clk(clk),
        .reset(reset),
        .pwm_in(pwm_v),
        .gate_h(v_high),
        .gate_l(v_low)
    );

    // Phase W Dead-Time - Phase C
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
