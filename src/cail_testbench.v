`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/12 14:14:51
// Design Name: 
// Module Name: cail_testbench
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
 
`timescale 1ns / 1ps
module cail_testbench;
 
	reg  clk 	  = 0; 
	reg  rst_n 	  = 0; 
	wire clk_300m; 
	wire clk_100m; 
	wire locked; 
 
	initial begin
		rst_n = 0;
		#100;
		rst_n = 1;
	end
	
	always #5 clk = ~clk;
 
//   clk_wiz_1 instance_name
//    (
//     // Clock out ports
//     .clk_out1                         (clk_100m                                   ), // output clk_out1
//     .clk_out2                         (clk_300m                                   ), // output clk_out2
//     // Status and control signals
//     .reset                            (!rst_n                                     ), // input reset
//     .locked                           (                                           ), // output locked
//    // Clock in ports
//     .clk_in1                          (clk                                    	  ) // input clk_in1
// 	);
	
 
	globalclk_clk300m u_globalclk_clk300m(
	// Clock out ports
		.clk_300m_g(clk_300m), // output clk_300_g
		.clk_100m_g(clk_100m), // output clk_100_g
	// Status and control signals
		.reset     (1'b0    ), // input reset
		.locked    (locked  ), // output locked
	// Clock in ports
		.global_clk(clk     )  // input global_clk
	);

	reg [47:0] m_dds_tdata_r;
	reg [31:0] m_dds_tdata_cunt;
	reg 	   m_dds_tdata_valid;


	localparam FFT_LEN = 512;
	reg locrstn,locrstn_buf; 

	always@(posedge clk_300m or negedge locrstn) begin
		if(locrstn==1'b0) begin
			m_dds_tdata_cunt  <= 'd0;
			m_dds_tdata_r     <= 'd0;
			m_dds_tdata_valid <= 'd0;
		end
		else if(m_dds_tdata_cunt == 'd2) begin
			m_dds_tdata_cunt  <= 'd0;
			m_dds_tdata_r     <= m_dds_tdata;
			m_dds_tdata_valid <= 'd1;  			                
		end
		else begin
			m_dds_tdata_cunt  <= m_dds_tdata_cunt + 'd1;
			m_dds_tdata_r     <= m_dds_tdata_r;
			m_dds_tdata_valid <= 'd0;
		end
	end
	
	
	//=================================================================================/
	// fifo
	//=================================================================================/
	wire                              fifo_rd_en; 
	wire                       [47:0] fifo_dout; 
	wire                              fifo_full; 
	wire                              fifo_empty; 
	wire                              fifo_valid; 
	wire                              fifo_wr_rst_busy; 
	wire                              fifo_rd_rst_busy;
	(*mark_debug = "true"*)reg [15:0] fifo_read_cunt; 
	reg                        [15:0] data_cunt;
	wire                       [10:0] wr_data_count;
	//=================================================================================/
	// FFT
	//=================================================================================/
	reg                        [15:0] tlast_cnt; 
	wire                              fft_tlast_path; 
	wire                       [47:0] fft_data_tdata; 
	wire                              fft_tvalid_path; 
	wire                              fft_tready_path; 
	wire                       	      m_axis_data_tvalid; 
	wire                       [47:0] m_dds_tdata; 
	//=================================================================================/
	// 状态机
	//=================================================================================/
	reg                         [2:0] fifo_read_state;
	reg                         [2:0] fifo_next__state;
	
	localparam FIFO_READ_IDLE = 'd0;
	localparam FIFO_READ_WAIT = 'd1;
	localparam FIFO_READ      = 'd2;
	localparam FIFO_READ_DONE = 'd3;
	
	always@(posedge clk_300m or negedge locked) begin
		if(locked == 1'b0)begin
			locrstn_buf <= 1'b0;
			locrstn	    <= 1'b0;
		end else begin
			locrstn_buf	<= 1'b1;
			locrstn		<= locrstn_buf;
		end
	end
 
//=================================================================================/
// 状态机 控制FIFO数据流
//=================================================================================/
	always @(posedge clk_300m or posedge locrstn) begin
		if( locrstn == 1'b0) begin
			fifo_read_state <= FIFO_READ_IDLE;
		end else begin
			fifo_read_state <= fifo_next__state;
		end
	end

    always @(*) begin
        // always @(posedge clk_300m or posedge locrstn) begin
        case (fifo_read_state)
            FIFO_READ_IDLE: fifo_next__state = FIFO_READ_WAIT;
            FIFO_READ_WAIT: fifo_next__state = (wr_data_count >= 1500) && (data_cunt <= 5) ? FIFO_READ : FIFO_READ_WAIT; //仿真时连续6次输入数据
        	// FIFO_READ_WAIT: fifo_next__state = ((fft_tready_path==1'b1)&&(wr_data_count>1100)) ? FIFO_READ : FIFO_READ_WAIT;
            FIFO_READ:      fifo_next__state = fft_tlast_path ? FIFO_READ_DONE : FIFO_READ;
        	// FIFO_READ:      fifo_next__state = (fifo_read_cunt==FFT_LEN) ? FIFO_READ_DONE : FIFO_READ;
            FIFO_READ_DONE: fifo_next__state = FIFO_READ_IDLE;
            default:        fifo_next__state = FIFO_READ_IDLE;
        endcase
    end
 
	always@(posedge clk_300m or negedge locrstn) begin
		if(locrstn == 1'b0) begin
			data_cunt <= 'd0;
		end else if(data_cunt == 30) begin
			data_cunt <= data_cunt;       			                
		end else if(fft_tlast_path) begin
			data_cunt <= data_cunt + 1'b1; 
		end else begin
			data_cunt <= data_cunt;
		end
	end
//=================================================================================/
//----------------------------------------FIFO模块---------------------------------
//=================================================================================/
	fifo_ddc2fft_48bit u_fifo_ddc2fft_48bit (
		.wr_clk       (clk_300m         ), // input wire wr_clk
		.rd_clk       (clk_300m         ), // input wire rd_clk	
		.din          (m_dds_tdata_r    ), // input wire [47 : 0] din
		.wr_en        (m_dds_tdata_valid), // input wire wr_en
		.rd_en        (fifo_rd_en       ), // input wire rd_en
		.dout         (fifo_dout        ), // output wire [47 : 0] dout
		.full         (fifo_full        ), // output wire full
		.empty        (fifo_empty       ), // output wire empty
		.valid        (fifo_valid       ), // output wire valid
		.wr_data_count(wr_data_count    )  // output wire [12 : 0] wr_data_count	
	);
//=================================================================================/
// 产生FIFO读使能信号fifo_rd_en，在FFT核准备好且FIFO非空时
// 在使能信号连续拉高1024个周期以后等待3个周期再拉高，用于分割一次1024长度的FFT
//=================================================================================/
	always@(posedge clk_300m or negedge locrstn) begin
		if(locrstn==1'b0) begin
			fifo_read_cunt <= 'd0;
		end else if(fifo_read_state == FIFO_READ) begin
			fifo_read_cunt <= fifo_read_cunt + 1'b1; 
		end else begin
			fifo_read_cunt <= 'd0;		
		end
	end	
//=================================================================================/
//用于产生FFT模块每帧输入最后（第1024个数据）一个数据的控制信息s_axis_data_tlast
//=================================================================================/
	always@(posedge clk_300m or negedge locrstn) begin
		if(locrstn == 1'b0) begin
			tlast_cnt <= 'd0;
		end else if((tlast_cnt == FFT_LEN-1) && (fifo_valid == 1'b1) || (fifo_read_state != FIFO_READ)) begin
			tlast_cnt <= 'd0;        
		end else if(fifo_valid == 1'b1) begin
			tlast_cnt <= tlast_cnt + 1'b1;
		end
	end	
	
assign fifo_rd_en = (fft_tready_path==1'b1) && (1<=fifo_read_cunt)&& (fifo_read_cunt<=FFT_LEN)&& (fifo_empty==1'b0)?  1'b1 : 1'b0;
// assign fifo_rd_en = (1<=fifo_read_cunt)&& (fifo_read_cunt<FFT_LEN+1)&& (fifo_empty==1'b0)?  1'b1 : 1'b0;
//-----------------------------------------FFT模块----------------------------------------------
//=================================================================================/
//输入的正弦信号为实信号放在实部
//=================================================================================/
	assign fft_data_tdata  = fifo_dout;
	assign fft_tvalid_path = fifo_valid;
	assign fft_tlast_path  = ((tlast_cnt == FFT_LEN - 1) && (fifo_valid)) ? 1'b1 : 1'b0;
 
	dds_compiler_0 dds_compiler_1m (
		.aclk               (clk_100m          ), // input wire aclk
		.s_axis_phase_tvalid(1'b1              ), // input wire s_axis_phase_tvalid
		.s_axis_phase_tdata (16'd655           ), // input wire [15:0] s_axis_phase_tdata
		.m_axis_data_tvalid (m_axis_data_tvalid), // output wire m_axis_data_tvalid
		.m_axis_data_tdata  (m_dds_tdata       )  // output wire [47:0] m_axis_data_tdata
	);
 
	cail_fft_ifft #(.BIT_NUM(24)) u_cail_fft_ifft (
		.SYS_CLK        (clk_300m       ), // (input ) (input ) 
		.SYS_RSTN       (locrstn        ), // (input ) (input ) 
		.fft_data_tdata (fft_data_tdata ), // (input ) (input )   
		.fft_tvalid_path(fft_tvalid_path), // (input ) (input ) 
		.fft_tlast_path (fft_tlast_path ), // (input ) (input ) 
		.fft_tready_path(fft_tready_path), // (output) (output) 
		.I_DATA_OUT     (				), // (output) (output)
		.Q_DATA_OUT     (				), // (output) (output)
		.DATA_OUT_VALID (				)  // (output) (output)       
	);
 
 
 
////////仿真数据保存为TXT文件
////integer     dout_file_imag;
////
////initial
////begin
////        dout_file_imag =$fopen("F:/shx/Matalb/test/f_imag.txt");
////        if(dout_file_imag == 0)begin
////                $display("can not open file!");
////                $stop;
////        end  
////end
////always @(posedge clk_300m)
////begin 
////        if(m_axis_data_tvalid) begin  
////                $fdisplay(dout_file_imag,"%d",$signed(f_imag)); 
////        end
////end
 
endmodule