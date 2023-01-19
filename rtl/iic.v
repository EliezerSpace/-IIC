/*
	Author : Must
	Description : iic controllor
*/
module iic
#
(
	parameter	SYS_CLK 	= 50_000_000,	//the frequency of system clock 
	parameter	IIC_SCL 	= 250_000	,	//the frequency of scl 
	parameter	DEVICE_ADD	= 7'b1010011
)
(
	input			sys_clk			,	//system clock
	input			sys_rst_n		,	//system reset negedge valid
	//---------iic user interface
	input			iic_add_bit		,	//address width 1: 16bits  0: 8bits
	input			iic_wr_en		,	//write enable
	input			iic_rd_en		,	//read enable
	input	[15:0]	iic_word_add	,	//the address of words
	input	[7:0]	iic_wr_data		,	//data to write
	//---------iic hardware interface
	output	reg		scl				,	//serial clock
	inout			sda				,	//serial data
	output	[7:0]	iic_rd_data			//datas from iic device
);
//**************parameter define
parameter	DRI_CLK_MAX = ( SYS_CLK / IIC_SCL ) >> 2;//the frequency of the drive clk is 4 times the scl
parameter	DEVICE_ADD_W = {DEVICE_ADD,1'b0};
parameter	DEVICE_ADD_R = {DEVICE_ADD,1'b1};
//--------state codes
parameter	IDLE         =	4'd0,		//idle 
			W_START      =  4'd1,		//write start
			W_DEV_ADD    =  4'd2,		//write device's address
			W_WORD_ADD_H =  4'd3,		//write the high 8bits address
			W_WORD_ADD_L =  4'd4,		//write the low 8bits address
			W_DATA       =  4'd5,		//write datas
			R_START      =  4'd6,		//read start
			R_DEV_ADD    =  4'd7,		//write device's again
			R_DATA       =  4'd8,		//read datas 
			STOP         =  4'd9;		//stop
//--------state define
reg	[3:0] 	state_cur;
reg [3:0] 	state_next;
//--------iic data input and output define
wire		sda_in;
reg			sda_out;
reg			out_en;
reg	[7:0]	rd_data_tmp;
//--------counter define
reg [7:0] 	cnt_dri;//dri clock counter
reg [1:0]	cnt_dri_cycle;
reg [3:0]	cnt_bit;
//--------flags define
wire	wr_rd_en;		//there is a write of read request
wire	w_dev_add_end;	//write device's address finish
wire	w_add_h_end;	//write high 8bits finish
wire	w_add_l_end;	//write low 8bits finish
wire	w_data_end;		//write datas finish
wire	r_dev_add_end;	//write device's address finish again
wire	r_data_end;
wire	w_start_end;
wire	r_start_end;
reg		wr_flag;		//1 : writing
reg		rd_flag;		//1 : reading
wire	ack;			//the ack signal from iic device
wire	cnt_bit_rst;

assign iic_rd_data = rd_data_tmp;
//**************assignments
assign w_start_end = (state_cur == W_START && cnt_dri_cycle == 3 && cnt_dri == DRI_CLK_MAX - 1'b1);
assign r_start_end = (state_cur == R_START && cnt_dri_cycle == 3 && cnt_dri == DRI_CLK_MAX - 1'b1);
assign wr_rd_en = (state_cur == IDLE && (iic_wr_en || iic_rd_en));
assign w_dev_add_end = (state_cur == W_DEV_ADD && cnt_bit == 8 && cnt_dri_cycle == 2 && ~ack);
assign w_add_h_end = (state_cur == W_WORD_ADD_H && cnt_bit == 8 && cnt_dri_cycle == 2 && ~ack);
assign w_add_l_end = (state_cur == W_WORD_ADD_L && cnt_bit == 8 && cnt_dri_cycle == 2 && ~ack);
assign w_data_end = (state_cur == W_DATA && cnt_bit == 8 && cnt_dri_cycle == 2 && ~ack);
assign r_dev_add_end = (state_cur == R_DEV_ADD && cnt_bit == 8 && cnt_dri_cycle == 2 && ~ack);
assign r_data_end = (state_cur == R_DATA && cnt_bit == 8);
assign cnt_bit_rst = (w_dev_add_end || w_add_h_end || w_add_l_end || w_data_end || r_dev_add_end);
assign ack = (cnt_bit == 8) ? sda_in : 1'b1;

always@(posedge sys_clk or negedge sys_rst_n)begin
	if(~sys_rst_n)begin
		wr_flag = 1'b0;
		rd_flag = 1'b0;
	end
	else begin
		if(state_cur == IDLE)begin
			wr_flag = iic_wr_en;
			rd_flag = iic_rd_en;
		end
		else if(state_cur == STOP)begin
			wr_flag = 1'b0;
			rd_flag = 1'b0;
		end
		else begin
			wr_flag = wr_flag;
			rd_flag = rd_flag;
		end
	end
end
//--------iic data assignment
assign sda_in = sda;
assign sda = out_en ? sda_out : 1'bz;
//**************counter
always@(posedge sys_clk or negedge sys_rst_n)begin
	if(~sys_rst_n)begin
		cnt_dri <= 8'd0;
	end
	else begin
		if(cnt_dri == DRI_CLK_MAX - 1'b1)begin
			cnt_dri <= 8'd0;
		end
		else begin
			cnt_dri <= cnt_dri + 1'b1;
		end
	end
end
always@(posedge sys_clk or negedge sys_rst_n)begin
	if(~sys_rst_n)begin
		cnt_dri_cycle <= 2'b0;
	end
	else begin
		if(state_cur == IDLE)
			cnt_dri_cycle <= 2'b0;
		else begin
			if(cnt_dri == DRI_CLK_MAX - 1'b1)
				cnt_dri_cycle <= cnt_dri_cycle + 1'b1;
			else if(cnt_bit_rst)
				cnt_dri_cycle <= 2'b0;
			else
				cnt_dri_cycle <= cnt_dri_cycle;
		end
	end
end
always@(posedge sys_clk or negedge sys_rst_n)begin
	if(~sys_rst_n)begin
		cnt_bit <= 4'd0;
	end	
	else begin
		case(state_cur)
			IDLE			,
			W_START			,
			R_START			,
			STOP:
			begin
				cnt_bit <= 4'd0;    
			end
			W_DEV_ADD    	,
			W_WORD_ADD_H 	,
			W_WORD_ADD_L 	,
			W_DATA       	,
			R_DEV_ADD    	,
			R_DATA       	:
			begin
				if(cnt_dri_cycle == 2'd3 && cnt_dri == DRI_CLK_MAX - 1'b1)
					cnt_bit <= cnt_bit + 1'b1;
				else if(cnt_bit_rst)
					cnt_bit <= 4'd0;
			end
		endcase
	end
end
//**************three stages state machine
//--------the first stage
always@(posedge sys_clk or negedge sys_rst_n)begin
	if(~sys_rst_n)
		state_cur <= IDLE;
	else
		state_cur <= state_next;
end
//--------the second stage
always@(*)begin
	case(state_cur)
		IDLE         :	state_next = wr_rd_en ? W_START : IDLE;
		W_START      :	state_next = w_start_end ? W_DEV_ADD : W_START;
		W_DEV_ADD    :	begin
			if(w_dev_add_end)begin
				if(iic_add_bit)
					state_next = W_WORD_ADD_H;
				else
					state_next = W_WORD_ADD_L;
			end
			else begin
				state_next = W_DEV_ADD;
			end
		end
		W_WORD_ADD_H :	state_next = w_add_h_end ? W_WORD_ADD_L : W_WORD_ADD_H;
		W_WORD_ADD_L :	begin
			if(w_add_l_end)begin
				if(wr_flag)begin
					state_next = W_DATA;
				end
				else if(rd_flag)begin
					state_next = R_START;
				end
				else begin
					state_next = state_next;
				end
			end
			else begin
				state_next = W_WORD_ADD_L;
			end
		end
		W_DATA       :	state_next = w_data_end ? STOP : W_DATA;
		R_START      :	state_next = r_start_end ? R_DEV_ADD : R_START;
		R_DEV_ADD    :	state_next = r_dev_add_end ? R_DATA : R_DEV_ADD;
		R_DATA       :	state_next = r_data_end ? STOP : R_DATA;
		STOP         :	state_next = IDLE;
		default      :	state_next = IDLE;
	endcase
end
//--------the third stage
always@(*)begin
	case(state_cur)
		IDLE 		:begin
			sda_out = 1;
		end		
		W_START     :begin
			case(cnt_dri_cycle)
				2'd0	:	sda_out = 1;
				2'd1	:	sda_out = 1;
				2'd2	:	sda_out = 0;
				2'd3	:	sda_out = 0;
				default	:;
			endcase
		end		
		W_DEV_ADD   :begin
			sda_out = DEVICE_ADD_W[7-cnt_bit];
		end		 
		W_WORD_ADD_H:begin
			sda_out = iic_word_add[15-cnt_bit];
		end		 
		W_WORD_ADD_L:begin
			sda_out = iic_word_add[7-cnt_bit];
		end		 
		W_DATA      :begin
			sda_out = iic_wr_data[7-cnt_bit];
		end		 
		R_START     :begin
			case(cnt_dri_cycle)
				2'd0	:	sda_out = 1;
				2'd1	:	sda_out = 1;
				2'd2	:	sda_out = 0;
				2'd3	:	sda_out = 0;
				default	:;
			endcase
		end		 
		R_DEV_ADD   :begin
			sda_out = DEVICE_ADD_R[7-cnt_bit];
		end		 
		R_DATA      :begin
			if(cnt_dri_cycle == 2'd1)
				rd_data_tmp[7-cnt_bit] = sda_in;
			else
				rd_data_tmp = rd_data_tmp;
		end		 
		STOP        :begin
			case(cnt_dri_cycle)
				2'd0	:	sda_out = 0;
				2'd1	:	sda_out = 0;
				2'd2	:	sda_out = 1;
				2'd3	:	sda_out = 1;
				default	:;
			endcase
		end		
		default		:;
	endcase
end
always@(*)begin
	case(state_cur)
		IDLE 		:begin
			case(cnt_dri_cycle)
				2'd0	:	scl = 0;
				2'd1	:	scl = 0;
				2'd2	:	scl = 0;
				2'd3	:	scl = 0;
				default	:;
			endcase
		end		
		W_START     :begin
			case(cnt_dri_cycle)
				2'd0	:	scl = 1;
				2'd1	:	scl = 1;
				2'd2	:	scl = 1;
				2'd3	:	scl = 0;
				default	:;
			endcase
		end		
		W_DEV_ADD   :begin
			case(cnt_dri_cycle)
				2'd0	:	scl = 0;
				2'd1	:	scl = 1;
				2'd2	:	scl = 1;
				2'd3	:	scl = 0;
				default	:;
			endcase
		end		 
		W_WORD_ADD_H:begin
			case(cnt_dri_cycle)
				2'd0	:	scl = 0;
				2'd1	:	scl = 1;
				2'd2	:	scl = 1;
				2'd3	:	scl = 0;
				default	:;
			endcase
		end		 
		W_WORD_ADD_L:begin
			case(cnt_dri_cycle)
				2'd0	:	scl = 0;
				2'd1	:	scl = 1;
				2'd2	:	scl = 1;
				2'd3	:	scl = 0;
				default	:;
			endcase
		end		 
		W_DATA      :begin
			case(cnt_dri_cycle)
				2'd0	:	scl = 0;
				2'd1	:	scl = 1;
				2'd2	:	scl = 1;
				2'd3	:	scl = 0;
				default	:;
			endcase
		end		 
		R_START     :begin
			case(cnt_dri_cycle)
				2'd0	:	scl = 0;
				2'd1	:	scl = 1;
				2'd2	:	scl = 1;
				2'd3	:	scl = 0;
				default	:;
			endcase
		end		 
		R_DEV_ADD   :begin
			case(cnt_dri_cycle)
				2'd0	:	scl = 0;
				2'd1	:	scl = 1;
				2'd2	:	scl = 1;
				2'd3	:	scl = 0;
				default	:;
			endcase
		end		 
		R_DATA      :begin
			case(cnt_dri_cycle)
				2'd0	:	scl = 0;
				2'd1	:	scl = 1;
				2'd2	:	scl = 1;
				2'd3	:	scl = 0;
				default	:;
			endcase
		end		 
		STOP        :begin
			case(cnt_dri_cycle)
				2'd0	:	scl = 0;
				2'd1	:	scl = 1;
				2'd2	:	scl = 1;
				2'd3	:	scl = 1;
				default	:;
			endcase
		end		
		default		:begin

		end		
	endcase
end	
always@(*)begin
	out_en = 1'b0;
	case(state_cur)
		IDLE			,         
		W_START 		,     
	    W_DEV_ADD 		,   
	    W_WORD_ADD_H 	,
	    W_WORD_ADD_L 	,
	    W_DATA       	,
	    R_START     	,
	    R_DEV_ADD    	:begin
			if(cnt_bit == 8)
				out_en = 1'b0;
			else
				out_en = 1'b1;
		end
	    R_DATA:out_en = 1'b0;		
	    STOP:out_en = 1'b1;	
	endcase
end
endmodule