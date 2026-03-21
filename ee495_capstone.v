// Written by Kelvin Jonasson and David Mielke - kjonasson44@gmail.com and davidpetermielke@gmail.com
module ee495_capstone (
     input wire CLOCK_50,             // System Clock (50 MHz)
     inout wire [35:0] GPIO,          // GPIO (36 pins)
     input wire [17:0] SW,
     input wire [3:0] KEY
);

/******************************* CLOCKS
********************************/
localparam CLK_FREQ_HZ     = 25_000_000;  // 25 MHz System Clock
localparam SAMPLE_RATE_HZ  = 720;         // Target Data Rate
localparam CLKS_PER_SAMPLE = CLK_FREQ_HZ / SAMPLE_RATE_HZ; // ~34,722 clocks

localparam FAST_CONV = 123695; // 0s32 of 720/25M
localparam CARRIER_CONV = 75; // 75 as in matlab

integer timer_cnt;
reg clk = 0;
reg clk_en = 0;

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
assign GPIO[22] = CONVST;
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
(* noprune *) assign GPIO[29] = u_high;
(* noprune *) assign GPIO[19] = u_low;

(* noprune *) assign GPIO[25] = v_high;
(* noprune *) assign GPIO[17] = v_low;

(* noprune *) assign GPIO[21] = w_high;
(* noprune *) assign GPIO[27] = w_low;

(* noprune *) assign GPIO[34] = 0;
(* noprune *) assign GPIO[33] = 0;
(* noprune *) assign GPIO[32] = 0;
(* noprune *) assign GPIO[31] = 0;
(* noprune *) assign GPIO[30] = 0;
(* noprune *) assign GPIO[28] = 0;
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

wire mode = issp_source_bus[91];
wire reset = issp_source_bus[90];
wire signed [17:0] a2_issp = $signed(issp_source_bus[89:72]);
wire signed [17:0] a1_issp = $signed(issp_source_bus[71:54]);
wire signed [17:0] b2_issp = $signed(issp_source_bus[53:36]);
wire signed [17:0] b1_issp = $signed(issp_source_bus[35:18]);
wire signed [17:0] b0_issp = $signed(issp_source_bus[17:0]);

// adc_reader - reads from adc into our registers - uses GPIO

adc_reader_new inst_adc_reader (
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
    .q_out(q_out)
);

// ipll - inertial phase lock loop - takes quadrature value and outputs corresponding frequency
ipll #(
    .WORD_SIZE(18),
    .ACC_WIDTH(32)
) inst_ipll (
    .clk(clk),
	.clk_en(clk_en),
    .reset(reset),
    .B0(b0_issp),
    .B1(b1_issp),
    .B2(b2_issp),
    .A1(a1_issp),
    .A2(a2_issp),
    .q_in(q_out),     // Feeding the Q-axis error into the PLL
    .freq_out(freq_out_ipll)
);



srf_pll_1 inst_srf_pll (
    .clk(clk),
	 .clk_en(clk_en),
    .reset(reset),
    .q_in(q_out),     // Feeding the Q-axis error into the PLL
    .freq_out(freq_out_srf)
);

// ========================================================================
// Frequency Output Multiplexer
// ========================================================================

// Constants for 60 Hz and the 0.05 Hz tolerance
localparam signed [31:0] FREQ_60HZ = 32'sd357913941;
localparam signed [31:0] FREQ_TOL  = 32'sd298262;

// Evaluate if the IPLL frequency is within +/- 0.05 Hz of 60 Hz
wire ipll_within_range = (freq_out_ipll >= (FREQ_60HZ - FREQ_TOL)) && 
                         (freq_out_ipll <= (FREQ_60HZ + FREQ_TOL));

// Mux logic for freq_out based on switches 
// If SW 0 is high - we use freq_out_srf - which is GRID FOLLOWING
(* noprune *) assign freq_out = (SW[0]) ? freq_out_srf :                                       // SW 0 High: Force SRF
                  (SW[1]) ? (ipll_within_range ? freq_out_srf : freq_out_ipll) : // SW 0 Low, SW 1 High: Combination Mode
                            freq_out_ipll;
									 
(* noprune *) wire signed [63:0] freq_out_fast_big = freq_out * FAST_CONV; // freq out - which is in cycles per sample at 720 samples/sec, into 25M samples/sec

(* noprune *) wire signed [31:0] freq_out_fast = freq_out_fast_big[63:32]; // Top 32 bits after multiplication
(* noprune *) wire signed [31:0] carrier_freq = freq_out_fast * CARRIER_CONV; // freq out fast multiplied by our modulation constant (75)

/*
spwm - pulse width modulation - controls switches of inverter with GPIO
*/
inverter_top #(
        .WORD_SIZE(18),
        .ACC_WIDTH(32)
    ) inst_inverter_top (
        .clk(clk),
        .clk_en(clk_en),
        .reset(reset),
        .freq_in(freq_out_fast),
        .carrier_fcw(carrier_freq),
        .d_in(d_out),
        .q_in(q_out),
        .u_high(u_high),
        .u_low(u_low),
        .v_high(v_high),
        .v_low(v_low),
        .w_high(w_high),
        .w_low(w_low)
    );


/*
math - calculates power and other things we want to monitor in our data
*/

endmodule
