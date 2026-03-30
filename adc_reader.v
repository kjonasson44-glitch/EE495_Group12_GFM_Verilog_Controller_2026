// =============================================================================
// Module Name:  adc_reader
// Description:  Interface controller for the AD7606 Simultaneous Sampling ADC.
//               This module manages the timing for conversion triggers and 
//               sequential data readout over a parallel bus.
//
// Parameters:
//   - Clock Frequency: 25 MHz
//   - Target Sample Rate: 720 Hz
//   - Timer Limit: 34,722 cycles (25 MHz / 720 Hz)
//
// Architecture:
//   - Finite State Machine (FSM): Manages the CONVST pulse, BUSY monitoring, 
//     and the 8-channel sequential read process.
//   - Synchronization: Double-registers the asynchronous BUSY signal to 
//     prevent metastability.
//   - Phase Coherency: Captures data into temporary registers and updates 
//     all outputs simultaneously at the end of a cycle.
//
// ADC Operation:
//   1. Conversion is triggered by a pulse on CONVST.
//   2. The module waits for the BUSY signal to transition from high to low.
//   3. Eight sequential read pulses (RD) are generated to latch data for 
//      VA, VB, VC, IA, IB, IC, VDC, and a garbage channel.
// =============================================================================

module adc_reader (
    input wire clk,                  // System Clock (25 MHz)
    input wire reset,                // System Reset
    
    // AD7606 Hardware Signals
    input wire BUSY,                 // ADC is currently converting
    input wire FRSTDATA,             // Indicates Channel 1 is on the bus
    input wire signed [15:0] DATA_IN,// Parallel data from ADC
    
    // ADC Control Signals
    output reg RD,                   // Read signal (active low)
    output reg CONVST,               // Conversion Start (Pulse)
    output reg reset_pin,            // Hardware Reset Pin
    
    // Processed Outputs
    output reg signed [15:0] VA,     // Channel 1
    output reg signed [15:0] VB,     // Channel 3
    output reg signed [15:0] VC,     // Channel 5
    output reg signed [15:0] IA,     // Channel 2
    output reg signed [15:0] IB,     // Channel 4
    output reg signed [15:0] IC,     // Channel 6
    output reg signed [15:0] VDC,    // Channel 7
    output reg signed [15:0] GARBAGE,// Channel 8
    output reg loading               // High during conversion/read
);

    // ==========================================
    // Parameters and State Definitions
    // ==========================================
    localparam TIMER_LIMIT      = 34722; // 720 Hz @ 25 MHz

    localparam S_IDLE           = 0; // Wait for timer
    localparam S_PULSE_LOW      = 1; // Drive CONVST Low
    localparam S_PULSE_HIGH     = 2; // Drive CONVST High
    localparam S_WAIT_BUSY_LOW  = 3; // Wait for conversion end
    localparam S_READ_LOW       = 4; // Drive RD low
    localparam S_READ_CAPTURE   = 5; // Capture data, Drive RD high
    localparam S_UPDATE_OUTPUTS = 6; // Update final registers
    localparam S_READ_HOLD      = 7; // 1-clock delay for stability

    // Internal Registers
    reg [3:0]  state;               // FSM State
    reg [15:0] samp_timer;          // Timer for 720 Hz
    reg [3:0]  channel_index;       // Channel tracker (0-7)
    reg signed [15:0] temp_data [0:7]; // Temp storage
    reg [1:0]  rd_delay_cnt;        // Read timing delay
    
    // Synchronizer for BUSY input
    reg busy_sync_1, busy_sync_2;
    always @(posedge clk) begin
        busy_sync_1 <= BUSY;
        busy_sync_2 <= busy_sync_1;
    end
    wire busy_clean = busy_sync_2;

    // ==========================================
    // Main State Machine
    // ==========================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state           <= S_IDLE;
            samp_timer      <= 0;
            channel_index   <= 0;
            CONVST          <= 1; // Idle High
            RD              <= 1;
            reset_pin       <= 1;
            loading         <= 0;
            VA <= 0; VB <= 0; VC <= 0;
            IA <= 0; IB <= 0; IC <= 0;
            VDC <= 0;
        end 
        else begin
            case (state)
                // Wait for the 720 Hz Timer
                S_IDLE: begin
                    loading         <= 0;
                    CONVST          <= 0; // Ensure Idle Low
                    reset_pin       <= 0;
                    if (samp_timer >= TIMER_LIMIT) begin
                        samp_timer  <= 0;
                        state       <= S_PULSE_LOW;
                    end else begin
                        samp_timer  <= samp_timer + 1;
                    end
                end

                // Drive CONVST High to trigger conversion
                S_PULSE_LOW: begin
                    loading <= 1;
                    CONVST  <= 1; 
                    state   <= S_PULSE_HIGH; 
                end

                // Maintain Pulse and prepare for BUSY response
                S_PULSE_HIGH: begin
                    loading <= 1;
                    CONVST  <= 0; // Falling edge triggers sampling
                    state   <= S_WAIT_BUSY_LOW;
                end

                // Wait for Conversion to Complete (BUSY -> 0)
                S_WAIT_BUSY_LOW: begin
                    loading <= 1;
                    CONVST  <= 0; 
                    if (busy_clean == 0) begin
                        channel_index <= 0;
                        state         <= S_READ_LOW;
                    end
                end

                // Start Read Sequence: Drive RD Low
                S_READ_LOW: begin
                    loading <= 1;
                    RD      <= 0; // Active Low
                    if (rd_delay_cnt > 1) begin 
                        rd_delay_cnt <= 0;
                        state <= S_READ_CAPTURE;
                    end else begin
                        rd_delay_cnt <= rd_delay_cnt + 1;
                    end
                end

                // Capture Data and Drive RD High
                S_READ_CAPTURE: begin
                    loading <= 1;
                    RD      <= 1; 
                    temp_data[channel_index] <= DATA_IN;
                    if (channel_index == 7) begin
                        state <= S_UPDATE_OUTPUTS;
                    end else begin
                        channel_index <= channel_index + 1;
                        state         <= S_READ_HOLD;
                    end
                end
					 
                // Delay for signal stability between reads
                S_READ_HOLD: begin
                    loading <= 1;
                    RD      <= 1;
                    state   <= S_READ_LOW;
                end

                // Final Output Update (Phase Coherency)
                S_UPDATE_OUTPUTS: begin
                    loading <= 0;
                    VA      <= temp_data[0];
                    IA      <= temp_data[1];
                    VB      <= temp_data[2];
                    IB      <= temp_data[3];
                    VC      <= temp_data[4];
                    IC      <= temp_data[5];
                    VDC     <= temp_data[6];
                    GARBAGE <= temp_data[7];
                    state   <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

// =============================================================================
// ADC INFORMATION & DATASHEET NOTES
// =============================================================================
// Signals:
// - BUSY Output: Transitions to high after CONVST rising edges. 
// - The BUSY output remains high until conversion for all channels is complete.
// - Falling edge of BUSY signals that data is latched and available to read.
// - RD: Falling edge puts next channel on bus.
// - CONVST: Rising edge begins the sampling process.
//
// Critical Timing:
// - Data read while BUSY is high must finish before BUSY falls.
// - CONVST pulses are ignored while BUSY is high.
// - First sample indicates that data on the bus is from the first channel.
// =============================================================================

endmodule
	
	
