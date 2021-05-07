//PC133

module SDRAM_Controller #(parameter Settings = 1)(
	sdr_clk,
	address_bus,
	command_bus,
	data_bus
);

generate
if (Settings == 1) begin
`define PC133
end
//else
endgenerate


`ifdef PC133
localparam CMD_BITS 			= 			6;
localparam ADDR_BITS			=			13;
localparam BA_BITS			=			2;
localparam DQ_BITS			=			16;
localparam DQM_BITS			=			2;
localparam INIT_DELAY		=			13334; //100us*clk/7.5ns = 13334 clk cyle delays @ 133MHz (2^14 bit counter)

localparam T_RP				=			2; 	//Calculate Delay - 1 (Issue Cycle)
localparam T_RC				=			8;
localparam T_MRD				=			2;
localparam REFRESH			=			1;
`endif
	
input wire sdr_clk; 
output wire [ADDR_BITS+BA_BITS -1 : 0] address_bus; 
output wire [CMD_BITS+DQM_BITS -1 : 0] command_bus; 
output wire [DQ_BITS -1 : 0] data_bus;
	
//=======================================================
//  SDRAM Internal Declarations
//		-Address
//		-Command
//		-Data
//=======================================================
reg [ADDR_BITS -1 : 0] 	addr;
reg [BA_BITS -1 : 0]		bank;

reg			cke;		//clock enable
reg			cs_n;		//chip select active low
reg			cas_n;	//column access strobe active low
reg			ras_n;	//row access strobe active low
reg			we_n;		//write enable active low
reg [1:0]	dqm;		//data mask

reg [DQ_BITS -1 : 0]	data;	

assign address_bus = {addr,bank};
assign command_bus = {cke, cs_n, cas_n, ras_n, we_n, dqm[1:0]};
assign data_bus 	= data;

//=======================================================
//  States
//=======================================================
localparam power_on	 			=	8'd0;
localparam init_delay 			=	8'd1;
localparam init_precharge 		= 	8'd2; 
localparam init_auto_refresh 	=	8'd3;
localparam init_load_reg 		=	8'd4;
localparam idle 					=	8'd5;


//=======================================================
//  Internal Registers
//=======================================================
reg state_machine_en = 1;						
reg [31:0] delay_reg = 0;
reg [7:0] auto_refresh_counter = 0;

reg [31:0] counter = 0;							//FSM Delay Generator Counter
reg [7:0] current_state = power_on;					//FSM States
reg [7:0] next_state = init_delay;

initial 
	$timeformat (-9, 1, " ns", 12);

//=======================================================
//  State Machine Delay Generator
//=======================================================
always @ (posedge sdr_clk) begin

	if(state_machine_en == 0)begin
		nop;
		if ((delay_reg - counter) == 0) //Like SLT OP
			state_machine_en <= 1;
		else
			counter <= counter+1;
	end
	
	else begin
		counter <= 1;
	end
	
end	

//==================================
// State Machine Present State Logic
always @ (posedge sdr_clk) begin
	if (state_machine_en == 1) begin
		current_state <= next_state;
	end
end



//==================================
// State Machine Control
//
always @ (*) begin

	case(current_state)
		power_on:
		begin
			next_state = init_delay;
		end	
		init_delay:
		begin
			next_state = init_precharge;
		end
		
		init_precharge:	
		begin
			next_state = init_auto_refresh;
		end
		
		init_auto_refresh:
		begin
			if (auto_refresh_counter == 8) next_state = init_load_reg;
			else next_state = init_auto_refresh;
		end
		
		init_load_reg:
		begin
			next_state = idle;
		end
		
		default:
		begin
			next_state = idle;
		end

	endcase
end

//==================================
// State Machine
always @ (posedge sdr_clk) begin
	if(state_machine_en == 1)begin
		case (next_state)
		
			//==================================
			// Init Routine - 100us delay
			init_delay:
			begin
				$display ("%m : at time %t Power On", $time);
				delay_reg <= INIT_DELAY;
				state_machine_en <= 0;
			end		
			
			//==================================
			// Init Routine - Precharge all
			init_precharge:	
			begin
				$display ("%m : at time %t Precharge", $time);	
				precharge_all_bank;
				delay_reg <= T_RP;
				state_machine_en <= 0;
			end
			
			//==================================
			// Init Routine - Auto Refresh x8
			init_auto_refresh: 
			begin
			$display ("%m : at time %t Auto Refresh N: %d", $time, auto_refresh_counter);
				auto_refresh;
				delay_reg <= T_RC;
				state_machine_en <= 0;
				auto_refresh_counter <= auto_refresh_counter+1;
			end
			
			//==================================
			// Loading Mode Register
			init_load_reg: 
			begin
				$display ("%m : at time %t Load", $time);
				load_mode_reg(50);
				delay_reg <= T_MRD;
				state_machine_en <= 0;
			end
			
			default:
			begin
				nop;
			end

		endcase
	end
end


//=======================================================
//  Tasks
//=======================================================

task nop;
	begin
		//data
		data 	= {DQ_BITS{1'bz}};
		//address
		addr	= {ADDR_BITS{1'bx}};
		bank	= {BA_BITS{1'bx}};
		//control
		cke 	= 1;
		cs_n 	= 0;
		ras_n	= 1;
		cas_n	= 1;
		we_n	= 1;
		dqm	= 2'b0;
	end
endtask
 
task precharge_all_bank;
	begin
		//data
		data	 = {DQ_BITS{1'bz}};
		//address
		addr	= {ADDR_BITS{1'bx}} | 1024;
		bank	= {BA_BITS{1'bx}};
		//control		
		cke 	= 1;
		cs_n 	= 0;
		ras_n	= 0;
		cas_n	= 1;
		we_n	= 0;
		dqm	= 0;	
    end
endtask

task auto_refresh;
    begin
		//data
		data	= {DQ_BITS{1'bz}};
		//address
		addr	= {ADDR_BITS{1'bx}};
		bank	= {BA_BITS{1'bx}};
		//control		
		cke 	= 1;
		cs_n 	= 0;
		ras_n	= 0;
		cas_n	= 0;
		we_n	= 1;
		dqm	= 0;
    end
endtask
	 
task load_mode_reg;
	input [ADDR_BITS - 1 : 0] op_code;
	begin
		//data
		data 	= {DQ_BITS{1'bz}};
		//address
		addr	= op_code;
		bank	= 0;
		//control		
		cke 	= 1;
		cs_n 	= 0;
		ras_n	= 0;
		cas_n	= 0;
		we_n	= 0;
		dqm	= 0;
    end
endtask


endmodule

