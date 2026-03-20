module volt_control_filt (
    input wire clk,                  // 25 MHz system clock
    input wire reset,                // Active low reset
    input wire clk_en,              // 720 Hz sampling strobe (enable signal)
    input wire signed [15:0] V_input,  // q-axis voltage (Error signal from dq transform) 
    
    output reg signed [15:0] V_output // Output frequency word for NCO
);

    // =========================================================================
    // PARAMETERS & CONSTANTS
    // =========================================================================
 
    // PI Controller Gains
    // Note: Gains depend on input magnitude (Vm) and sampling time (Ts) 
    localparam signed [31:0] KP = 32'sd429496730;  // Proportional Gain - 0s32 - 0.1 * 2^32 = 429496730
    localparam signed [19:0] KI = 20'sd2560;   // Integral Gain (includes Ts factor) - 10s10 - 2.5 * 2^10 = 2560
	 localparam signed [31:0] DT = 32'sd172;   // Ts 1/720 * 2^32 = 5965232 - 0s32 - scratch that - 1/25M * 2^32 = 172
	 localparam signed [15:0] MAX_VAL = 16'sd100;   // max Val brake - not used currently
	 localparam signed [15:0] VREF = 16'sd16384;   // Referance Voltage

    // =========================================================================
    // INTERNAL SIGNALS
    // =========================================================================
    
    // Integrator state for the I-term of the PI controller
    // Using 48 bits to prevent overflow during accumulation before truncation
    reg signed [17:0] integral_acc;
	 reg signed [37:0] integral_ki;
	 reg signed [16:0] error;
	 reg signed [48:0] error_kp;
	 reg signed [48:0] error_t_mid; // need to change this for scaling
	 reg signed [16:0] error_t;
	 
	 reg signed [16:0] pi_out;
	 
	 reg signed [16:0] V_grid_reading; //Increased by 1 bit to prevent overflow
    
    // =========================================================================
    // MAIN LOGIC
    // =========================================================================
    
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
        end else begin
            // The PLL operates at the sampling rate of the dq transformation (720 Hz)
            //if (clk_en) begin // need to do this on clk, not clk_en, otherwise out output sin waves for PWM will be much more choppy then they should be
                
                // 1. Proportional Term Calculation
                // error_ramp(k) = V_ramp_input(k) - V_out_ramp(k-1)
					 error <= {V_input[15], V_input} - V_grid_reading; // 2s15? Top int bit may never be used
					 
					 error_t_mid <= error * DT; // 1s15 * 0s32 = 1s
					 
					 error_t <= error_t_mid[28:12]; // 1s15 again
					 
					 // 2. Integral Term Calculation
					 integral_acc <= integral_acc + error_t; //2s15 + 2s15 - this seems super wrong to me
					 
					 error_kp <= error * KP; // 1s15 * 0s32 
					 
					 integral_ki <= integral_acc * 2; // 2s15 * 2 = 3s15
                
                // 3. PI Output Summation
                // The PI output represents the frequency deviation required to lock.
                pi_out <= {error_kp[48], error_kp[48],error_kp[48:32]} + integral_ki; // (1+2)s15 + 3s15

                V_grid_reading <= pi_out + VREF;
                
            end
        end
	 
always @ (posedge clk or posedge reset)
	if (reset || pi_out < 0) begin
		V_output <= VREF;
	end
	else begin
		V_output <= VREF - pi_out;
	end

endmodule


