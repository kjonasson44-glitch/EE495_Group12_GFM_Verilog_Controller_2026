// Written by Kelvin Jonasson and David Meilke - kjonasson44@gmail.com and davidpetermielke@gmail.com
module ee495_capstone_pwm_test (
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
localparam CENTRE_FREQ = 32'd357913941;
localparam CARRIER_FREQ = 32'd29826161750;

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

(* noprune *) wire reset; // This is a wire in adc_reader and we do nothing with it
(* noprune *) wire reset_pin;
/*
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

// Interconnect wires for the DSP chain
(* noprune *) wire signed [17:0] d_out;
(* noprune *) wire signed [17:0] q_out;
(* noprune *) wire signed [31:0] freq_out;
(* noprune *) wire signed [17:0] nco_sine;
(* noprune *) wire signed [17:0] nco_cosine;

// Inputs from external hardware
(* noprune *) wire BUSY     = GPIO[20];
(* noprune *) wire FRSTDATA = GPIO[16];
(* noprune *) wire signed [15:0] DATA_IN = GPIO[15:0];

// Outputs to external hardware
assign GPIO[18] = RD;
assign GPIO[22] = CONVST;
(* noprune *) assign GPIO[35] = reset_pin;
//assign GPIO[35] = ~KEY[0]; //reset;

(* noprune *) wire u_high;
(* noprune *) wire u_low;
(* noprune *) wire v_high;
(* noprune *) wire v_low;
(* noprune *) wire w_high;
(* noprune *) wire w_low;

/************** MODULE INSTANTIATIONS
********************************/

/*
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

// dqz - converts three phase signals into the quadrature value we use - also has the NCO
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
	 //.sine(nco_sine),
	 //.cosine(nco_cosine),
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
    .q_in(q_out),     // Feeding the Q-axis error into the PLL
    .freq_out(freq_out)
);

// nco - takes in a frequency and outputs a sinusoid of that frequency
// NOTE: Another nco is instantiated within dqz at the moment
/*
nco #(
    .WORD_SIZE(18),
    .ADDR_SIZE(10),
    .ACC_WIDTH(32)
) inst_standalone_nco (
    .clk(clk),
    .clk_en(clk_en),
    .reset(reset),
    .fcw(freq_out),   // Driven by the PLL's calculated frequency
    .sine(nco_sine),
    .cosine(nco_cosine)
);
*/

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
        .freq_in(CENTRE_FREQ),
        .carrier_fcw(CARRIER_FREQ),
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