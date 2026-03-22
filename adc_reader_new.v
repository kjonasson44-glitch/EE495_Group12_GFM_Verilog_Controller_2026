module adc_reader_new ( 
    input wire clk,             // System Clock (25 MHz) 
    input wire reset,           // System Reset 
     
    // AD7606/AD7609 Hardware Signals 
    input wire BUSY,            // ADC is currently converting 
    input wire FRSTDATA,        // Indicates Channel 1 is on the bus 
    input wire signed [15:0] DATA_IN,// Parallel data from ADC 
     
    // ADC Control Signals 
    output reg RD,              // Read signal (active low) 
    output reg CONVST,          // Conversion Start (Active Low Pulse) 
    output reg reset_pin, 
     
    // Processed Outputs 
    output reg signed [15:0] VA, 
    output reg signed [15:0] VB, 
    output reg signed [15:0] VC, 
    output reg signed [15:0] IA, 
    output reg signed [15:0] IB, 
    output reg signed [15:0] IC, 
    output reg signed [15:0] VDC, 
    output reg signed [15:0] GARBAGE, 
    output reg loading          // High when reading/converting 
); 
 
    // ========================================== 
    // Parameters and Timers 
    // ========================================== 
     
    // Clock is 25 MHz. Desired sample rate is 720 Hz. 
    // Count = 25,000,000 / 720 = 34,722 
    localparam TIMER_LIMIT = 3472; // Divided by 10 for new clk
     
    // State Definitions 
    localparam S_IDLE           = 0; 
    localparam S_PULSE_LOW      = 1; // Drive CONVST Low 
    localparam S_PULSE_HIGH     = 2; // Drive CONVST High (Rising Edge triggers sample) 
    localparam S_WAIT_BUSY_LOW  = 3; // Wait for ADC to finish conversion 
    localparam S_READ_LOW       = 4; // Drive RD low 
    localparam S_READ_CAPTURE   = 5; // Capture data, Drive RD high 
    localparam S_UPDATE_OUTPUTS = 6; // Update final registers 
    localparam S_READ_HOLD      = 7; // New state to provide a 1-clock delay 
	 localparam S_CONV_HOLD      = 8; // New state to provide a 1-clock delay 
	 localparam S_CONV_HOLD2      = 9; // New state to provide a 1-clock delay
	 localparam S_CONV_HOLD3      = 10; // New state to provide a 1-clock delay
 
    reg [3:0] state;             // Current State 
    reg [15:0] samp_timer;       // Timer for 720Hz 
    reg [3:0] channel_index;     // Tracks which channel (0-7) we are reading 
    reg read_phase;              // NEW: Toggles between 1st read (capture) and 2nd read (ignore)
     
    // Temporary registers to hold data during the read process 
    reg signed [15:0] temp_data [0:7]; 
    reg [1:0] rd_delay_cnt;      // Added delay counter, adjust bit width for desired delay 
    reg [1:0] rd_delay_cnt2;     // Added delay counter, adjust bit width for desired delay 
 
    // Synchronizer for asynchronous inputs 
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
            read_phase      <= 0; // Initialize read phase
             
            // UPDATED: CONVST idles High
            CONVST          <= 0;  
            RD              <= 1;  
            reset_pin       <= 1; 
            loading         <= 0;  
             
            // Reset outputs 
            VA <= 0; VB <= 0; VC <= 0; 
            IA <= 0; IB <= 0; IC <= 0; 
            VDC <= 0; 
            GARBAGE <= 0;
        end  
        else begin 
             
            case (state) 
             
                // --------------------------------------------------------- 
                // 1. Wait for the 720Hz Timer 
                // --------------------------------------------------------- 
                S_IDLE: begin 
                    loading <= 0; 
                    CONVST  <= 0; // Ensure Idle Low
						  RD		 <= 1; 
                    reset_pin <= 0; 
                     
                    if (samp_timer >= TIMER_LIMIT) begin 
                        samp_timer <= 0; 
                        state      <= S_PULSE_LOW; 
                    end else begin 
                        samp_timer <= samp_timer + 1; 
                    end 
                end 
 
                // --------------------------------------------------------- 
                // 2. Drive CONVST High (Rising Edge starts sampling) 
                // --------------------------------------------------------- 
                S_PULSE_LOW: begin 
                    loading <= 1; 
                    CONVST  <= 1; // Pulse High 
                    state   <= S_CONV_HOLD; 
                end 
 
                // --------------------------------------------------------- 
                // 3. Drive CONVST Low 
                // --------------------------------------------------------- 
                S_PULSE_HIGH: begin 
                    loading <= 1; 
                    CONVST  <= 0; // Falling Edge! Sampling starts here. //Sampling is on rising edge
                    state   <= S_WAIT_BUSY_LOW; 
                end 
 
                // --------------------------------------------------------- 
                // 4. Wait for Conversion to Complete (BUSY -> 0) 
                // --------------------------------------------------------- 
                S_WAIT_BUSY_LOW: begin 
                    loading <= 1; 
                    CONVST  <= 0; // Hold Low 
						  
						  // Delete this if going back to busy clean == 0
						  channel_index <= 0;
                    read_phase    <= 0; // Ensure we start on the capture phase 
						  state         <= S_READ_LOW;
						  
                     
							/*
                    if (busy_clean ==0) begin // THIS IS wrong
                        channel_index <= 0;
                        read_phase    <= 0; // Ensure we start on the capture phase 
								state         <= S_READ_LOW;
                    end */
                end 
 
                // --------------------------------------------------------- 
                // 5. Read Sequence: Drive RD Low 
                // --------------------------------------------------------- 
                S_READ_LOW: begin 
                    loading <= 1; 
                    RD      <= 0; // Active Low 
                             
                    // Wait before capture 
                    if (rd_delay_cnt > 1) begin // Two clock cycles 
                        rd_delay_cnt <= 0; 
                        state <= S_READ_CAPTURE; 
                    end else begin 
                        rd_delay_cnt <= rd_delay_cnt + 1; 
                    end 
                end 
					 // t10 tolerance is 37 ns in worst case - we do 80 ns just to be safe 
					 // t11 tolerance is 15 ns - we do 40 ns to be safe
 
                // --------------------------------------------------------- 
                // 6. Read Sequence: Capture Data & Drive RD High 
                // --------------------------------------------------------- 
                S_READ_CAPTURE: begin 
                    loading <= 1; 
                    RD      <= 0; // Drive High -> Keep low while reading (active low) 
                     
                    if (read_phase == 0) begin
                        // Phase 0: First pulse, capture the top 16 bits
                        temp_data[channel_index] <= DATA_IN; 
                        read_phase <= 1; // Set up to throw away the next read
                        state      <= S_READ_HOLD;
                    end else begin
                        // Phase 1: Second pulse, ignore the bottom 2 bits
                        read_phase <= 0; // Reset for the next channel
                        
                        if (channel_index == 7) begin 
                            state <= S_UPDATE_OUTPUTS;  
                        end else begin 
                            channel_index <= channel_index + 1; 
                            state         <= S_READ_HOLD; // Go to delay state
                        end 
                    end
                end 
                     
                // --------------------------------------------------------- 
                // 6b. Read Hold: Wait 1 cycle with RD High 
                // --------------------------------------------------------- 
                S_READ_HOLD: begin 
                    loading <= 1; 
                    RD      <= 1;        // Keep RD high for this extra cycle //Read goes high here because read is done these naming conventions are bad
                    state   <= S_READ_LOW; // Return to start the next read pulse
                end 
 
                // --------------------------------------------------------- 
                // 7. Update Outputs (Phase Coherency) 
                // --------------------------------------------------------- 
                S_UPDATE_OUTPUTS: begin 
                    loading <= 0; 
                     
                    VA  <= temp_data[0]; //Channel 1 
                    IA  <= temp_data[1]; //Channel 2 
                    VB  <= temp_data[2]; //Channel 3 
                    IB  <= temp_data[3]; //Channel 4 
                    VC  <= temp_data[4]; //Channel 5 
                    IC  <= temp_data[5]; //Channel 6 
                    VDC <= temp_data[6]; //Channel 7 
                    GARBAGE <= temp_data[7]; //Channel 8 
                     
                    state <= S_IDLE; 
                end 
					 
					 S_CONV_HOLD: begin 
                    loading <= 1; 
                    CONVST  <= 1; // Pulse High 
                    state   <= S_CONV_HOLD2; 
                end
					 
					 S_CONV_HOLD2: begin 
                    loading <= 1; 
                    CONVST  <= 1; // Pulse High 
                    state   <= S_CONV_HOLD3; 
                end
					 
					 S_CONV_HOLD3: begin 
                    loading <= 1; 
                    CONVST  <= 1; // Pulse High 
                    state   <= S_PULSE_HIGH; 
                end
 
                default: state <= S_IDLE; 
            endcase 
        end 
    end 
 
endmodule
