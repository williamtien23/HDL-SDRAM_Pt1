`timescale 1ns/1ps
module SDRAM_Controller_TB ();

wire [13 -1 : 0] 	address_bus;
wire [8 -1 : 0]	command_bus;
wire [16 -1 : 0]					data_bus;
reg clk = 0;
reg sdr_clk = 0;
 SDRAM_Controller DUT (clk, address_bus, command_bus, data_bus);

initial	begin
	#1000000
	$stop;
	$finish;
end

always 
#(7.5/2) clk = ~clk;

initial begin
	#(7.5/4)
	forever sdr_clk = #(7.5/2) ~sdr_clk;
end

endmodule 