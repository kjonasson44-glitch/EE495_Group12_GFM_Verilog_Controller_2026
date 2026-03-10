module sine_rom #(
	parameter WORD_SIZE = 18,
	parameter ADDR_SIZE = 10
)(
	input  wire clk,
	input  wire [ADDR_SIZE-1:0] addr_a,
	input  wire [ADDR_SIZE-1:0] addr_b,
	output reg  [WORD_SIZE-1:0] data_a,
	output reg  [WORD_SIZE-1:0] data_b
);

// Memory array of 1024 (2^10) words, 18 bit word size
reg [WORD_SIZE-1:0] rom [1023:0];

// Load first quadrant data from hex file
initial
	$readmemh("sine_quadrant.hex", rom);

always @(posedge clk) begin
	data_a <= rom[addr_a];
	data_b <= rom[addr_b];
end

endmodule