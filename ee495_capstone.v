// =============================================================================
// Module Name:  ee495_capstone
// Description:  Top-level module for a three-phase grid-following inverter.
//
// Instantiations:
//   - issp_control: Provides an In-System Sources and Probes interface for real-time debugging and parameter adjustment.
//   - adc_reader: Interfaces with the external hardware ADC to read analog data.
//   - dqz: Performs Clarke and Park transformations to convert stationary three-phase signals into a rotating reference frame.
//   - ipll: Implements an inertial second-order IIR filter to track system frequency from the quadrature voltage signal.
//   - srf_pll: Synchronizes the system to the grid using a standard synchronous rotating frame phase-locked loop.
//   - volt_control_filt: Executes PI-based voltage regulation to maintain the inverter output amplitude at the reference level.
//   - inverter_top: Manages the generation of Sinusoidal Pulse Width Modulation (SPWM) signals to drive the power inverter switches.
// =============================================================================

module ee495_capstone (
    input wire CLOCK_50,             // System Clock (50 MHz)
    inout wire [35:0] GPIO,          // GPIO (36 pins)
    input wire [17:0] SW,
    input wire [3:0] KEY
);

   // =========================================================================
   // Parameters and Constants
   // =========================================================================
   localparam ACC_WIDTH       = 32;
   localparam CLK_FREQ_HZ     = 25_000_000;
   localparam SAMPLE_RATE_HZ  = 720;         
   localparam CLKS_PER_SAMPLE = CLK_FREQ_HZ / SAMPLE_RATE_HZ; // ~34,722 clocks
   localparam SAMPLING_CLK    = 10; 

   localparam FAST_CONV       = 123695; // 0s32 
   localparam CARRIER_CONV    = 75; 

   localparam signed [31:0] FREQ_60HZ = 32'sd357913941;
   localparam signed [31:0] FREQ_TOL  = 32'sd298262;

   // =========================================================================
   // Clock and Timing Logic
   // =========================================================================
   integer timer_cnt;
   integer timer_cnt2;
   reg clk = 0;
   reg clk_en = 0;
   reg sampling_clk = 0;

   always @ (posedge CLOCK_50) begin
       clk = ~clk;
   end

   always @(posedge clk or posedge reset) begin
       if (reset) begin
           timer_cnt <= 0;
           clk_en <= 1'd0;
       end else begin
           if (timer_cnt >= CLKS_PER_SAMPLE - 1) begin
               timer_cnt <= 0;
               clk_en <= 1;
           end else begin
               timer_cnt <= timer_cnt + 1;
               clk_en <= 0;
           end
       end
   end

   // =========================================================================
   // Signal Declarations
   // =========================================================================
   (* noprune *) wire reset_pin;
   (* noprune *) wire signed [15:0] VA, VB, VC;
   (* noprune *) wire signed [15:0] IA, IB, IC;
   (* noprune *) wire signed [15:0] VDC, GARBAGE;
   (* noprune *) wire loading;

   (* noprune *) wire RD, CONVST;
   (* noprune *) wire u_high, u_low, v_high, v_low, w_high, w_low;

   (* noprune *) wire signed [17:0] d_out; // 1s15
   (* noprune *) wire signed [17:0] q_out; // 1s15
   (* noprune *) wire signed [31:0] freq_out_ipll; // 0s32
   (* noprune *) wire signed [31:0] freq_out_srf;
   (* noprune *) wire signed [31:0] freq_out;
   (* noprune *) wire signed [17:0] nco_sine, nco_cosine;

   // External Hardware Mapping
   (* noprune *) wire BUSY     = GPIO[20];
   (* noprune *) wire FRSTDATA = GPIO[16];
   (* noprune *) wire signed [15:0] DATA_IN = GPIO[15:0];

   // =========================================================================
   // Control and Multiplexer Logic
   // =========================================================================
   wire [99:0] issp_source_bus;
   wire GFL_mode         = issp_source_bus[91];
   wire combination_mode = issp_source_bus[92];
   wire reset            = issp_source_bus[90];
   wire PWM_SW_OFF       = issp_source_bus[93];
   wire VOLT_CONTROL_OFF = issp_source_bus[12];

   wire signed [31:0] KP_issp         = 32'sd429496730;
   wire signed [15:0] VREF_issp       = $signed(issp_source_bus[89:74]);
   wire signed [15:0] VMAX_issp       = $signed(issp_source_bus[73:58]);
   wire signed [15:0] VMIN_issp       = $signed(issp_source_bus[57:42]);
   wire signed [15:0] CONVERSION_issp = $signed(issp_source_bus[41:23]);
   wire signed [9:0]  KI_issp         = $signed(issp_source_bus[22:13]);
   wire signed [31:0] DT_issp         = 32'sd172;

   wire ipll_within_range = (freq_out_ipll >= (FREQ_60HZ - FREQ_TOL)) && 
                            (freq_out_ipll <= (FREQ_60HZ + FREQ_TOL));

   wire srf_active = GFL_mode ? 1'b1 : 
                     combination_mode ? ipll_within_range : 1'b0;

   wire signed [17:0] q_in_srf  = srf_active ? q_out : 18'sd0;
   wire signed [17:0] q_in_ipll = srf_active ? 18'sd0 : q_out;

   (* noprune *) assign freq_out = srf_active ? freq_out_srf : freq_out_ipll;
   (* noprune *) wire signed [63:0] freq_out_fast_big = freq_out * FAST_CONV;
   (* noprune *) wire signed [31:0] freq_out_fast = freq_out_fast_big[63:32]; // 0s32
   (* noprune *) wire signed [31:0] carrier_freq = freq_out_fast * CARRIER_CONV; // 0s32

   // =========================================================================
   // GPIO Assignments
   // =========================================================================
   assign GPIO[18] = RD;
   assign GPIO[22] = CONVST;
   assign GPIO[35] = reset_pin;
   assign GPIO[23] = PWM_SW_OFF ? 1'b0 : u_high;
   assign GPIO[19] = PWM_SW_OFF ? 1'b0 : u_low;
   assign GPIO[17] = PWM_SW_OFF ? 1'b0 : v_high;
   assign GPIO[21] = PWM_SW_OFF ? 1'b0 : v_low;
   assign GPIO[29] = PWM_SW_OFF ? 1'b0 : w_high;
   assign GPIO[25] = PWM_SW_OFF ? 1'b0 : w_low;

   assign GPIO[24] = 0; assign GPIO[34] = 0; assign GPIO[33] = 0;
   assign GPIO[32] = 0; assign GPIO[31] = 0; assign GPIO[30] = 0;
   assign GPIO[28] = 0; assign GPIO[27] = 0; assign GPIO[26] = 0;

   // =========================================================================
   // Module Instantiations
   // =========================================================================
   issp_control issp_control_inst (
       .source_clk (clk),
       .source     (issp_source_bus),
       .probe      ()
   );

   adc_reader inst_adc_reader (
       .clk(clk), .reset(reset), .BUSY(BUSY), .FRSTDATA(FRSTDATA), .DATA_IN(DATA_IN),
       .RD(RD), .CONVST(CONVST), .reset_pin(reset_pin), .VA(VA), .VB(VB), .VC(VC),
       .IA(IA), .IB(IB), .IC(IC), .VDC(VDC), .GARBAGE(GARBAGE), .loading(loading)
   );

   dqz #(
       .WORD_SIZE(18), .ACC_WIDTH(32)
   ) inst_dqz (
       .clk(clk), .clk_en(clk_en), .reset(reset), .a_in(VA), .b_in(VB), .c_in(VC),
       .freq_in(freq_out), .d_out(d_out), .q_out(q_out), .phase_acc_dqz(phase_acc_dqz),
       .amplitude(amplitude)
   );

   ipll #(
       .WORD_SIZE(18), .ACC_WIDTH(32)
   ) inst_ipll (
       .clk(clk), .clk_en(clk_en), .reset(reset), .B0(18'sd14359), .B1(18'sd490),
       .B2(-18'sd13869), .A1(-18'sd126997), .A2(18'sd61522), .q_in(q_in_ipll),
       .freq_out(freq_out_ipll)
   );

   srf_pll inst_srf_pll (
       .clk(clk), .clk_en(clk_en), .reset(reset), .q_in(q_in_srf), .freq_out(freq_out_srf)
   );

   volt_control_filt inst_volt_ctrl (
       .clk(clk), .reset(reset), .clk_en(clk_en), .V_input(amplitude), .KP(KP_issp),
       .VREF(VREF_issp), .VOLT_CONTROL_OFF(VOLT_CONTROL_OFF), .DT(DT_issp),
       .VMIN(VMIN_issp), .VMAX(VMAX_issp), .KI(KI_issp), .CONVERSION(CONVERSION_issp),
       .V_output(nco_v_output)
   );

   inverter_top #(
       .WORD_SIZE(18), .ACC_WIDTH(32)
   ) inst_inverter_top (
       .clk(clk), .clk_en(clk_en), .reset(reset), .freq_in(freq_out_fast),
       .carrier_fcw(carrier_freq), .d_in(d_out), .q_in(q_out), .u_high(u_high),
       .u_low(u_low), .v_high(v_high), .v_low(v_low), .w_high(w_high), .w_low(w_low),
       .phase_acc_dqz(phase_acc_dqz), .scale(nco_v_output)
   );

endmodule