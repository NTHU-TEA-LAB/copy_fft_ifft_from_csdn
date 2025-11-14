`timescale 1 ns / 10ps
//
module adc_iq_cail#(
	parameter BIT_NUM	= 24
)(
  input                   SYS_CLK       , // (input) 300MHz
  input                   SYS_RSTN      , // (input)
  input  [BIT_NUM-1'b1:0] I_DATA_IN     , // (input)
  input  [BIT_NUM-1'b1:0] Q_DATA_IN     , // (input)
  input                   DATA_IN_VALID , // (input)
  output [BIT_NUM-1'b1:0] I_DATA_OUT    , // (output)
  output [BIT_NUM-1'b1:0] Q_DATA_OUT    , // (output)
  output                  DATA_OUT_VALID  // (output)
);
	localparam FFT_LEN = 512;
	reg        locrstn,locrstn_buf;
	//=================================================================================/
	// fifo
	//=================================================================================/
	wire        fifo_rd_en;
	wire [47:0] fifo_dout;
	wire        fifo_full;
	wire        fifo_empty;
	wire        fifo_valid;
	wire        fifo_wr_rst_busy;
	wire        fifo_rd_rst_busy;
	reg  [15:0] fifo_read_cunt;
	reg  [15:0] data_cunt;
	wire [12:0] wr_data_count;
	//=================================================================================/
	// FFT
	//=================================================================================/
	reg  [15:0] tlast_cnt;
	wire        fft_tlast_path;
	wire [47:0] fft_data_tdata;
	wire        fft_tvalid_path;
	wire        fft_tready_path;
	wire 	    m_axis_data_tvalid;
	wire [47:0] m_dds_tdata;
	//=================================================================================/
	// 状态机
	//=================================================================================/
	reg   [2:0] fifo_read_state;
	reg   [2:0] fifo_next__state;

	localparam FIFO_READ_IDLE   = 'd0;
	localparam FIFO_READ_WAIT   = 'd1;
	localparam FIFO_READ        = 'd2;
	localparam FIFO_READ_DONE   = 'd3;

		always@(posedge clk_300m or negedge locked)begin
			if(locked == 1'b0)begin
				locrstn_buf <= 1'b0;
				locrstn     <= 1'b0;
			end else begin
				locrstn_buf	<= 1'b1;
				locrstn	    <= locrstn_buf;
			end
		end

	//=================================================================================/
	// 生成仿真数据
	//=================================================================================/

	dds_compiler_0 dds_compiler_1m (
		.aclk                (clk_100m),           // input wire aclk
		.s_axis_phase_tvalid (1'b1),               // input wire s_axis_phase_tvalid
		.s_axis_phase_tdata  (16'd655),            // input wire [15 : 0] s_axis_phase_tdata
		.m_axis_data_tvalid  (m_axis_data_tvalid), // output wire m_axis_data_tvalid
		.m_axis_data_tdata   (m_dds_tdata)         // output wire [47 : 0] m_axis_data_tdata
	);
	//=================================================================================/
	// 状态机 控制FIFO数据流
	//=================================================================================/
	always @(posedge clk_300m or posedge locrstn) begin
		if( locrstn ==1'b0) begin
			fifo_read_state <= FIFO_READ_IDLE;
		end else begin
			fifo_read_state <= fifo_next__state;
		end
	end
	//     always @(*) begin
	always @(posedge clk_300m or posedge locrstn) begin
		case (fifo_read_state)
			FIFO_READ_IDLE: fifo_next__state = FIFO_READ_WAIT;
			// FIFO_READ_WAIT: fifo_next__state = (wr_data_count>=1100)&&(data_cunt<=5) ? FIFO_READ : FIFO_READ_WAIT;
			FIFO_READ_WAIT: fifo_next__state = ((fft_tready_path==1'b1)&&(wr_data_count>1100)) ? FIFO_READ : FIFO_READ_WAIT;
			FIFO_READ:      fifo_next__state = fft_tlast_path ? FIFO_READ_DONE : FIFO_READ;
			FIFO_READ_DONE: fifo_next__state = FIFO_READ_IDLE;
			default:        fifo_next__state = FIFO_READ_IDLE;
		endcase
	end

	always@(posedge clk_300m or negedge locrstn)begin
		if(locrstn==1'b0) begin
			data_cunt <= 'd0;
		end else if(data_cunt == 30) begin
			data_cunt <= data_cunt;
		end else if(fft_tlast_path)begin
			data_cunt <= data_cunt+1'b1;
		end else begin
			data_cunt <= data_cunt;
		end
	end
	//=================================================================================/
	//----------------------------------------FIFO模块---------------------------------
	//=================================================================================/
	fifo_ddc2fft_48bit u_fifo_ddc2fft_48bit (
		.wr_clk       (clk_100m          ), // input wire wr_clk
		.rd_clk       (clk_300m          ), // input wire rd_clk
		.din          (m_dds_tdata       ), // input wire [47 : 0] din
		.wr_en        (m_axis_data_tvalid), // input wire wr_en
		.rd_en        (fifo_rd_en        ), // input wire rd_en
		.dout         (fifo_dout         ), // output wire [47 : 0] dout
		.full         (fifo_full         ), // output wire full
		.empty        (fifo_empty        ), // output wire empty
		.valid        (fifo_valid        ), // output wire valid
		.wr_data_count(wr_data_count     )  // output wire [12 : 0] wr_data_count
	);
	//=================================================================================/
	// 产生FIFO读使能信号fifo_rd_en，在FFT核准备好且FIFO非空时
	//=================================================================================/
	always@(posedge clk_300m or negedge locrstn) begin
		if(locrstn == 1'b0) begin
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
		if(locrstn==1'b0) begin
			tlast_cnt <= 'd0;
		end else if((tlast_cnt==FFT_LEN-1)&&(fifo_valid==1'b1)||(fifo_read_state != FIFO_READ)) begin
			tlast_cnt <= 'd0;
		end else if(fifo_valid==1'b1) begin
			tlast_cnt <= tlast_cnt+1'b1;
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
	assign fft_tlast_path  = ((tlast_cnt==FFT_LEN-1)&&(fifo_valid)) ? 1'b1 : 1'b0;

	cail_fft_ifft #(.BIT_NUM(BIT_NUM)) u_cail_fft_ifft (
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

endmodule