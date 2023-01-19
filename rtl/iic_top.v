module iic_top(
	input			sys_clk		,
    input			sys_rst_n	,
                                
	output			scl	        ,
	inout			sda	,
	output	[7:0]	iic_rd_data
);

reg   			iic_add_bit		= 1'b1;
reg   			iic_wr_en		= 1'b0;
reg   			iic_rd_en		= 1'b1;
reg   [15:0]	iic_word_add	= 16'd0;
reg   [7:0]		iic_wr_data		= 8'hf0;


iic
#
(
	.SYS_CLK 	(50_000_000	),	//the frequency of system clock 
	.IIC_SCL 	(250_000	),	//the frequency of scl 
	.DEVICE_ADD	(7'b1010011 )
)
iic_inst
(
	.sys_clk			(sys_clk),	//system clock
	.sys_rst_n			(sys_rst_n),	//system reset negedge valid
	//---------iic user interface
	.iic_add_bit		(iic_add_bit	),	//address width 1: 16bits  0: 8bits
	.iic_wr_en			(iic_wr_en		),	//write enable
	.iic_rd_en			(iic_rd_en		),	//read enable
	.iic_word_add		(iic_word_add	),	//the address of words
	.iic_wr_data		(iic_wr_data	),	//data to write
	//---------iic hardware interface
	.scl				(scl),	//serial clock
	.sda				(sda),	//serial data
	.iic_rd_data		(iic_rd_data)	//datas from iic device
);
endmodule