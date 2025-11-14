// +FHDR============================================================================/
// Author       :
// Creat Time   : 2024/09/23 14:07:27
// File Name    : cail_fft_ifft.v
// Module Ver   : V1.0
//
// CopyRight(c) 2024, UNI_T
// All Rights Reserved
//
// ---------------------------------------------------------------------------------/
//
//                                              ------------------------------
//                                              |                            |
//                                              |       -^-        -^-       |
//                                              |                            |
//                                              |            -<>-            |
//                                              |                            |
//                                              ------------------------------
//
//
//
//
//
//
//
//
//
//
//
// Modification History:
// V1.0         initial
//
// -FHDR============================================================================/
//
//
//
//
`timescale 1 ns / 10ps
//
module cail_fft_ifft#(
	parameter BIT_NUM	= 24
)(
    input        pcie_user_clk  , // (input )
    input        pcie_user_rst_n, // (input )
    input        SYS_CLK        , // (input )
    input        SYS_RSTN       , // (input )
    input        caild_en       , // (input )

    input        fft_cail_init_flag, // (input )
    input [31:0] fft_cail_init_data, // (input )
    input        fft_cail_init_en  , // (input )

    (*mark_debug = "true"*)input [BIT_NUM*2-1:0] fft_data_tdata , // (input )
    (*mark_debug = "true"*)input                 fft_tvalid_path, // (input )
    (*mark_debug = "true"*)input                 fft_tlast_path , // (input )
    (*mark_debug = "true"*)output                fft_tready_path, // (output)
    (*mark_debug = "true"*)output         [31:0] I_DATA_OUT     , // (output)
    (*mark_debug = "true"*)output         [31:0] Q_DATA_OUT     , // (output)
    (*mark_debug = "true"*)output 	             DATA_OUT_VALID   // (output)
);
	//=================================================================================/
	// REST
	//=================================================================================/
	reg         rstn_buf,rstn;
	reg         fft_rst;
	//=================================================================================/
	// FFT CONFIG
	//=================================================================================/
	reg   [1:0] fft_ip_state;
	reg  [15:0] fft_config_dat;
	reg  [15:0] ifft_config_dat;
	reg         fft_config_tvalid;
	wire        fft_config_tdy_path;
	wire        ifft_config_tdy_path;
	//=================================================================================/
	// FFT DATA
	//=================================================================================/
	wire [BIT_NUM*2-1:0] fft_m_axis_data_tdata;
	// wire          [79:0] fft_m_axis_data_tdata;
	wire          [15:0] fft_m_axis_data_tuser;
	wire                 fft_m_axis_data_tvalid;
	wire                 fft_m_axis_data_tlast;
	//=================================================================================/
	// IFFT DATA
	//=================================================================================/
	wire [BIT_NUM*2-1:0] ifft_m_axis_data_tdata;
	// wire          [95:0] ifft_m_axis_data_tdata;
	wire          [15:0] ifft_m_axis_data_tuser;
	wire                 ifft_m_axis_data_tvalid;
	wire                 ifft_m_axis_data_tlast;
	wire                 ifft_tready_path;
	reg  [BIT_NUM*2-1:0] m_axis_data;
	// reg           [79:0] m_axis_data;
	reg                  m_axis_tlast;
	reg                  m_axis_tvalid;
	//=================================================================================/
	// CAIL DATA
	//=================================================================================/
	wire             [31:0] fft_cail_dout;
	reg  [BIT_NUM + 'd15:0] FFT_DATA_I;
	reg  [BIT_NUM + 'd15:0] FFT_DATA_Q;
	reg                     FFT_DATA_VLD;
	reg                     FFT_DATA_LAST;
	//=================================================================================/
	//DATA  截位
	//=================================================================================/
	wire        fft_data_cbit_i;
	wire        fft_data_cbit_q;
	wire [31:0] fft_data_round_i;
	wire [31:0] fft_data_round_q;

	wire        ifft_data_cbit_i;
	wire        ifft_data_cbit_q;
	wire [23:0] ifft_data_round_i;
	wire [23:0] ifft_data_round_q;

	wire  [7:0] ifft_m_axis_status_tdata;
	wire        ifft_m_axis_status_tvalid;
	wire        ifft_m_axis_status_tready;
	reg   [7:0] ifftdat_delay;
	reg         ifftdat_vlid;

	always@(posedge	SYS_CLK or negedge SYS_RSTN) begin
		if(SYS_RSTN == 1'b0) begin
			rstn_buf <= 1'b0;
			rstn     <= 1'b0;
		end else begin
			rstn_buf <= 1'b1;
			rstn     <= rstn_buf;
		end
	end

	always@(posedge	SYS_CLK or negedge rstn) begin
		if(rstn	== 1'b0) begin
			fft_rst	          <= 1'b0;
			fft_ip_state	  <= 2'd0;
			fft_config_tvalid <= 1'b0;
			fft_config_dat	  <= {7'd0,1'b1,3'b000,5'b01001};
			ifft_config_dat	  <= {7'd0,1'b0,3'b000,5'b01001};
		end else begin
			case(fft_ip_state)
				2'd0: begin
					fft_rst      <= 1'b1;
					fft_ip_state <= 2'd1;
				end
				2'd1: begin
					fft_ip_state		<= 2'd2;
					fft_config_dat		<= {7'd0,1'b1,3'b000,5'b01001};
					ifft_config_dat		<= {7'd0,1'b0,3'b000,5'b01001};
					fft_config_tvalid	<= 1'b1;
				end
				2'd2: begin
					if(fft_config_tdy_path == 1'b1) begin
						fft_config_tvalid	<= 1'b0;
						fft_ip_state		<= 2'd3;
					end
					// else;
				end
				2'd3: begin
					fft_ip_state <= 2'd3;
				end
				default: begin
					fft_ip_state <= 2'd0;
				end
			endcase
		end
	end
	//生成FFT的IP模块
	fft_cail	u_fft_cail (
		.aclk                       ( SYS_CLK               ), // input wire aclk
		.aresetn                    ( fft_rst               ), // input wire aresetn
	    // .s_axis_config_tdata        ( fft_config_dat        ), // input wire [15 : 0] s_axis_config_tdata
		.s_axis_config_tdata        ( 8'd1                  ), // input wire [15 : 0] s_axis_config_tdata
		.s_axis_config_tvalid       ( fft_config_tvalid     ), // input wire s_axis_config_tvalid
		.s_axis_config_tready       ( fft_config_tdy_path   ), // output wire s_axis_config_tready

		.s_axis_data_tdata          ( fft_data_tdata        ), // input wire [47 : 0] s_axis_data_tdata
		.s_axis_data_tvalid         ( fft_tvalid_path       ), // input wire s_axis_data_tvalid
		.s_axis_data_tready         ( fft_tready_path       ), // output wire s_axis_data_tready
		.s_axis_data_tlast          ( fft_tlast_path        ), // input wire s_axis_data_tlast

		.m_axis_data_tdata          ( fft_m_axis_data_tdata ), // output wire [47 : 0] m_axis_data_tdata
		.m_axis_data_tuser          (                       ), // output wire [7 : 0] m_axis_data_tuser
		// .m_axis_data_tready         ( 1'b1                  ), //取数延时，使最后一级fifo能够无损传输数据给ps// input wire m_axis_data_tready
		.m_axis_data_tready         ( ifftdat_vlid          ), //取数延时，使最后一级fifo能够无损传输数据给ps// input wire m_axis_data_tready
		.m_axis_data_tvalid         ( fft_m_axis_data_tvalid), // output wire m_axis_data_tvalid
		.m_axis_data_tlast          ( fft_m_axis_data_tlast ), // output wire m_axis_data_tlast
		.m_axis_status_tdata        (                       ), // output wire [7 : 0] m_axis_status_tdata
		.m_axis_status_tvalid       (                       ), // output wire m_axis_status_tvalid
		.m_axis_status_tready       ( 1'b1                  ), // input wire m_axis_status_tready

		.event_frame_started        (                       ), // output wire event_frame_started
		.event_tlast_unexpected     (                       ), // output wire event_tlast_unexpected
		.event_tlast_missing        (                       ), // output wire event_tlast_missing
		.event_data_in_channel_halt (                       ), // output wire event_data_in_channel_halt
		.event_status_channel_halt  (                       ), // output wire event_status_channel_halt
		.event_data_out_channel_halt(                       )  // output wire event_data_out_channel_halt
	);

	always@(posedge	SYS_CLK or negedge rstn)
	begin
		if(rstn	== 1'b0)begin
			m_axis_data		<= 'd0;
			m_axis_tlast	<= 1'b0;
			m_axis_tvalid	<= 1'b0;
		end else begin
			m_axis_data		<= fft_m_axis_data_tdata;
			m_axis_tlast	<= fft_m_axis_data_tlast;
			m_axis_tvalid	<= fft_m_axis_data_tvalid;
		end
	end


	always@(posedge	SYS_CLK or negedge rstn)
	begin
		if(rstn	== 1'b0)begin
			FFT_DATA_I			<= 'd0;
			FFT_DATA_Q			<= 'd0;
			FFT_DATA_VLD		<= 1'b0;
			FFT_DATA_LAST		<= 1'b0;
		end
		else begin
			if(m_axis_tvalid ==	1'b1)begin
					FFT_DATA_I			<= m_axis_data[32+:32]*fft_cail_dout[15: 0] - m_axis_data[0 +:32]*fft_cail_dout[31:16] ;
					FFT_DATA_Q			<= m_axis_data[32+:32]*fft_cail_dout[31:16] + m_axis_data[0 +:32]*fft_cail_dout[15: 0] ;
					FFT_DATA_VLD		<= 1'b1;
			end
			else begin
					FFT_DATA_VLD		<= 1'b0;
					FFT_DATA_I			<=  'd0;
					FFT_DATA_Q			<=  'd0;
			end
			FFT_DATA_LAST <= m_axis_tlast;
		end
	end

	assign fft_data_cbit_i	= FFT_DATA_I[47]?(FFT_DATA_I[14]&(|FFT_DATA_I[13:0])):FFT_DATA_I[14];
	assign fft_data_round_i	= FFT_DATA_I[46-:32] + fft_data_cbit_i;
	assign fft_data_cbit_q	= FFT_DATA_Q[47]?(FFT_DATA_Q[14]&(|FFT_DATA_Q[13:0])):FFT_DATA_Q[14];
	assign fft_data_round_q	= FFT_DATA_Q[46-:32] + fft_data_cbit_q;


	reg  [63:0] IFFT_DATA_IN;
	reg         IFFT_DATA_VALID_IN;
	wire        cail_data_chose;

	always@(posedge	SYS_CLK or negedge rstn) begin
		if(rstn	== 1'b0)begin
			IFFT_DATA_IN     	   <=  'd0;
			IFFT_DATA_VALID_IN 	   <= 1'b0;
		end else begin
			if(caild_en  ==	1'b1) begin
				IFFT_DATA_IN       <= {fft_data_round_i,fft_data_round_q};
				IFFT_DATA_VALID_IN <= FFT_DATA_VLD;
			end else begin
				IFFT_DATA_IN       <= m_axis_data;
				IFFT_DATA_VALID_IN <= m_axis_tvalid;
			end
		end
	end

	//生成IFFT的IP模块
	ifft_cail u_ifft_cail (
		.aclk                       (SYS_CLK                  ), // input wire aclk
		.aresetn                    (fft_rst                  ), // input wire aresetn
		.s_axis_config_tdata        (ifft_config_dat          ), // input wire [15 : 0] s_axis_config_tdata
	    // .s_axis_config_tdata        (8'b0                     ), // input wire [15 : 0] s_axis_config_tdata
		.s_axis_config_tvalid       (fft_config_tvalid        ), // input wire s_axis_config_tvalid
		.s_axis_config_tready       (ifft_config_tdy_path     ), // output wire s_axis_config_tready
		.s_axis_data_tdata          (IFFT_DATA_IN             ), // input wire [47 : 0] s_axis_data_tdata
		.s_axis_data_tvalid         (IFFT_DATA_VALID_IN       ), // input wire s_axis_data_tvalid
		.s_axis_data_tready         (ifft_tready_path         ), // output wire s_axis_data_tready
		.s_axis_data_tlast          (                         ), // input wire s_axis_data_tlast
		.m_axis_data_tdata          (ifft_m_axis_data_tdata   ), // output wire [47 : 0] m_axis_data_tdata
		// .m_axis_data_tready         (1'b1                     ), //取数延时，使最后一级fifo能够无损传输数据给ps// input wire m_axis_data_tready
		.m_axis_data_tready         (ifftdat_vlid             ), //取数延时，使最后一级fifo能够无损传输数据给ps// input wire m_axis_data_tready
		.m_axis_data_tvalid         (ifft_m_axis_data_tvalid  ), // output wire m_axis_data_tvalid
		.m_axis_data_tlast          (ifft_m_axis_data_tlast   ), // output wire m_axis_data_tlast

		.m_axis_status_tdata        (ifft_m_axis_status_tdata ), // output wire [7 : 0] m_axis_status_tdata
		.m_axis_status_tvalid       (ifft_m_axis_status_tvalid), // output wire m_axis_status_tvalid
		.m_axis_status_tready       (1'b1                     ), // input wire m_axis_status_tready
		.event_frame_started        (                         ), // output wire event_frame_started
		.event_tlast_unexpected     (                         ), // output wire event_tlast_unexpected
		.event_tlast_missing        (                         ), // output wire event_tlast_missing
		.event_data_in_channel_halt (                         ), // output wire event_data_in_channel_halt
		.event_status_channel_halt  (                         ), // output wire event_status_channel_halt
		.event_data_out_channel_halt(                         )  // output wire event_data_out_channel_halt
	);

	always@(posedge	SYS_CLK or negedge rstn)
	begin
		if(rstn	== 1'b0)begin
			ifftdat_delay		<=	6'd6;
			ifftdat_vlid		<=	1'b0;
		end else begin
			if(ifftdat_delay >= 6'd31) begin //fft 取数延时，使得最后一级fifo 能够无损传输数据给ps
				ifftdat_delay	<=	6'd0;
				ifftdat_vlid	<=	1'b1;
			end else begin
				ifftdat_delay	<=	ifftdat_delay + 1'b1;
				ifftdat_vlid	<=	1'b0;
			end
		end
	end

	reg         fifo_rd_en;
	reg   [5:0] fifo_rd_cunt;
	wire [63:0] dout;
	wire  [9:0] data_count;
	wire        full;
	wire        empty;
	wire        valid;

	ifft_fifo_data_300m  u_ifft_fifo_data_300m(
		.clk       (SYS_CLK                ), // input wire rd_clk
		.din       (ifft_m_axis_data_tdata ), // input wire [75 : 0] din
		.wr_en     (ifft_m_axis_data_tvalid), // input wire wr_en
		.rd_en     (fifo_rd_en             ), // input wire rd_en
		.dout      (dout                   ), // output wire [63 : 0] dout
		.data_count(data_count             ), // output wire [12 : 0] wr_data_count
		.full      (full                   ), // output wire full
		.empty     (empty                  ), // output wire empty
		.valid     (valid                  )  // output wire valid
	);
	always@(posedge	SYS_CLK or negedge rstn)
	begin
		if(rstn	== 1'b0)begin
			fifo_rd_en     <= 1'b0;
		end else begin
			if(empty==1'b0)
				fifo_rd_en <= 1'b1;
			else
				fifo_rd_en <= 1'b0;
		end
	end

	assign I_DATA_OUT  	  = dout[63-:32];
	assign Q_DATA_OUT  	  = dout[31-:32];
	assign DATA_OUT_VALID = valid;

endmodule