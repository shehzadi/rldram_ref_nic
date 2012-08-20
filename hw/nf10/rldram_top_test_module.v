`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:44:22 08/13/2012 
// Design Name: 
// Module Name:    rldram_top_test_module 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module rldram_top_test_module(
    refClk_p,
   refClk_n,
   sysClk_p,
	intClk,
   sysClk_n,
   sysReset,
   dip,
   clk33,

 //  FPGA3_7SEG,
 //  DBG_LED,
 //  FPGA3_TEST_HDR,

   // RLD2 memory signals
   RLD2_CK_P,
   RLD2_CK_N,
   RLD2_DK_P,
   RLD2_DK_N,
   RLD2_QK_P,
   RLD2_QK_N,
   RLD2_A,
   RLD2_BA,
   RLD2_CS_N,
   RLD2_WE_N,
   RLD2_REF_N,
   RLD2_DM,
   RLD2_DQ,
   RLD2_QVLD,
	RLD2_CK_P_C2,
   RLD2_CK_N_C2,
   RLD2_DK_P_C2,
   RLD2_DK_N_C2,
   RLD2_QK_P_C2,
   RLD2_QK_N_C2,
   RLD2_A_C2,
   RLD2_BA_C2,
   RLD2_CS_N_C2,
   RLD2_WE_N_C2,
   RLD2_REF_N_C2,
   RLD2_DM_C2,
   RLD2_DQ_C2,
   RLD2_QVLD_C2,
	

 //  rldReadData, 
 //  rldReadDataValid, 

    
  
  // rlWdfEmpty, 
 //  rlWdfFull, 
 //  rlRdfEmpty, 
 //  rlafEmpty, 
 //  rlafFull, 

	s_axis_0_tdata,
   s_axis_0_tstrb,
   s_axis_0_tuser,
   s_axis_0_tvalid,
   s_axis_0_tready,
   s_axis_0_tlast,
	s_axis_1_tdata,
   s_axis_1_tstrb,
   s_axis_1_tuser,
   s_axis_1_tvalid,
   s_axis_1_tready,
   s_axis_1_tlast,
	s_axis_2_tdata,
   s_axis_2_tstrb,
   s_axis_2_tuser,
   s_axis_2_tvalid,
   s_axis_2_tready,
   s_axis_2_tlast,
	s_axis_3_tdata,
   s_axis_3_tstrb,
   s_axis_3_tuser,
   s_axis_3_tvalid,
   s_axis_3_tready,
   s_axis_3_tlast,
	m_axis_0_tdata,
	m_axis_0_tstrb,
	m_axis_0_tuser,
	m_axis_0_tvalid,
	m_axis_0_tready,
	m_axis_0_tlast,
	m_axis_1_tdata,
	m_axis_1_tstrb,
	m_axis_1_tuser,
	m_axis_1_tvalid,
	m_axis_1_tready,
	m_axis_1_tlast,	
	m_axis_2_tdata,
	m_axis_2_tstrb,
	m_axis_2_tuser,
	m_axis_2_tvalid,
	m_axis_2_tready,
	m_axis_2_tlast,	
	m_axis_3_tdata,
	m_axis_3_tstrb,
	m_axis_3_tuser,
	m_axis_3_tvalid,
	m_axis_3_tready,
	m_axis_3_tlast	

	
   
   // PASS_FAIL
);

// public parameters -- adjustable
parameter SIMULATION_ONLY = 1'b0;  // if set (1'b1), it shortens the wait time
//
parameter RL_DQ_WIDTH     = 36;
parameter DEV_DQ_WIDTH    = 18;  // data width of the memory device
parameter NUM_OF_DEVS     = RL_DQ_WIDTH/DEV_DQ_WIDTH;  // number of memory devices
parameter NUM_OF_DKS      = (DEV_DQ_WIDTH == 36) ? 2*NUM_OF_DEVS : NUM_OF_DEVS;
parameter DEV_AD_WIDTH    = 20;  // address width of the memory device
parameter DEV_BA_WIDTH    = 3;   // bank address width of the memory device
parameter APP_AD_WIDTH    = 1+1+1+DEV_AD_WIDTH+DEV_BA_WIDTH;
parameter DUPLICATE_CONTROLS = 1'b0;  // Duplicate the ports for A, BA, WE# and REF#
//
parameter RL_CK_PERIOD  = 16'd3003;  // CK clock period of the RLDRAM in ps
// MRS (Mode Register Set command) parameters   
//    please check Micron RLDRAM-II datasheet for definitions of these parameters
parameter RL_MRS_CONF            = 3'b011; // 3'b001: mode1;  3'b010: mode2;  3'b011: mode3
parameter RL_MRS_BURST_LENGTH    = 2'b01;  // 2'b00: BL2;  2'b01: BL4;  2'b10: BL8 (BL8 unsupported)
parameter RL_MRS_ADDR_MUX        = 1'b0;   // 1'b0: non-muxed addr;  1'b1: muxed addr
parameter RL_MRS_DLL_RESET       = 1'b1;   // 1'b0: Memory DLL reset; 1'b1: Memory DLL enabled
parameter RL_MRS_IMPEDANCE_MATCH = 1'b1;   // 1'b0: internal 50ohms output buffer impedance, 1'b1: external 
parameter RL_MRS_ODT             = 1'b0;   // 1'b0: disable term;  1'b1: enable term
//
// specific to FPGA/memory devices and capture method
parameter RL_IO_TYPE     = 2'b00;    // CIO=2'b00  SIO_CIO_HYBRID=2'b01  SIO=2'b10
parameter DEVICE_ARCH    = 2'b01;    // Virtex4=2'b00  Virtex5=2'b01
parameter CAPTURE_METHOD = 2'b01;    // Direct Clocking=2'b00  SerDes=2'b01
parameter CAL_ADDRESS    = {DEV_AD_WIDTH{1'b0}}; //saved location to perform calibration
// end of public parameters
parameter TDATA_WIDTH        = 32;
	// Width of TUSER in bits
parameter TUSER_WIDTH        = 128;
parameter C_S_AXIS_DATA_WIDTH = TDATA_WIDTH*8;
parameter C_S_AXIS_TUSER_WIDTH = TUSER_WIDTH;
parameter NUM_QUEUES         = 4;
parameter TID_WIDTH          = 4;
parameter TDEST_WIDTH        = 4;
parameter QUEUE_ID_WIDTH     = 2;
parameter C_M_AXIS_DATA_WIDTH = TDATA_WIDTH*8;
parameter C_M_AXIS_TUSER_WIDTH = TUSER_WIDTH;


   // System signals and debug
   input            refClk_p;
   input            refClk_n;
   input            sysClk_p;
	input					intClk;
   input            sysClk_n;
   input            sysReset;
   input            dip;
   input            clk33;

 //  output [7:0]     FPGA3_7SEG;
 //  output [3:0]     DBG_LED;
 //  output [7:0]     FPGA3_TEST_HDR;

   // RLD2 memory signals
   output [NUM_OF_DEVS-1:0]    RLD2_CK_P;
   output [NUM_OF_DEVS-1:0]    RLD2_CK_N;
   output [NUM_OF_DKS-1:0]     RLD2_DK_P;
   output [NUM_OF_DKS-1:0]     RLD2_DK_N;
   input  [2*NUM_OF_DEVS-1:0]  RLD2_QK_P;
   input  [2*NUM_OF_DEVS-1:0]  RLD2_QK_N;
   output [DEV_AD_WIDTH-1:0]   RLD2_A;
   output [DEV_BA_WIDTH-1:0]   RLD2_BA;
   output [NUM_OF_DEVS-1:0]    RLD2_CS_N;
   output                      RLD2_WE_N;
   output                      RLD2_REF_N;
   output [NUM_OF_DEVS-1:0]    RLD2_DM;
   inout  [RL_DQ_WIDTH-1:0]    RLD2_DQ;
   input  [NUM_OF_DEVS-1:0]    RLD2_QVLD;
	
	output [NUM_OF_DEVS-1:0]    RLD2_CK_P_C2;
   output [NUM_OF_DEVS-1:0]    RLD2_CK_N_C2;
   output [NUM_OF_DKS-1:0]     RLD2_DK_P_C2;
   output [NUM_OF_DKS-1:0]     RLD2_DK_N_C2;
   input  [2*NUM_OF_DEVS-1:0]  RLD2_QK_P_C2;
   input  [2*NUM_OF_DEVS-1:0]  RLD2_QK_N_C2;
   output [DEV_AD_WIDTH-1:0]   RLD2_A_C2;
   output [DEV_BA_WIDTH-1:0]   RLD2_BA_C2;
   output [NUM_OF_DEVS-1:0]    RLD2_CS_N_C2;
   output                      RLD2_WE_N_C2;
   output                      RLD2_REF_N_C2;
   output [NUM_OF_DEVS-1:0]    RLD2_DM_C2;
   inout  [RL_DQ_WIDTH-1:0]    RLD2_DQ_C2;
   input  [NUM_OF_DEVS-1:0]    RLD2_QVLD_C2;

   // output [2:0]     PASS_FAIL;
	
  

	 
	 input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_0_tdata;
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_0_tstrb;
    input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_0_tuser;
    input  s_axis_0_tvalid;
    output s_axis_0_tready;
    input  s_axis_0_tlast;
    
    input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_1_tdata;
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_1_tstrb;
    input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_1_tuser;
    input  s_axis_1_tvalid;
    output s_axis_1_tready;
    input  s_axis_1_tlast;

    input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_2_tdata;
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_2_tstrb;
    input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_2_tuser;
    input  s_axis_2_tvalid;
    output s_axis_2_tready;
    input  s_axis_2_tlast;

    input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_3_tdata;
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_3_tstrb;
    input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_3_tuser;
    input  s_axis_3_tvalid;
    output s_axis_3_tready;
    input  s_axis_3_tlast;
	 
	 output [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_0_tdata;
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_0_tstrb;
    output [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_0_tuser;
    output m_axis_0_tvalid;
    input  m_axis_0_tready;
    output m_axis_0_tlast;

    output [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_1_tdata;
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_1_tstrb;
    output [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_1_tuser;
    output m_axis_1_tvalid;
    input  m_axis_1_tready;
    output m_axis_1_tlast;

    output [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_2_tdata;
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_2_tstrb;
    output [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_2_tuser;
    output m_axis_2_tvalid;
    input  m_axis_2_tready;
    output m_axis_2_tlast;

    output [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_3_tdata;
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_3_tstrb;
    output [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_3_tuser;
    output m_axis_3_tvalid;
    input  m_axis_3_tready;
    output m_axis_3_tlast;
	
	wire [(NUM_QUEUES-1):0]        tvalid_in = {s_axis_3_tvalid, s_axis_2_tvalid, s_axis_1_tvalid, s_axis_0_tvalid};
	wire [(NUM_QUEUES-1):0]       tready_in;
	assign {s_axis_3_tready, s_axis_2_tready, s_axis_1_tready, s_axis_0_tready} = tready_in;
	wire [((8*TDATA_WIDTH*NUM_QUEUES) - 1):0] tdata_in = {s_axis_3_tdata, s_axis_2_tdata, s_axis_1_tdata, s_axis_0_tdata};
   wire [(NUM_QUEUES-1):0]        tlast_in = {s_axis_3_tlast, s_axis_2_tlast, s_axis_1_tlast, s_axis_0_tlast};
   wire [(TID_WIDTH*NUM_QUEUES-1):0]         tid_in;
   wire [(TDEST_WIDTH*NUM_QUEUES-1):0]       tdest_in;
   wire [(TUSER_WIDTH*NUM_QUEUES-1):0]       tuser_in = {s_axis_3_tuser, s_axis_2_tuser, s_axis_1_tuser, s_axis_0_tuser};
	wire [((TDATA_WIDTH*NUM_QUEUES) - 1):0] tstrb_in = {s_axis_3_tstrb, s_axis_2_tstrb, s_axis_1_tstrb, s_axis_0_tstrb};
	wire [(NUM_QUEUES-1):0]         tvalid_out;
	assign {m_axis_3_tvalid, m_axis_2_tvalid, m_axis_1_tvalid, m_axis_0_tvalid} = tvalid_out;
	wire [(NUM_QUEUES-1):0]     tready_out = {m_axis_3_tready, m_axis_2_tready, m_axis_1_tready, m_axis_0_tready};
	wire [((8*TDATA_WIDTH*NUM_QUEUES) - 1):0] tdata_out;
	assign {m_axis_3_tdata, m_axis_2_tdata, m_axis_1_tdata, m_axis_0_tdata} = tdata_out;
	wire [(NUM_QUEUES-1):0]                   tlast_out;
	assign {m_axis_3_tlast, m_axis_2_tlast, m_axis_1_tlast, m_axis_0_tlast} = tlast_out;
	wire [(TID_WIDTH*NUM_QUEUES-1):0]         tid_out;
	wire [(TDEST_WIDTH*NUM_QUEUES-1):0]       tdest_out;
	wire [(TUSER_WIDTH*NUM_QUEUES-1):0]       tuser_out;
	assign {m_axis_3_tuser, m_axis_2_tuser, m_axis_1_tuser, m_axis_0_tuser} = tuser_out;
	wire [((TDATA_WIDTH*NUM_QUEUES) - 1):0] tstrb_out;
    assign {m_axis_3_tstrb, m_axis_2_tstrb, m_axis_1_tstrb, m_axis_0_tstrb} = tstrb_out;
	wire [127:0] input_fifo_cnt;
	wire [(NUM_QUEUES-1):0] rinc_in;
	wire [(NUM_QUEUES-1):0] rempty_in;
	wire [(NUM_QUEUES-1):0] r_almost_empty_in;
	wire [(NUM_QUEUES-1):0] dout_valid_in;
	wire [(NUM_QUEUES*(TDATA_WIDTH*8+5+1+16)-1):0] dout_in;
	wire [(NUM_QUEUES-1):0] din_valid_out;
	wire [(NUM_QUEUES*(TDATA_WIDTH*8+5+1+16)-1):0] din_out;
	wire [(NUM_QUEUES-1):0] w_almost_full_out;
	wire [(NUM_QUEUES-1):0] wfull_out;
	wire [NUM_QUEUES:0] output_inc; //check if there is an extra bit here
	wire [NUM_OF_DEVS-1:0] Init_Done;
	
	wire read_burst, write_burst;
	wire [((TDATA_WIDTH*8+5+1+16)-1):0] mem_din;
	wire [((TDATA_WIDTH*8+5+1+16)-1):0] mem_dout;

	wire mem_dout_valid;
	wire mem_din_valid;
	wire [(NUM_QUEUES-1):0] mem_rempty;
	wire [(NUM_QUEUES-1):0] mem_rfull;
	wire [(NUM_QUEUES-1):0] mem_wfull;
	wire [(QUEUE_ID_WIDTH-1):0] mem_queue_id_read;
	wire [(QUEUE_ID_WIDTH-1):0] mem_queue_id_write;
	wire [(QUEUE_ID_WIDTH-1):0] mem_din_queue_id;
	
	wire [(NUM_QUEUES-1):0] winc_out;
	wire next_winc;
	

	wire                         issueCalibration;
	
	wire q_read_select, q_write_select;


   // application interface signals
   wire  [NUM_OF_DEVS-1:0]      apRdfRdEn;
   wire  [17:0]     apAddr;
   wire                         apValid;
   wire  [(2*NUM_OF_DEVS)-1:0]  apWriteDM;
   wire  [(4*RL_DQ_WIDTH)-1:0]  apWriteData;
   wire                         apWriteDValid;
   wire  [3:0]                  apConfA;
   wire  [7:0]                  apConfWrD;
   wire                         apConfRd;
   wire                         apConfWr;

   wire [(8*NUM_OF_DEVS)-1:0]                  apConfRdD;
	
	
	wire [(4*RL_DQ_WIDTH)-1:0]  rldReadData;
	wire [NUM_OF_DEVS-1:0]      rldReadDataValid;

	wire      [NUM_OF_DEVS-1:0]                  rlWdfEmpty;
	wire     [NUM_OF_DEVS-1:0]                   rlWdfFull;
	wire    [NUM_OF_DEVS-1:0]                    rlRdfEmpty;
	wire    [NUM_OF_DEVS-1:0]                    rlafEmpty;
	wire   [NUM_OF_DEVS-1:0]                     rlafFull;
	wire [NUM_OF_DEVS*13-1:0]                 rlWdfWrCount  ;   // write data FIFO (wdfifo) write count
   wire [NUM_OF_DEVS*13-1:0]                 rlWdfWordCount  ; // write data FIFO (wdfifo) write count
   wire [NUM_OF_DEVS*13-1:0]                 rlafWrCount ;    // command/address FIFO (rafifo) write count
   wire [NUM_OF_DEVS*13-1:0]                 rlafWordCount  ;
	
	genvar i;
	generate
	for(i=0;i<NUM_QUEUES;i=i+1)
	begin : aximasterslave
	/*  AxiToFifo #(.TDATA_WIDTH(TDATA_WIDTH),
					  .TUSER_WIDTH(TUSER_WIDTH),
					  .TID_WIDTH(TID_WIDTH), 
					  .TDEST_WIDTH(TDEST_WIDTH), 
					  .NUM_QUEUES(NUM_QUEUES), 
					  .QUEUE_ID_WIDTH(QUEUE_ID_WIDTH)) 
					axififo(
							  .clk(intClk),
							  .reset(~sysReset),
							  .tvalid(tvalid_in[i]),
							  .tready(tready_in[i]),
							  .tdata(tdata_in[((i+1)*TDATA_WIDTH*8-1):(i*TDATA_WIDTH*8)]),
							  .tlast(tlast_in[i]),
							  .tid(tid_in[((i+1)*TID_WIDTH-1):(i*TID_WIDTH)]),
							  .tdest(tdest_in[((i+1)*TDEST_WIDTH-1):(i*TDEST_WIDTH)]),
							  .tuser(tuser_in[((i+1)*TUSER_WIDTH-1):(i*TUSER_WIDTH)]),
							  .memclk(intClk),
							  .rinc(rinc_in[i]),
							  .rempty(rempty_in[i]),
							  .r_almost_empty(r_almost_empty_in[i]),
							  .dout_valid(dout_valid_in[i]),
			//				  .dout(dout_in[((i+1)*(8*TDATA_WIDTH+/*TUSER_WIDTH+*///1)-1):(i*(8*TDATA_WIDTH+/*TUSER_WIDTH+*/1))]), 
				//			  .cal_done/*(fake_cal),//*/(&Init_Done),
					//		  .output_inc(output_inc[i])
						//	  );*/
	 AxiToFifo #(.TDATA_WIDTH(TDATA_WIDTH),
                    
                    .TUSER_WIDTH(TUSER_WIDTH),
                    .TID_WIDTH(TID_WIDTH),
                    .TDEST_WIDTH(TDEST_WIDTH),
                    .NUM_QUEUES(NUM_QUEUES),
                    .QUEUE_ID_WIDTH(QUEUE_ID_WIDTH))
                  axififo(
                          .clk(intClk),
                          .reset(~sysReset),
                          .tvalid(tvalid_in[i]),
                          .tready(tready_in[i]),
                          .tdata(tdata_in[((i+1)*TDATA_WIDTH*8-1):(i*TDATA_WIDTH*8)]),
                          .tstrb(tstrb_in[((i+1)*TDATA_WIDTH-1):(i*TDATA_WIDTH)]),
                          .tlast(tlast_in[i]),
                          .tid(tid_in[((i+1)*TID_WIDTH-1):(i*TID_WIDTH)]),
                          .tdest(tdest_in[((i+1)*TDEST_WIDTH-1):(i*TDEST_WIDTH)]),
                          .tuser(tuser_in[((i+1)*TUSER_WIDTH-1):(i*TUSER_WIDTH)]),
                          .memclk(intClk),
                          .memreset(~sysReset),
                          .rinc(rinc_in[i]),
                          .rempty(rempty_in[i]),
                          .r_almost_empty(r_almost_empty_in[i]),
                          .dout_valid(dout_valid_in[i]),
                          .dout(dout_in[((i+1)*(8*TDATA_WIDTH+6+16)-1):(i*(8*TDATA_WIDTH+6+16))]),
                          .cal_done(&Init_Done),
                          .output_inc(output_inc[i]),
                          .input_fifo_cnt(input_fifo_cnt[(32*i+31):(32*i)])
                          );

	  FifoToAxi #(.TDATA_WIDTH(TDATA_WIDTH),
					  .TUSER_WIDTH(TUSER_WIDTH),
					  .TID_WIDTH(TID_WIDTH), 
					  .TDEST_WIDTH(TDEST_WIDTH), 
					  .NUM_QUEUES(NUM_QUEUES), 
					  .QUEUE_ID_WIDTH(QUEUE_ID_WIDTH)) 
					fifoaxi(
							  .clk(intClk),
							  .reset(~sysReset),
							  .tvalid(tvalid_out[i]),
							  .tready(tready_out[i]),
							  .tdata(tdata_out[((i+1)*TDATA_WIDTH*8-1):(i*TDATA_WIDTH*8)]),
							  .tlast(tlast_out[i]),
							  .tid(tid_out[((i+1)*TID_WIDTH-1):(i*TID_WIDTH)]),
							  .tdest(tdest_out[((i+1)*TDEST_WIDTH-1):(i*TDEST_WIDTH)]),
							  .tuser(tuser_out[((i+1)*TUSER_WIDTH-1):(i*TUSER_WIDTH)]),
							  .memclk(intClk),
							  .memreset(~sysReset),
							  .din_valid(din_valid_out[i]),
							  .din(din_out[((i+1)*(8*TDATA_WIDTH+5+1+16)-1):(i*(8*TDATA_WIDTH+5+1+16))]),
							  .w_almost_full(w_almost_full_out[i]),
							  .wfull(wfull_out[i]), 
							  .cal_done/*(fake_cal),//*/(&Init_Done),
							  .rinc(output_inc[i])
							  );
	end
	endgenerate
	
	
	rldAxiFifoArbiter #(.TDATA_WIDTH(TDATA_WIDTH),
                     .TUSER_WIDTH(TUSER_WIDTH),
                     .NUM_QUEUES(NUM_QUEUES), 
                     .QUEUE_ID_WIDTH(QUEUE_ID_WIDTH)) 
                  inarb(
                          .clk(intClk),
                          .reset(~sysReset),
                          .memclk(intClk),
                          .inc(rinc_in),
                          .empty(rempty_in), // used to be almost_empty
                          .write_burst(write_burst),
                          .din_valid(dout_valid_in),
                          .din(dout_in),
                          .mem_queue_full(mem_wfull),
                          .queue_id(mem_queue_id_write),
                          .dout(mem_dout),
                          .dout_valid(mem_dout_valid),
								  .q_write_select(q_write_select),
								  .next_dout_valid(next_write_true)
								  
                       );
    

	 rldFifoMem       #(.TDATA_WIDTH(TDATA_WIDTH),
                    .TUSER_WIDTH(TUSER_WIDTH),
                    .NUM_QUEUES(NUM_QUEUES), 
                    .QUEUE_ID_WIDTH(QUEUE_ID_WIDTH)) 
                  fifomem(
                          .clk(intClk),
                          .reset(~sysReset),
                          .read_queue_id(mem_queue_id_read),
                          .read_data_queue_id(mem_din_queue_id),
                          .read_data_ready(winc_out[mem_queue_id_read]),
                          .read_data(mem_din),
                          .read_data_valid(mem_din_valid),
                          .read_empty(mem_rempty),
                          .read_burst_state(read_burst), 
                          .write_queue_id(mem_queue_id_write), 
                          .write_data(mem_dout),
                          .write_data_valid(mem_dout_valid),
                          .write_full(mem_wfull), 
                          .next_write_burst_state(write_burst),
								  .apRdfRdEn(apRdfRdEn),//
								  .apWriteData(apWriteData),
								  .apValid(apValid),
								  .apWriteDM(apWriteDM),
								  .apWriteDValid(apWriteDValid),
								  .apConfA(apConfA),
								  .apConfWrD(apConfWrD[7:0]),
								  .apConfRd(apConfRd),
								  .apConfWr(apConfWr),
								  .apConfRdD(apConfRdD),
								  .rlWdfEmpty(rlWdfEmpty),
								  .rlWdfFull(rlWdfFull),
								  .rlRdfEmpty(rlRdfEmpty),
								  .rlafFull(rlafFull),
								  .rlWdfWrCount(rlWdfWrCount),
								  .rlWdfWordCount(rlWdfWordCount),
								  .rlafWrCount(rlafWrCount),
								  .rlafWordCount(rlafWordCount),
	 
								  .issueCalibration(issueCalibration),
								  .InitDone/*(fake_cal),//*/(&Init_Done),
	 
								  .rldReadData(rldReadData),
								  .rldReadDataValid(rldReadDataValid),
								  .apAddr(apAddr),
                          .q_write_select(q_write_select),
								  .q_read_select(q_read_select),
								  .next_read_true(next_winc),
								  .next_write_true(next_write_true),
								  .readSigForAdd(readSigForAdd)
                          );

   rld_mem_interface_top  #(
      .SIMULATION_ONLY    ( SIMULATION_ONLY ),     // if set, it shortens the wait time
      .RL_DQ_WIDTH        ( RL_DQ_WIDTH ),
      .DEV_DQ_WIDTH       ( DEV_DQ_WIDTH ),        // data width of the memory device
      .DEV_AD_WIDTH       ( DEV_AD_WIDTH ),        // address width of the memory device
      .DEV_BA_WIDTH       ( DEV_BA_WIDTH ),        // bank address width of the memory device
      .DUPLICATE_CONTROLS ( DUPLICATE_CONTROLS ),  // Duplicate the ports for A, BA, WE# and REF#
      .RL_CK_PERIOD         ( RL_CK_PERIOD ),      // CK clock period of the RLDRAM in ps
      // MRS (Mode Register Set command) parameters   
      .RL_MRS_CONF            ( RL_MRS_CONF ),             // 3'b001: mode1;  3'b010: mode2;  3'b011: mode3
      .RL_MRS_BURST_LENGTH    ( RL_MRS_BURST_LENGTH ),     // 2'b00: BL2;  2'b01: BL4;  2'b10: BL8
      .RL_MRS_ADDR_MUX        ( RL_MRS_ADDR_MUX ),         // 1'b0: non-muxed addr;  1'b1: muxed addr
      .RL_MRS_DLL_RESET       ( RL_MRS_DLL_RESET ),        //
      .RL_MRS_IMPEDANCE_MATCH ( RL_MRS_IMPEDANCE_MATCH ),  // internal 50ohms output buffer impedance
      .RL_MRS_ODT             ( RL_MRS_ODT ),              // 1'b0: disable term;  1'b1: enable term
      // specific to FPGA/memory devices and capture method
      .RL_IO_TYPE     ( RL_IO_TYPE ),       // CIO=2'b00  SIO_CIO_HYBRID=2'b01  SIO=2'b10
      .DEVICE_ARCH    ( DEVICE_ARCH ),      // Virtex4=2'b00  Virtex5=2'b01
      .CAPTURE_METHOD ( CAPTURE_METHOD ),    // Direct Clocking=2'b00  SerDes=2'b01
      .CAL_ADDRESS    ( CAL_ADDRESS )
   )
   ml561_top0  (
      // globals
	
      .sysReset ( sysReset   ),
      .sysClk_p ( sysClk_p     ),
      .sysClk_n ( sysClk_n    ),
      .refClk_p ( refClk_p  ),    // 200MHz differential reference clock
		.refClk_n ( refClk_n ),
      .clk33    ( clk33 ),
     
      // RLDRAM interface signals
      .RLD2_CK_P  ( RLD2_CK_P   ),
      .RLD2_CK_N  ( RLD2_CK_N ),      
      .RLD2_CS_N  ( RLD2_CS_N  ),
      .RLD2_REF_N ( RLD2_REF_N ),
      .RLD2_WE_N  ( RLD2_WE_N  ),      
      .RLD2_A     ( RLD2_A  ),
      .RLD2_BA    ( RLD2_BA ),
      .RLD2_DM    ( RLD2_DM ),      
      .RLD2_QK_P  ( RLD2_QK_P   ),
      .RLD2_QK_N  ( RLD2_QK_N ),      
      .RLD2_DK_P  ( RLD2_DK_P   ),
      .RLD2_DK_N  ( RLD2_DK_N ),      
      .RLD2_QVLD  ( RLD2_QVLD ),      
      .RLD2_DQ    ( RLD2_DQ ),
		
		.rldReadData      ( rldReadData[RL_DQ_WIDTH*2-1:0] ), //output
		.rldReadDataValid (rldReadDataValid[0]), //output
		.apConfRdD(apConfRdD[7:0]),
		.rlWdfEmpty(rlWdfEmpty[0]),
		.rlWdfFull(rlWdfFull[0]),
		.rlRdfEmpty(rlRdfEmpty[0]),
		.rlafEmpty(rlafEmpty[0]),
		.rlafFull(rlafFull[0]),
		.rlWdfWrCount(rlWdfWrCount[12:0]),   // write data FIFO (wdfifo) write count
		.rlWdfWordCount(rlWdfWordCount[12:0]), // write data FIFO (wdfifo) write count
		.rlafWrCount(rlafWrCount[12:0]),    // command/address FIFO (rafifo) write count
		.rlafWordCount(rlafWordCount[12:0]), 
		
		.apRdfRdEn(apRdfRdEn[0]),
		.apAddr({1'b0,readSigForAdd,6'b0,apAddr}),
		.apValid(apValid),
		.apWriteDM(apWriteDM),
		.apWriteData(apWriteData[RL_DQ_WIDTH*2-1:0]),
		.apWriteDValid(apWriteDValid),
		.apConfA(apConfA),
		.apConfWrD(apConfWrD[7:0]),
		.apConfRd(apConfRd),
		.apConfWr(apConfWr),
      // observation points
      //.PASS_FAIL  (  ),		
      .dip				   ( dip ),
		.Init_Done(Init_Done[0])
   //   .FPGA3_7SEG			( DISPLAY ),
  //    .DBG_LED				( LED ),
  //    .FPGA3_TEST_HDR   ( TEST_HDR )
);


   rld_mem_interface_top  #(
      .SIMULATION_ONLY    ( SIMULATION_ONLY ),     // if set, it shortens the wait time
      .RL_DQ_WIDTH        ( RL_DQ_WIDTH ),
      .DEV_DQ_WIDTH       ( DEV_DQ_WIDTH ),        // data width of the memory device
      .DEV_AD_WIDTH       ( DEV_AD_WIDTH ),        // address width of the memory device
      .DEV_BA_WIDTH       ( DEV_BA_WIDTH ),        // bank address width of the memory device
      .DUPLICATE_CONTROLS ( DUPLICATE_CONTROLS ),  // Duplicate the ports for A, BA, WE# and REF#
      .RL_CK_PERIOD         ( RL_CK_PERIOD ),      // CK clock period of the RLDRAM in ps
      // MRS (Mode Register Set command) parameters   
      .RL_MRS_CONF            ( RL_MRS_CONF ),             // 3'b001: mode1;  3'b010: mode2;  3'b011: mode3
      .RL_MRS_BURST_LENGTH    ( RL_MRS_BURST_LENGTH ),     // 2'b00: BL2;  2'b01: BL4;  2'b10: BL8
      .RL_MRS_ADDR_MUX        ( RL_MRS_ADDR_MUX ),         // 1'b0: non-muxed addr;  1'b1: muxed addr
      .RL_MRS_DLL_RESET       ( RL_MRS_DLL_RESET ),        //
      .RL_MRS_IMPEDANCE_MATCH ( RL_MRS_IMPEDANCE_MATCH ),  // internal 50ohms output buffer impedance
      .RL_MRS_ODT             ( RL_MRS_ODT ),              // 1'b0: disable term;  1'b1: enable term
      // specific to FPGA/memory devices and capture method
      .RL_IO_TYPE     ( RL_IO_TYPE ),       // CIO=2'b00  SIO_CIO_HYBRID=2'b01  SIO=2'b10
      .DEVICE_ARCH    ( DEVICE_ARCH ),      // Virtex4=2'b00  Virtex5=2'b01
      .CAPTURE_METHOD ( CAPTURE_METHOD ),    // Direct Clocking=2'b00  SerDes=2'b01
      .CAL_ADDRESS    ( CAL_ADDRESS )
   )
   ml561_top1  (
      // globals
	
      .sysReset ( sysReset   ),
      .sysClk_p ( sysClk_p     ),
      .sysClk_n ( sysClk_n    ),
      .refClk_p ( refClk_p  ),    // 200MHz differential reference clock
		.refClk_n ( refClk_n ),
      .clk33    ( clk33 ),
     
      // RLDRAM interface signals
      .RLD2_CK_P  ( RLD2_CK_P_C2   ),
      .RLD2_CK_N  ( RLD2_CK_N_C2 ),      
      .RLD2_CS_N  ( RLD2_CS_N_C2  ),
      .RLD2_REF_N ( RLD2_REF_N_C2 ),
      .RLD2_WE_N  ( RLD2_WE_N_C2 ),      
      .RLD2_A     ( RLD2_A_C2  ),
      .RLD2_BA    ( RLD2_BA_C2 ),
      .RLD2_DM    ( RLD2_DM_C2 ),      
      .RLD2_QK_P  ( RLD2_QK_P_C2   ),
      .RLD2_QK_N  ( RLD2_QK_N_C2 ),      
      .RLD2_DK_P  ( RLD2_DK_P_C2   ),
      .RLD2_DK_N  ( RLD2_DK_N_C2 ),      
      .RLD2_QVLD  ( RLD2_QVLD_C2 ),      
      .RLD2_DQ    ( RLD2_DQ_C2 ),
		
		.rldReadData      ( rldReadData[RL_DQ_WIDTH*4-1:RL_DQ_WIDTH*2] ),
		.rldReadDataValid (rldReadDataValid[1]),
		.apConfRdD(apConfRdD[15:8]),
		.rlWdfEmpty(rlWdfEmpty[1]),
		.rlWdfFull(rlWdfFull[1]),
		.rlRdfEmpty(rlRdfEmpty[1]),
		.rlafEmpty(rlafEmpty[1]),
		.rlafFull(rlafFull[1]),
		.rlWdfWrCount(rlWdfWrCount[NUM_OF_DEVS*13-1:13]),   // write data FIFO (wdfifo) write count
		.rlWdfWordCount(rlWdfWordCount[NUM_OF_DEVS*13-1:13]), // write data FIFO (wdfifo) write count
		.rlafWrCount(rlafWrCount[NUM_OF_DEVS*13-1:13]),    // command/address FIFO (rafifo) write count
		.rlafWordCount(rlafWordCount[NUM_OF_DEVS*13-1:13]), 
		
		.apRdfRdEn(apRdfRdEn[1]),
		.apAddr({1'b0,readSigForAdd,6'b0,apAddr}),
		.apValid(apValid),
		.apWriteDM(apWriteDM),
		.apWriteData(apWriteData[RL_DQ_WIDTH*4-1:RL_DQ_WIDTH*2]),
		.apWriteDValid(apWriteDValid),
		.apConfA(apConfA),
		.apConfWrD(apConfWrD[7:0]),
		.apConfRd(apConfRd),
		.apConfWr(apConfWr),
      // observation points
      //.PASS_FAIL  (  ),		
      .dip				   ( dip ),
		.Init_Done(Init_Done[1])
    //  .FPGA3_7SEG			( DISPLAY ),
    //  .DBG_LED				( LED ),
     // .FPGA3_TEST_HDR   ( TEST_HDR )
);



rldFifoAxiArbiter #(.TDATA_WIDTH(TDATA_WIDTH),
                     .TUSER_WIDTH(TUSER_WIDTH),
                     .NUM_QUEUES(NUM_QUEUES), 
                     .QUEUE_ID_WIDTH(QUEUE_ID_WIDTH)) 
                  outarb(
                          .clk(intClk),
                          .reset(~sysReset),
                          .memclk(intClk),
                          .burst_inc(winc_out), 
                          .full(w_almost_full_out), 
                          .read_burst(read_burst),
                          .din_valid(mem_din_valid),
                          .din(mem_din),
                          .din_queue_id(mem_din_queue_id),
                          .mem_queue_empty(mem_rempty),
                          .queue_id(mem_queue_id_read),
                          .dout(din_out),
                          .dout_valid(din_valid_out),
								  .q_read_select(q_read_select),
								  .next_burst_id(next_winc)
                          );

endmodule
