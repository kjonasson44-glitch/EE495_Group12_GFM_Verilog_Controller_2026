// Written by Kelvin Jonasson and David Mielke - kjonasson44@gmail.com and davidpetermielke@gmail.com
module ee495_capstone (
     input wire CLOCK_50,             // System Clock (50 MHz)
     inout wire [35:0] GPIO,          // GPIO (36 pins)
     input wire [17:0] SW,
     input wire [3:0] KEY
);
localparam ACC_WIDTH = 32;
/******************************* CLOCKS
********************************/
localparam CLK_FREQ_HZ     = 25_000_000;  // 25 MHz System Clock
localparam SAMPLE_RATE_HZ  = 720;         // Target Data Rate
localparam CLKS_PER_SAMPLE = CLK_FREQ_HZ / SAMPLE_RATE_HZ; // ~34,722 clocks

localparam SAMPLING_CLK = 10; // ~34,722 clocks

localparam FAST_CONV = 123695; // 0s32 of 720/25M
localparam CARRIER_CONV = 75; // 75 as in matlab

integer timer_cnt;
integer timer_cnt2;
reg clk = 0;
reg clk_en = 0;
reg sampling_clk = 0;

// System Clock (25 Mhz)
always @ (posedge CLOCK_50) begin
    clk = ~clk;
end

// Clock Enable Counter
always @(posedge clk or posedge reset) begin
    if (reset) begin
      timer_cnt <= 0;
      clk_en <= 1'd0;
    end else begin
      // Check if enough clock cycles have passed to jump to the next sample
      if (timer_cnt >= CLKS_PER_SAMPLE - 1) begin
            timer_cnt <= 0;               // Reset timer
            clk_en <= 1;
      end else begin
            timer_cnt <= timer_cnt + 1; // Keep counting
            clk_en <= 0;
      end
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
      timer_cnt2 <= 0;
      sampling_clk <= 1'd0;
    end else begin
      // Check if enough clock cycles have passed to jump to the next sample
      if (timer_cnt2 >= SAMPLING_CLK - 1) begin
            timer_cnt2 <= 0;               // Reset timer
            sampling_clk <= ~sampling_clk;
      end else begin
            timer_cnt2 <= timer_cnt2 + 1; // Keep counting
            sampling_clk <= sampling_clk;
      end
    end
end

/****************** RESET STUFF
********************************/
(* noprune *) wire reset_pin;

/*
(* noprune *) reg reset; // This is a wire in adc_reader and we do nothing with it
always @ * begin
    if (~KEY[0])
        reset = 1'b1; // Reset on a key push
    else
        reset = 1'b0; // Ensure reset goes low when key is released
end
*/

/************** GPIO ASSIGNMENTS & WIRES
********************************/

// Note: Changed these from 'reg' to 'wire' because they are driven by the adc_reader outputs.
(* noprune *) wire signed [15:0] VA;
(* noprune *) wire signed [15:0] VB;
(* noprune *) wire signed [15:0] VC;
(* noprune *) wire signed [15:0] IA;
(* noprune *) wire signed [15:0] IB;
(* noprune *) wire signed [15:0] IC;
(* noprune *) wire signed [15:0] VDC;
(* noprune *) wire signed [15:0] GARBAGE;

(* noprune *) wire loading;         // High when reading/converting
(* noprune *) wire RD;
(* noprune *) wire CONVST;
(* noprune *) wire u_high;
(* noprune *) wire u_low;
(* noprune *) wire v_high;
(* noprune *) wire v_low;
(* noprune *) wire w_high;
(* noprune *) wire w_low;

// Interconnect wires for the DSP chain
(* noprune *) wire signed [17:0] d_out; //1s15 - from dqz to ipll and spvm
(* noprune *) wire signed [17:0] q_out; //1s15 - from dqz to ipll and spvm
(* noprune *) wire signed [31:0] freq_out_ipll; // freq out as a 0s32 number (cycles/sample) - 60/720 * 2^32 - as an example
(* noprune *) wire signed [31:0] freq_out_srf; // freq out from type 1 system (grid following)
(* noprune *) wire signed [31:0] freq_out; // freq out from type 1 system (grid following)
(* noprune *) wire signed [17:0] nco_sine; // From dqz
(* noprune *) wire signed [17:0] nco_cosine; // From dqz

// Inputs from external hardware
(* noprune *) wire BUSY     = GPIO[20];                                                                         
(* noprune *) wire FRSTDATA = GPIO[16];
(* noprune *) wire signed [15:0] DATA_IN = GPIO[15:0];

// Outputs to external hardware
assign GPIO[18] = RD;
//assign GPIO[28] = RD;
assign GPIO[22] = CONVST;
//assign GPIO[26] = CONVST;
(* noprune *) assign GPIO[35] = reset_pin;
//assign GPIO[35] = ~KEY[0]; //reset;


/* GFM 1.0 assignments - for older pcb - ignore
(* noprune *) assign GPIO[17] = u_high;
(* noprune *) assign GPIO[23] = u_low;
(* noprune *) assign GPIO[19] = v_high;
(* noprune *) assign GPIO[24] = v_low;
(* noprune *) assign GPIO[21] = w_high;
(* noprune *) assign GPIO[25] = w_low;
*/ 

// GPIO[23] is now sync out - from the DB9 connector - but we don't ever need this signal so we ignore it
/*
(* noprune *) assign GPIO[29] = u_high;
(* noprune *) assign GPIO[19] = u_low;
// DOUBLE CHECK THEM
(* noprune *) assign GPIO[25] = v_high;
(* noprune *) assign GPIO[17] = v_low;

(* noprune *) assign GPIO[21] = w_high;
(* noprune *) assign GPIO[27] = w_low;
*/

(* noprune *) assign GPIO[23] = u_high;
(* noprune *) assign GPIO[19] = u_low;

(* noprune *) assign GPIO[17] = v_high;
(* noprune *) assign GPIO[21] = v_low;

(* noprune *) assign GPIO[29] = w_high;
(* noprune *) assign GPIO[25] = w_low;


(* noprune *) assign GPIO[24] = 0;
(* noprune *) assign GPIO[34] = 0;
(* noprune *) assign GPIO[33] = 0;
(* noprune *) assign GPIO[32] = 0;
(* noprune *) assign GPIO[31] = 0;
(* noprune *) assign GPIO[30] = 0;

(* noprune *) assign GPIO[28] = 0;

(* noprune *) assign GPIO[27] = 0;

(* noprune *) assign GPIO[26] = 0;

/************** MODULE INSTANTIATIONS
********************************/

// In-Signal Sources and Probes
wire [99:0] issp_source_bus;
issp_control issp_control_inst (
    .source_clk (clk),
    //.probe_clk  (clk),
    .source     (issp_source_bus),
    .probe      ()
);

wire GFL_mode = 1'b0; //issp_source_bus[91];
wire combination_mode = 1'b0; //issp_source_bus[92];
wire reset = SW[17]; //issp_source_bus[90];

/*
wire signed [17:0] a2_issp = $signed(issp_source_bus[89:72]);
wire signed [17:0] a1_issp = $signed(issp_source_bus[71:54]);
wire signed [17:0] b2_issp = $signed(issp_source_bus[53:36]);
wire signed [17:0] b1_issp = $signed(issp_source_bus[35:18]);
wire signed [17:0] b0_issp = $signed(issp_source_bus[17:0]);
*/
wire signed [31:0] KP_issp = 32'sd429496730;
wire signed [15:0] VREF_issp = 16'sd1800;//$signed(issp_source_bus[89:74]);
wire signed [15:0] VMAX_issp = 16'sd19000; //$signed(issp_source_bus[73:58]);
wire signed [15:0] VMIN_issp = 16'sd2100; //$signed(issp_source_bus[57:42]);
wire signed [15:0] CONVERSION_issp = 16'sd10000; //$signed(issp_source_bus[41:23]);
wire signed [9:0] KI_issp = 10'sd2; //$signed(issp_source_bus[22:13]);
wire signed [31:0] DT_issp = 32'sd172;
wire VOLT_CONTROL_OFF = SW[16]; // issp_source_bus[12];

/*
wire signed [17:0] a2_issp = $signed(issp_source_bus[89:72]);
wire signed [17:0] a1_issp = $signed(issp_source_bus[71:54]);
wire signed [17:0] b2_issp = $signed(issp_source_bus[53:36]);
wire signed [17:0] b1_issp = $signed(issp_source_bus[35:18]);
wire signed [17:0] b0_issp = $signed(issp_source_bus[17:0]);
*/
// adc_reader - reads from adc into our registers - uses GPIO

adc_reader inst_adc_reader (
  .clk(clk),
  .reset(reset),
  .BUSY(BUSY),
  .FRSTDATA(FRSTDATA),
  .DATA_IN(DATA_IN),
  .RD(RD),
  .CONVST(CONVST),
  .reset_pin(reset_pin),
  .VA(VA),
  .VB(VB),
  .VC(VC),
  .IA(IA),
  .IB(IB),
  .IC(IC),
  .VDC(VDC),
  .GARBAGE(GARBAGE),
  .loading(loading)
);



// For old adc (GFM 1.0)
/*
adc_reader inst_adc_reader (
  .clk(clk),
  .reset(reset),
  .BUSY(BUSY),
  .FRSTDATA(FRSTDATA),
  .DATA_IN(DATA_IN),
  .RD(RD),
  .CONVST(CONVST),
  .reset_pin(reset_pin),
  .VA(VA),
  .VB(VB),
  .VC(VC),
  .IA(IA),
  .IB(IB),
  .IC(IC),
  .VDC(VDC),
  .GARBAGE(GARBAGE),
  .loading(loading)
);
*/


wire [ACC_WIDTH-1:0] phase_acc_dqz;
wire [15:0] amplitude;
// dqz - converts three phase signals into the quadrature value we use - also has the NCO_dqz inside 
dqz #(
    .WORD_SIZE(18),
    .ACC_WIDTH(32)
) inst_dqz (
    .clk(clk),
    .clk_en(clk_en),
    .reset(reset),
    .a_in(VA),      // Passing 16-bit ADC values directly
    .b_in(VB),
    .c_in(VC),
    .freq_in(freq_out), // Taking the frequency/phase output from the IPLL
    .d_out(d_out),
    .q_out(q_out),
	 .phase_acc_dqz(phase_acc_dqz),
	 .amplitude(amplitude)
);

// ipll - inertial phase lock loop - takes quadrature value and outputs corresponding frequency
ipll #(
    .WORD_SIZE(18),
    .ACC_WIDTH(32)
) inst_ipll (
    .clk(clk),
	.clk_en(clk_en),
    .reset(reset),
    .B0(18'sd14359),
    .B1(18'sd490),
    .B2(-18'sd13869),
    .A1(-18'sd126997),
    .A2(18'sd61522),
    .q_in(q_in_ipll),     // Feeding the Q-axis error into the PLL
    .freq_out(freq_out_ipll)
);



srf_pll_1 inst_srf_pll (
    .clk(clk),
	 .clk_en(clk_en),
    .reset(reset),
    .q_in(q_in_srf),     // Feeding the Q-axis error into the PLL
    .freq_out(freq_out_srf)
);

// ========================================================================
// Frequency Output & Input Routing Multiplexers
// ========================================================================

// Constants for 60 Hz and the 0.05 Hz tolerance
localparam signed [31:0] FREQ_60HZ = 32'sd357913941;
localparam signed [31:0] FREQ_TOL  = 32'sd298262;

// Evaluate if the IPLL frequency is within +/- 0.05 Hz of 60 Hz
wire ipll_within_range = (freq_out_ipll >= (FREQ_60HZ - FREQ_TOL)) && 
                         (freq_out_ipll <= (FREQ_60HZ + FREQ_TOL));

// Determine if SRF is the active controller based on your existing switch logic
wire srf_active = GFL_mode ? 1'b1 : 
                  combination_mode ? ipll_within_range : 
                            1'b0;

// Route q_out to the active PLL (tie the inactive one to 0)
wire signed [17:0] q_in_srf  = srf_active ? q_out : 18'sd0;
wire signed [17:0] q_in_ipll = srf_active ? 18'sd0 : q_out;

// Mux logic for freq_out based on switches 
(* noprune *) assign freq_out = srf_active ? freq_out_srf : freq_out_ipll;
									 
(* noprune *) wire signed [63:0] freq_out_fast_big = freq_out * FAST_CONV; // freq out - which is in cycles per sample at 720 samples/sec, into 25M samples/sec

(* noprune *) wire signed [31:0] freq_out_fast = freq_out_fast_big[63:32]; // Top 32 bits after multiplication
(* noprune *) wire signed [31:0] carrier_freq = freq_out_fast * CARRIER_CONV; // freq out fast multiplied by our modulation constant (75)

//reg signed [15:0] adc_in_a;
(* noprune *) wire [15:0] tracked_amplitude_A;
(* noprune *) wire signed [15:0] nco_v_output;


amplitude_finder u_amp_finder (
        .clk(clk), .reset(reset), .adc_in(VA), .amplitude(tracked_amplitude_A)
); 

volt_control_filt u_volt_ctrl (
        .clk(clk), .reset(reset), .clk_en(clk_en),
        .V_input(amplitude),
		  .KP(KP_issp),
		  .VREF(VREF_issp),
		  .VOLT_CONTROL_OFF(VOLT_CONTROL_OFF),
		  .DT(DT_issp),
		  .VMIN(VMIN_issp),
		  .VMAX(VMAX_issp),
		  .KI(KI_issp),
		  .CONVERSION(CONVERSION_issp),
        .V_output(nco_v_output)
    );
/*
spwm - pulse width modulation - controls switches of inverter with GPIO
*/
inverter_top_new #(
        .WORD_SIZE(18),
        .ACC_WIDTH(32)
    ) inst_inverter_top (
        .clk(clk),
        .clk_en(clk_en),
        .reset(reset),
        .freq_in(freq_out_fast),
		  //.freq_in_dqz(freq_out),
        .carrier_fcw(carrier_freq),
        .d_in(d_out), // This doesn't use q out anyway
        .q_in(q_out), // This doesn't use d out
        .u_high(u_high),
        .u_low(u_low),
        .v_high(v_high),
        .v_low(v_low),
        .w_high(w_high),
        .w_low(w_low),
		  .phase_acc_dqz(phase_acc_dqz),
		  .V_scale(nco_v_output)
    );
	 

/*
math - calculates power and other things we want to monitor in our data
*/

endmodule
