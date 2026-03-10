module adc_reader_tb;
// -- Plan --
// Essentially this needs to simulate the ADC, so it needs to: 
// Go busy for the correct amount of time after a CONVST was sent. 
// Switch DATA OUT to the next channel when read is low
// Have the channels have data on them (right now it can just be Va = 1, Vb = 2...) 
// Send a FRST_DATA signal out after its done the conversion
// Also we have a clock that should be 25 M in here
// Also we have a reset just to test that
    // ------------------------------------------
    // 1. Signal Declarations
    // ------------------------------------------
    reg clk;
    reg reset;
    
    // Inputs to the DUT (Outputs from the ADC Emulator)
    reg BUSY;
    reg FRSTDATA;
    reg signed [15:0] DATA_IN;
    
    // Outputs from the DUT (Inputs to the ADC Emulator)
    wire RD;
    wire CONVST;
    wire signed [15:0] VA, VB, VC, IA, IB, IC, VDC;
    wire loading;

    // Timing Constants
    localparam PERIOD = 40;       // 40ns = 25 MHz clock
    localparam T_CONV = 4000;     // 4us conversion time for AD7606 
    localparam T_BUSY_DELAY = 45; // Max delay from CONVST rising to BUSY high [cite: 603]

    // ------------------------------------------
    // 2. Clock and Reset Generation
    // ------------------------------------------
    initial begin
        clk = 0;
        forever #(PERIOD/2) clk = ~clk;
    end

    initial begin
        reset = 1;               // Active High Reset
        BUSY = 0;
        FRSTDATA = 0;
        DATA_IN = 0;
        
        #(PERIOD * 5);           // Hold reset for 5 cycles (200ns)
        reset = 0;
        
        // Let simulation run for 2 sample cycles (~3ms)
        // 720 Hz sample rate = 1.38ms per sample
        #(3000000); 
        $display("Simulation Finished.");
        $stop;
    end

    // ------------------------------------------
    // 3. Device Under Test (DUT) Instantiation
    // ------------------------------------------
    adc_reader test_inst (
        .clk(clk),
        .reset(reset),
        
        // AD7606 Hardware Signals
        .BUSY(BUSY),
        .FRSTDATA(FRSTDATA),
        .DATA_IN(DATA_IN),
        
        // ADC Control Signals
        .RD(RD),
        .CONVST(CONVST),
        
        // Processed Outputs
        .VA(VA), .VB(VB), .VC(VC),
        .IA(IA), .IB(IB), .IC(IC),
        .VDC(VDC),
        .loading(loading)
    );

    // ------------------------------------------
    // 4. ADC Emulator Logic
    // ------------------------------------------
    reg [15:0] mock_adc_data [0:7];
    integer read_ptr = 0;

    initial begin
        // Define some recognizable test values
        mock_adc_data[0] = 16'h1111; // VA
        mock_adc_data[1] = 16'h2222; // VB
        mock_adc_data[2] = 16'h3333; // VC
        mock_adc_data[3] = 16'h4444; // IA
        mock_adc_data[4] = 16'h5555; // IB
        mock_adc_data[5] = 16'h6666; // IC
        mock_adc_data[6] = 16'h7777; // VDC
        mock_adc_data[7] = 16'h0000; // Unused
    end

    // Simulation of Conversion Start -> BUSY
    always @(posedge CONVST) begin
        #(T_BUSY_DELAY); 
        BUSY = 1;
        #(T_CONV); 
        BUSY = 0;
        read_ptr = 0; // Reset read pointer after conversion completes
    end

    // Simulation of Data Output and FRSTDATA based on RD signal [cite: 95, 98, 99]
    always @(negedge RD) begin
        if (read_ptr < 8) begin
            DATA_IN <= mock_adc_data[read_ptr];
            
            // FRSTDATA goes high when V1 (index 0) is on the bus [cite: 95]
            // and returns low on the next RD falling edge [cite: 99]
            if (read_ptr == 0) 
                FRSTDATA <= 1;
            else 
                FRSTDATA <= 0;
                
            read_ptr <= read_ptr + 1;
        end
    end

	 
	 
	 
	 /*
	 some specifics:
	 time between positive edge (from low pulse) of CONVST and positive edge of busy (from low) = t1 = 40 ns
	 typical time of conversion (until busy goes low) = tCONV = idk there's like a hundred diff ones - I think it's like 3.45 us
	 We are reading during conversions right now, but I feel that's dangerous and stupid, we should just read after a conversion as we
	 are reading from it so slowly.
	 */
endmodule

	
	
