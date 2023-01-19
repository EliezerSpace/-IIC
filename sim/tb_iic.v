`timescale 1ns/1ns

module tb_iic;

reg		sys_clk		;
reg 	sys_rst_n	;
reg 	iic_wr_en 	;
reg 	iic_rd_en 	;

wire	scl;
wire	sda;
initial begin
	iic_wr_en = 1'b0;
    iic_rd_en = 1'b0;
	sys_clk = 0;
	sys_rst_n = 0;
	#100
	sys_rst_n = 1;
	#1000
	iic_wr_en = 1'b1;
	#20
	iic_wr_en = 1'b0;
	#200000
	iic_rd_en = 1'b1;
	#20
	iic_rd_en = 1'b0;
end
always#10 sys_clk = ~sys_clk;


iic
#
(
	.SYS_CLK 	(50_000_000	),	//the frequency of system clock 
	.IIC_SCL 	(250_000	),	//the frequency of scl 
	.DEVICE_ADD	(7'b1010011	)
)
iic_inst
(
	.sys_clk			(sys_clk	),				//system clock
	.sys_rst_n			(sys_rst_n	),				//system reset negedge valid
	//---------iic user interface
	.iic_add_bit		(1'b1),			//address width 1: 16bits  0: 8bits
	.iic_wr_en			(iic_wr_en),	//write enable
	.iic_rd_en			(iic_rd_en),	//read enable
	.iic_word_add		(16'd0),		//the address of words
	.iic_wr_data		(8'h55),		//data to write
	//---------iic hardware interface
	.scl				(scl),		//serial clock
	.sda				(sda),		//serial data
	.iic_rd_data		()	//datas from iic device
);
M24LC64 	M24LC64_inst(
	.A0			(1'b1), 
	.A1			(1'b1), 
	.A2			(1'b0), 
	.WP			(1'b0), 
	.SDA		(sda), 
	.SCL		(scl), 
	.RESET   	(~sys_rst_n)
);
endmodule