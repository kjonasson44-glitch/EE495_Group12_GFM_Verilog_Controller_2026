module adc_reader (
    input wire clk,             // System Clock (25 MHz)
    input wire reset,           // System Reset
    
    // AD7606 Hardware Signals
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
    localparam TIMER_LIMIT = 34722;
    
    // State Definitions
    localparam S_IDLE           = 0;
    localparam S_PULSE_LOW      = 1; // Drive CONVST Low
    localparam S_PULSE_HIGH     = 2; // Drive CONVST High (Rising Edge triggers sample)
    localparam S_WAIT_BUSY_LOW  = 3; // Wait for ADC to finish conversion
    localparam S_READ_LOW       = 4; // Drive RD low
    localparam S_READ_CAPTURE   = 5; // Capture data, Drive RD high
    localparam S_UPDATE_OUTPUTS = 6; // Update final registers

    reg [3:0] state;             // Current State
    reg [15:0] samp_timer;       // Timer for 720Hz
    reg [3:0] channel_index;     // Tracks which channel (0-7) we are reading
    
    // Temporary registers to hold data during the read process
    reg signed [15:0] temp_data [0:7]; 

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
            
            // UPDATED: CONVST idles High [cite: 209]
            CONVST          <= 1; 
            RD              <= 1; 
			   reset_pin       <= 1;
            loading         <= 0; 
            
            // Reset outputs
            VA <= 0; VB <= 0; VC <= 0;
            IA <= 0; IB <= 0; IC <= 0;
            VDC <= 0;
        end 
        else begin
            // Default signal states to prevent latches
            // CONVST defaults to 1 (High)
            // RD defaults to 1 (High)
            
            case (state)
            
                // ---------------------------------------------------------
                // 1. Wait for the 720Hz Timer
                // ---------------------------------------------------------
                S_IDLE: begin
                    loading <= 0;
                    CONVST  <= 0; // Ensure Idle Low
		              reset_pin       <= 0;
                    
                    if (samp_timer >= TIMER_LIMIT) begin
                        samp_timer <= 0;
                        state      <= S_PULSE_LOW;
                    end else begin
                        samp_timer <= samp_timer + 1;
                    end
                end

                // ---------------------------------------------------------
                // 2. Drive CONVST Low
                // ---------------------------------------------------------
                S_PULSE_LOW: begin
                    loading <= 1;
                    CONVST  <= 1; // Pulse High
                    
                    // The datasheet requires a minimum low pulse width (t2) of 25ns.
                    // 1 clock cycle at 25MHz is 40ns. 
                    // So holding this for 1 cycle is sufficient.
                    state   <= S_PULSE_HIGH;
                end

                // ---------------------------------------------------------
                // 3. Drive CONVST High (Rising Edge starts sampling)
					 // Note: The rising edge of CONVST is when BUSY from the ADC goes high, so right now the ADC is busy, and we can't read from it. 
                // ---------------------------------------------------------
                S_PULSE_HIGH: begin
                    loading <= 1;
                    CONVST  <= 0; // Falling Edge! Sampling starts here.
                    
                    // Now we wait for the BUSY signal to indicate conversion is done.
                    // Note: BUSY goes high almost immediately after this rising edge.
                    // We jump straight to waiting for it to go LOW.
                    state   <= S_WAIT_BUSY_LOW;
                end

                // ---------------------------------------------------------
                // 4. Wait for Conversion to Complete (BUSY -> 0)
                // ---------------------------------------------------------
                S_WAIT_BUSY_LOW: begin
                    loading <= 1;
                    CONVST  <= 0; // Hold Low
                    
                    // We check if BUSY is low.
                    // We must ensure we don't catch "BUSY hasn't gone high yet"
                    // but at 25MHz, the ADC response is usually fast enough 
                    // that by the time we get here, BUSY is already high.
                    // If you want to be extra safe, you can add a "Wait for Busy High"
                    // state before this, but usually not strictly necessary if clock is slow.
                    if (busy_clean == 0) begin
                        channel_index <= 0;
                        state         <= S_READ_LOW;
                    end
                end

                // ---------------------------------------------------------
                // 5. Read Sequence: Drive RD Low
                // ---------------------------------------------------------
                S_READ_LOW: begin
                    loading <= 1;
                    RD      <= 0; // Active Low
                    state   <= S_READ_CAPTURE; 
                end

                // ---------------------------------------------------------
                // 6. Read Sequence: Capture Data & Drive RD High
                // ---------------------------------------------------------
                S_READ_CAPTURE: begin
                    loading <= 1;
                    RD      <= 1; // Drive High
                    
                    // Capture data
                    temp_data[channel_index] <= DATA_IN;
                    
                    if (channel_index == 7) begin
                        state <= S_UPDATE_OUTPUTS;
                    end else begin
                        channel_index <= channel_index + 1;
                        state         <= S_READ_LOW;
                    end
                end

                // ---------------------------------------------------------
                // 7. Update Outputs (Phase Coherency)
                // ---------------------------------------------------------
                S_UPDATE_OUTPUTS: begin
                    loading <= 0;
                    
                    VA  <= temp_data[0]; 
                    VB  <= temp_data[1]; 
                    VC  <= temp_data[2]; 
                    IA  <= temp_data[3]; 
                    IB  <= temp_data[4]; 
                    IC  <= temp_data[5]; 
                    VDC <= temp_data[6]; 
						  GARBAGE <= temp_data[7]; 
                    
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

	 
	 
// ADC info: 
// Coming in: BUSY, FIRST SAMPLE
// Going out: READ, SAMPLE START (CONVST)
// Falling edge of read puts the next channel on the bus (this is from the FPGA - to the ADC)
// Rising edge of SAMPLE START begins the asmpling process in the ADC (CONVST - conversion start is the name in the datasheet). 
// Busy high indicates a conversion is taking place (so don't try to read) 
// first sample indicates that the sample on the bus is from the first of the eight channels


// We want to sample the signals at 720 Hz
// I think our clock is 25 Mhz
// Output CONVST needs to go high at an appropriate rate - which should be easily controllable. 
// Output CONVST needs to go high when we need the ADC to read off another sample. 


// Input busy - if busy is high - don't read onto anything, obviously 
// Also just to be safe if CONVST is high - also don't read onto anything?


// When first data is high, read VA

// Then we need a counter to index, which will sequentially turn on registers


/* NOTES FROM THE DATASHEET:
Busy Output. This pin transitions to a logic high after both CONVST A and CONVST B rising
edges and indicates that the conversion process has started. The BUSY output remains high
until the conversion process for all channels is complete. The falling edge of BUSY signals
that the conversion data is being latched into the output data registers and is available to
read after a Time t4. Any data read while BUSY is high must be completed before the falling
edge of BUSY occurs. Rising edges on CONVST A or CONVST B have no effect while the
BUSY signal is high
WE HAVE TO WAIT FOR BUSY TO BE LOW BEFORE WE ARE READING - FOR SOME REASON WE ARE READING EVEN THOUGH BUSY IS HIGH

ALSO, for some reason we are setting loading == high on the negative edge of CONVST, but loading should be set high on the negative 
edge of BUSY. 

Essentially we have to wait for the adc to complete its conversion, before our fpga can do its loading, but we are not doing that at all. 

Otherwise it seems to work fine. 




*/ 

endmodule
	
	
