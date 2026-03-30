module inverter_interface #(
    parameter DEAD_TIME_CYCLES = 125
)(
    input  wire clk,
    input  wire clk_en,
    input  wire reset,
    input  wire pwm_in,
    output reg  gate_h,
    output reg  gate_l
);
    // Registers count dead time
    reg [15:0] count_h, count_l;

    always @(posedge clk) begin
        // High Side Logic with Turn-on Delay
        if (pwm_in == 1'b0) begin
            gate_h <= 1'b0;
            count_h <= 0;
        end else begin
            if (count_h < DEAD_TIME_CYCLES) count_h <= count_h + 1;
            else gate_h <= 1'b1;
        end

        // Low Side Logic with Turn-on Delay
        if (pwm_in == 1'b1) begin
            gate_l <= 1'b0;
            count_l <= 0;
        end else begin
            if (count_l < DEAD_TIME_CYCLES) count_l <= count_l + 1;
            else gate_l <= 1'b1;
        end
    end

endmodule