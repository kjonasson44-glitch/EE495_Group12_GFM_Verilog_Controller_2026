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
// =============================================================================
// Module Name:  DESMOS_dqz
// Description:  Direct-Quadrature-Zero (dqz) Transformation module utilizing 
//               a simplified Clarke-Park pipeline.
// =============================================================================

module dqz #(
    parameter WORD_SIZE = 18,
    parameter ACC_WIDTH = 32
)(
    input  wire clk,
    input  wire clk_en,
    input  wire reset,
    input  wire signed [WORD_SIZE-3:0] a_in, // 1s15 15:0
    input  wire signed [WORD_SIZE-3:0] b_in,
    input  wire signed [WORD_SIZE-3:0] c_in,
    input  wire signed [ACC_WIDTH-1:0] freq_in,
    output reg signed [WORD_SIZE-1:0] d_out, 
    output reg signed [WORD_SIZE-1:0] q_out,  // 2s16
    output wire [ACC_WIDTH-1:0] phase_acc_dqz,
    output reg [15:0] amplitude
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

    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            delay_counter <= 4'd0;
        end
        else if (clk_en) begin
            delay_counter <= 4'd0;
        end
        else begin
            delay_counter <= delay_counter + 4'd1;
        end
    end

    localparam signed THIRD      = 18'sh1_5555; // 0s18
    localparam signed SQRT_THIRD = 18'sh1_279A; // 1s17

    (* noprune *) wire signed [WORD_SIZE-1:0] alpha = (a_in <<< 1) - b_in - c_in;
    (* noprune *) wire signed [WORD_SIZE-1:0] beta  = c_in - b_in;

    (* noprune *) wire signed [2*WORD_SIZE-1:0] third_alpha     = THIRD * alpha; //3s33
    (* noprune *) wire signed [2*WORD_SIZE-1:0] sqrt_third_beta = SQRT_THIRD * beta; //4s32

    // --- RE-ADDED: Extract true alpha/beta for both Park Transform and Amplitude --- //
    wire signed [WORD_SIZE-1:0] true_alpha = $signed(third_alpha[34:17]);
    wire signed [WORD_SIZE-1:0] true_beta  = $signed(sqrt_third_beta[33:16]);

    // ----- Direct Axis ----- //
    wire signed [2*WORD_SIZE-1:0] alpha_cos = true_alpha * cosine; 
    wire signed [2*WORD_SIZE-1:0] beta_sin  = true_beta * sine; 
    wire signed [2*WORD_SIZE-1:0] inter_d   = alpha_cos - beta_sin; 

    // ----- Quadrature Axis ----- //
    wire signed [2*WORD_SIZE-1:0] alpha_sin = true_alpha * sine; 
    wire signed [2*WORD_SIZE-1:0] beta_cos  = true_beta * cosine; 
    wire signed [2*WORD_SIZE-1:0] inter_q   = alpha_sin + beta_cos;
    
    // ----- Amplitude Calculation ----- //
    // 1. Square the alpha and beta terms
    wire [35:0] alpha_sq = true_alpha * true_alpha;
    wire [35:0] beta_sq  = true_beta  * true_beta;
    
    // 2. Sum of squares (mag^2)
    wire [35:0] mag_sq   = alpha_sq + beta_sq;
    
    // 3. Unrolled Combinational Square Root Function
    function [15:0] isqrt;
        input [35:0] radicand;
        integer i;
        reg [35:0] root;
        reg [35:0] remainder;
        reg [35:0] test_val;
        begin
            root = 0;
            remainder = 0;
            for (i = 17; i >= 0; i = i - 1) begin
                remainder = (remainder << 2) | ((radicand >> (i*2)) & 2'b11);
                test_val  = (root << 2) | 2'b01;
                
                if (remainder >= test_val) begin
                    remainder = remainder - test_val;
                    root = (root << 1) | 1'b1;
                end else begin
                    root = root << 1;
                end
            end
            isqrt = root[16:1];
        end
    endfunction

    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            d_out <= 18'd0;
            q_out <= 18'd0;
            amplitude <= 16'd0;
        end
        else if (delay_counter == 4'd2) begin
            d_out <= $signed(inter_d[2*WORD_SIZE-1:WORD_SIZE]); // 2s16
            q_out <= $signed(inter_q[2*WORD_SIZE-1:WORD_SIZE]); // 2s16
            amplitude <= isqrt(mag_sq);
        end
    end
    
endmodule