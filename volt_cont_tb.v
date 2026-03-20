module volt_cont_tb;

    reg clk;
    reg reset;
    
    // 720 Hz Clock Enable signals
    reg clk_en;
    integer clk_en_counter;
    
    // Interconnects
    reg signed [15:0] adc_in_a;
    wire [15:0] tracked_amplitude;
    wire signed [15:0] nco_v_output; // This is our V_scale!

    // Inverter Control Signals
    wire u_h, u_l, v_h, v_l, w_h, w_l;
    
    // FCW Constants for 25MHz Clock
    // 60Hz: (60 * 2^32) / 25,000,000 = 10308
    // 5kHz Carrier: (5000 * 2^32) / 25,000,000 = 858993
    localparam [31:0] FCW_60HZ = 32'd10308;
    localparam [31:0] FCW_5KHZ = FCW_60HZ*75;

    reg [15:0] rom_phase_a [0:2047];
    integer sample_idx;

    // 1. Amplitude Finder (Tracks incoming grid)
    amplitude_finder u_amp_finder (
        .clk(clk), .reset(reset), .adc_in(adc_in_a), .amplitude(tracked_amplitude)
    );

    // 2. Voltage Control Filter (The PI Loop)
    volt_control_filt u_volt_ctrl (
        .clk(clk), .reset(reset), .clk_en(clk_en),
        .V_input(tracked_amplitude),
        .V_output(nco_v_output)
    );

    // 3. Inverter Top (The Power Stage)
    inverter_top_new #(.WORD_SIZE(18), .ACC_WIDTH(32)) u_inverter (
        .clk(clk), .clk_en(1'b1), .reset(reset),
        .freq_in(FCW_60HZ),
        .carrier_fcw(FCW_5KHZ),
        .d_in(18'd0), .q_in(18'd0),
        .V_scale(nco_v_output), // PI Filter controls inverter amplitude
        .u_high(u_h), .u_low(u_l),
        .v_high(v_h), .v_low(v_l),
        .w_high(w_h), .w_low(w_l)
    );

    // Clock Gen (25MHz)
    initial begin clk = 0; forever #20 clk = ~clk; end

    // 720Hz Strobe and ROM Reader
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_en_counter <= 0; clk_en <= 0; sample_idx <= 0; adc_in_a <= 0;
        end else begin
            if (clk_en_counter >= 34721) begin
                clk_en_counter <= 0;
                clk_en <= 1;
                adc_in_a <= rom_phase_a[sample_idx];
                sample_idx <= (sample_idx == 2047) ? 0 : sample_idx + 1;
            end else begin
                clk_en_counter <= clk_en_counter + 1;
                clk_en <= 0;
            end
        end
    end

    initial begin
        $readmemh("phase_a_zero.hex", rom_phase_a);
        reset = 1; #100; reset = 0;
        $display("Simulation Started: Closing loop between PI Filter and Inverter SPWM.");
        #2850000000; // 2.85s
        $stop;
    end
endmodule