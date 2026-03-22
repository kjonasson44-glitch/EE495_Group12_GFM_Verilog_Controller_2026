module srf_pll_tb;

    // =========================================================================
    // SIGNALS
    // =========================================================================
    reg clk;
    reg reset;
    reg clk_en;
    reg signed [17:0] q_in;
    wire signed [31:0] freq_out;

    // =========================================================================
    // UNIT UNDER TEST (UUT)
    // =========================================================================
    srf_pll_1 uut (
        .clk(clk),
        .reset(reset),
        .clk_en(clk_en),
        .q_in(q_in),
        .freq_out(freq_out)
    );

    // =========================================================================
    // CLOCK GENERATION (25 MHz)
    // =========================================================================
    // 25 MHz = 40 ns period (20 ns high, 20 ns low)
    initial clk = 0;
    always #20 clk = ~clk;

    // =========================================================================
    // STROBE GENERATION (720 Hz)
    // =========================================================================
    // 25 MHz / 720 Hz = ~34722.22 clock cycles.
    // We will pulse clk_en high for 1 clock cycle every 34,722 cycles.
    integer clk_count = 0;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_count <= 0;
            clk_en <= 0;
        end else begin
            if (clk_count == 34721) begin
                clk_count <= 0;
                clk_en <= 1'b1;
            end else begin
                clk_count <= clk_count + 1;
                clk_en <= 1'b0;
            end
        end
    end

    // =========================================================================
    // STIMULUS
    // =========================================================================
    initial begin
        // 1. Initialization
        $display("Starting SRF PLL Simulation...");
        reset = 1'b1; // Driving HIGH based on `if(reset)` in your module
        q_in  = 18'sd0;
        
        // Hold reset for a few clock cycles
        #100;
        reset = 1'b0;
        $display("[%0t ns] Reset released.", $time);
        
        // 2. Run at zero-input to show stability
        // Wait ~3 strobe cycles. 1 strobe cycle = ~1.388 ms = 1,388,888 ns.
        #5000000; 
        
        // 3. Apply 0.25 Full Scale Step Input
        // 18-bit signed range is -131072 to +131071. 25% of FS is ~32768.
        $display("[%0t ns] Applying 0.25 FS step (32768) to q_in...", $time);
        q_in = 18'sd32768; 
        
        // 4. Wait and observe PI controller response
        // Let it run for 50 milliseconds to watch the integrator wind up.
        // 50ms = 50,000,000 ns.
        #50000000;
        
        // 5. Apply negative step to see it recover
        $display("[%0t ns] Applying negative step (-32768) to q_in...", $time);
        q_in = -18'sd32768;
        
        #50000000;

        $display("[%0t ns] Simulation finished.", $time);
        $stop; // Pauses ModelSim so you can inspect the waveform
    end

endmodule