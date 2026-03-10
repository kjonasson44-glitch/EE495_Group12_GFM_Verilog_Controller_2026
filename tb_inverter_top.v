`timescale 1ns/1ps

module tb_inverter_top();

    // Parameters based on reference designs
    parameter WORD_SIZE = 18;
    parameter ACC_WIDTH = 32;
    parameter CLK_PERIOD = 10; // 100MHz clock

    // Testbench Signals
    reg CLOCK_50;
    reg clk;
    reg clk_en;
    reg reset;
    reg [ACC_WIDTH-1:0] freq_in;
    reg [ACC_WIDTH-1:0] carrier_fcw;
    reg signed [WORD_SIZE-1:0] q_in, d_in;

    // Gate drive outputs 
    wire u_high, u_low;
    wire v_high, v_low;
    wire w_high, w_low;


    integer timer_cnt;
    // 50 MHz Master Clock (20ns period)
    initial CLOCK_50 = 0;
    always #10 CLOCK_50 = ~CLOCK_50;

    // Logic for the 25 MHz derived clock
    initial clk = 0;
    always @(posedge CLOCK_50) begin
        clk <= ~clk;
    end

    // clk_en trigger logic matching the hardware implementation
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            timer_cnt <= 0;
            clk_en <= 1'b0;
        end else begin
            if (timer_cnt >= 34721) begin
                timer_cnt <= 0;
                clk_en <= 1'b1;
            end else begin
                timer_cnt <= timer_cnt + 1;
                clk_en <= 1'b0;
            end
        end
    end

    // Instantiate the Top Level Inverter Module
    inverter_top #(
        .WORD_SIZE(WORD_SIZE),
        .ACC_WIDTH(ACC_WIDTH)
    ) uut (
        .clk(clk),
        .clk_en(clk_en),
        .reset(reset),
        .freq_in(freq_in),
        .carrier_fcw(carrier_fcw),
        .d_in(d_in),
        .q_in(q_in),
        .u_high(u_high),
        .u_low(u_low),
        .v_high(v_high),
        .v_low(v_low),
        .w_high(w_high),
        .w_low(w_low)
    );

    // Clock Generation logic
    /*initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    */

    // Stimulus and Initialization
    initial begin
        clk_en = 0;
        reset = 1;
        d_in = 18'sd32767;
        q_in = 18'sd0;
        freq_in = 32'd200000;//32'd357913941;//32'd200000; //32'd357913941;
        
        // Note: This literal (29.8e9) exceeds 32 bits and will be truncated by the simulator
        carrier_fcw = 32'hA00000; //32'h10000000;//32'sd2147483647;//32'd29826161750;
        
        // Wait for system to stabilize during reset
        repeat(1000) @(posedge clk);
        reset = 0;
        
        repeat(5) @(posedge clk);
        clk_en = 1;

        $display("Simulation Started: Testing Inverter Top with Dead-Time.");
        
        // Run simulation for a sufficient window to see modulation
        // and dead-time behavior (e.g., 1ms)
        #100000000;
        #100000000;

        $display("Simulation Finished.");
        $stop; 
    end

endmodule