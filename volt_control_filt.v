// =============================================================================
// Module Name:  volt_control_filt
// Description:  PI-based voltage controller for closed-loop regulation.
//               Calculates error against a reference and applies a PI filter 
//               to generate a scaled voltage output command.
// =============================================================================

module volt_control_filt (
    input wire clk,                  
    input wire VOLT_CONTROL_OFF,                  
    input wire reset,                
    input wire clk_en,              
    input wire signed [15:0] V_input,  
    input wire signed [31:0] KP,
    input wire signed [9:0] KI,
    input wire signed [15:0] VREF,
    input wire signed [31:0] DT,
    input wire signed [18:0] CONVERSION,
    input wire signed [15:0] VMIN,
    input wire signed [15:0] VMAX,
    output reg signed [15:0] V_output 
);

    localparam signed [15:0] MAX_VAL = 16'sd16000;

    reg signed [37:0] integral_acc;
    reg signed [37:0] integral_ki;
    reg signed [16:0] error;
    reg signed [48:0] error_kp;
    reg signed [48:0] error_t_mid;
    reg signed [16:0] error_t;
    reg signed [16:0] pi_out;
    reg signed [16:0] V_grid_reading;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            integral_acc <= 18'sd0;
            integral_ki <= 38'sd0;
            error_kp <= 49'sd0;
            error_t_mid <= 49'sd0;
            error_t <= 17'sd0;
            error <= 17'sd0;
            pi_out  <= 17'sd0;
            V_grid_reading  <= 17'sd0;
            
        end else if (VOLT_CONTROL_OFF) begin
            integral_acc <= 18'sd0;
            integral_ki <= 38'sd0;
            error_kp <= 49'sd0;
            error_t_mid <= 49'sd0;
            error_t <= 17'sd0;
            error <= 17'sd0;
            pi_out  <= 17'sd0;
            V_grid_reading  <= 17'sd0;
            
        end else begin
            error <= {V_input[15], V_input} - VREF;
            
            error_t_mid <= error * DT;
            
            error_t <= error_t_mid[28:12];
            
            integral_acc <= integral_acc + error_t*KI;
            
            error_kp <= error * KP;
            
            pi_out <= {error_kp[48], error_kp[48],error_kp[48:31]} + integral_acc[37:20]; 

            V_grid_reading <= pi_out + VREF;
        end
    end

    assign is_negative = (pi_out < 0);
    assign is_too_high = (pi_out > MAX_VAL);
    
    reg signed [15:0] V_output_val;
    wire signed [34:0] V_output_mult;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            V_output_val <= VREF;
        end else if (VOLT_CONTROL_OFF) begin
            V_output_val <= 16'sd16000; 
        end else if (is_negative) begin
            V_output_val <= VREF;
        end else if (is_too_high) begin
            V_output_val <= VMIN;
        end else begin
            V_output_val <= VREF - pi_out;
        end
    end

    assign V_output_mult = V_output_val * CONVERSION;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            V_output <= 16'd0;
        end else begin
            V_output <= {V_output_mult[34], V_output_mult[25:11]};
        end
    end

endmodule

