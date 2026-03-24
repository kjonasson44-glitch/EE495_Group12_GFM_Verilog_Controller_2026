module volt_control_filt (
    input wire clk,                  // 25 MHz system clock
	 input wire VOLT_CONTROL_OFF,                  // 25 MHz system clock
    input wire reset,                // Active low reset
    input wire clk_en,              // 720 Hz sampling strobe (enable signal)
    input wire signed [15:0] V_input,  // q-axis voltage (Error signal from dq transform) 
	 input wire signed [31:0] KP,
	 input wire signed [9:0] KI,
	 input wire signed [15:0] VREF,
	 input wire signed [31:0] DT,
	 input wire signed [18:0] CONVERSION,
	 input wire signed [15:0] VMIN,
	 input wire signed [15:0] VMAX,
    
    output reg signed [15:0] V_output // Output frequency word for NCO
);

    // =========================================================================
    // PARAMETERS & CONSTANTS
    // =========================================================================
 
    // PI Controller Gains
    // Note: Gains depend on input magnitude (Vm) and sampling time (Ts) 
    //localparam signed [31:0] KP = 32'sd429496730;  // Proportional Gain - 0s32 - 0.1 * 2^32 = 429496730
    //localparam signed [19:0] KI = 20'sd2560;   // Integral Gain (includes Ts factor) - 10s10 - 2.5 * 2^10 = 2560
	 //localparam signed [31:0] DT = 32'sd172;   // Ts 1/720 * 2^32 = 5965232 - 0s32 - scratch that - 1/25M * 2^32 = 172
	 localparam signed [15:0] MAX_VAL = 16'sd16000;   // Max Val Brake - Corresponds to the absolute least we should ever output 
	 // 0.05 * 17500 = 875 (since our output is VREF - pi_out)
	 //localparam signed [15:0] VREF = 16'sd17500;   // Referance Voltage
	 // V normal should be 16384 - so we subtract 1116 from 17500 to get our desired output

    // =========================================================================
    // INTERNAL SIGNALS
    // =========================================================================
    
    // Integrator state for the I-term of the PI controller
    // Using 48 bits to prevent overflow during accumulation before truncation
    reg signed [37:0] integral_acc;
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
            // The PLL operates at the sampling rate of the dq transformation (720 Hz)
            //if (clk_en) begin // need to do this on clk, not clk_en, otherwise out output sin waves for PWM will be much more choppy then they should be
                
                // 1. Proportional Term Calculation
                // error_ramp(k) = V_ramp_input(k) - V_out_ramp(k-1)
					 error <= {V_input[15], V_input} - VREF; // 2s15? Top int bit may never be used
					 
					 error_t_mid <= error * DT; // 1s15 * 0s32 = 1s
					 
					 error_t <= error_t_mid[28:12]; // 1s15 again
					 
					 // 2. Integral Term Calculation
					 integral_acc <= integral_acc + error_t*KI; //2s15 + 2s15 - this seems super wrong to me
					 
					 error_kp <= error * KP; // 1s15 * 0s32 
					   
					 //integral_ki <= integral_acc[27:0]; // 2s15 * 2 = 3s15
                
                // 3. PI Output Summation
                // The PI output represents the frequency deviation required to lock.
                pi_out <= {error_kp[48], error_kp[48],error_kp[48:31]} + integral_acc[37:20]; // (1+2)s15 + 3s15

                V_grid_reading <= pi_out + VREF;
                
            end
        end

assign is_negative = (pi_out < 0);
assign is_too_high = (pi_out > MAX_VAL);

reg signed [15:0] V_output_val;
// FIX 1: 16 bits * 19 bits = 35 bits total to prevent hidden overflow
wire signed [34:0] V_output_mult; 

// 1. Determine the raw output value
always @ (posedge clk or posedge reset) begin
    if (reset) begin
        V_output_val <= VREF;
	 end else if (VOLT_CONTROL_OFF) begin
		  V_output_val <= 16'sd16000; //Safe value
    end else if (is_negative) begin
        V_output_val <= VREF; 
    end else if (is_too_high) begin
        V_output_val <= VMIN; 
    end else begin
        V_output_val <= VREF - pi_out;
    end
end

// FIX 2: Combinational multiply prevents cascading clock delays
assign V_output_mult = V_output_val * CONVERSION;

// 3. Scale and slice the output
always @ (posedge clk or posedge reset) begin
    if (reset) begin
        V_output <= 16'd0;		  
	end else if (VOLT_CONTROL_OFF) begin
			V_output <= 16'sd16350;
    end else begin
        // You were extracting [25:11]. Assuming that bit selection is still 
        // valid for your fixed-point format, we apply it to the full 35-bit product.
        // We use bit 34 as the true sign bit.
        V_output <= {V_output_mult[34], V_output_mult[25:11]};
    end
end
// i multiply by 1/max val, which should be a -xsy number, giving me a 0s15 number after truncation - which should have the range of 16384 to 0 (or 1.0 to 0.0)
// Probably shouldn't be signed but whatever. 
// About 17500 is 120 RMS or 170 peak, 8s? 
// I will assume 8s for now, lets see if that makes sense 
// 16 bits, 9s7? - closer - I guess I will assume it is 9s7 as that is ballpark
// Meaning our multiplier has to be 1/204 - makes no sense - our input and output are like entirely different 
// So it needs to be tunable. But - we should max out our input at 204/204 then, so then 204 peak = 16384 (on the inverter side)
// Then we don't check is_negative - we check is greater than 16380
// Now, we multiply by a -9s19 number - 1/204 * 2^19 - 2570 - how many bits? Like 12 - kinda random but its just a coefficient
// now we have 0s26, take 0s14, Should give us our ratio

endmodule


