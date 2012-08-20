//*****************************************************************************
// DISCLAIMER OF LIABILITY
// 
// This text/file contains proprietary, confidential
// information of Xilinx, Inc., is distributed under license
// from Xilinx, Inc., and may be used, copied and/or
// disclosed only pursuant to the terms of a valid license
// agreement with Xilinx, Inc. Xilinx hereby grants you a 
// license to use this text/file solely for design, simulation, 
// implementation and creation of design files limited 
// to Xilinx devices or technologies. Use with non-Xilinx 
// devices or technologies is expressly prohibited and 
// immediately terminates your license unless covered by
// a separate agreement.
//
// Xilinx is providing this design, code, or information 
// "as-is" solely for use in developing programs and 
// solutions for Xilinx devices, with no obligation on the 
// part of Xilinx to provide support. By providing this design, 
// code, or information as one possible implementation of 
// this feature, application or standard, Xilinx is making no 
// representation that this implementation is free from any 
// claims of infringement. You are responsible for 
// obtaining any rights you may require for your implementation. 
// Xilinx expressly disclaims any warranty whatsoever with 
// respect to the adequacy of the implementation, including 
// but not limited to any warranties or representations that this
// implementation is free from claims of infringement, implied 
// warranties of merchantability or fitness for a particular 
// purpose.
//
// Xilinx products are not intended for use in life support
// appliances, devices, or systems. Use in such applications is
// expressly prohibited.
//
// Any modifications that are made to the Source Code are 
// done at the user's sole risk and will be unsupported.
//
// Copyright (c) 2006-2008 Xilinx, Inc. All rights reserved.
//
// This copyright and support notice must be retained as part 
// of this text at all times. 
//*****************************************************************************
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor: Xilinx
// \   \   \/     Version: 1.2
//  \   \         Filename: ext_test_bench.v
//  /   /         Timestamp: 14 March 2008
// /___/   /\     
// \   \  /  \
//  \___\/\___\
//
//
//	Device:  Virtex-4 and Virtex-5
//	Purpose: Simulation test bench
// Revision History:
//   Rev 1.0 - initial release
//   Rev 1.1 - Changed the simulation_only parameter to default to false, replaced
//		         the Micron model, changed the default to config3 for 333MHz operation,
//             enable the DLL by default, changed clock frequency parameter to 
//             clock period
//   Rev 1.2 - Changed the default frequency to 250MHz
//*****************************************************************************

`timescale 1ns/1ps

`define BOARD_SKEW #0.500 // put a 500 ps delay on the QK lines between FPGA and RAMs 

module  copytestbench  ();

// parameter definitions
   parameter SIMULATION_ONLY = 1'b0;  // if set (1'b1), it shortens the wait time but Micron model requires that time
   //
   parameter RL_DQ_WIDTH     = 72;
   parameter DEV_DQ_WIDTH    = 36;  // data width of the memory device
   parameter NUM_OF_DEVS     = RL_DQ_WIDTH/DEV_DQ_WIDTH;  // number of memory devices
   parameter NUM_OF_DKS      = (DEV_DQ_WIDTH == 36) ? 2*NUM_OF_DEVS : NUM_OF_DEVS;
   parameter DEV_AD_WIDTH    = 20;  // address width of the memory device
   parameter DEV_BA_WIDTH    = 3;   // bank address width of the memory device
   parameter APP_AD_WIDTH    = 1+1+1+DEV_AD_WIDTH+DEV_BA_WIDTH;
   parameter DUPLICATE_CONTROLS = 1'b0;  // Duplicate the ports for A, BA, WE# and REF#
   parameter RL_CK_PERIOD  = 16'd3003;     // CK clock period of the RLDRAM in ps
   // MRS (Mode Register Set command) parameters   
   parameter RL_MRS_CONF            = 3'b011;  // Config3   // Config1=3'b001  Config2=3'b010  Config3=3'b011
   parameter RL_MRS_BURST_LENGTH    = 2'b01;   // BL4       // BL2=2'b00  BL4=2'b01  BL8=2'b10 (BL8 unsupported)
   parameter RL_MRS_ADDR_MUX        = 1'b0;    // non-mux   // non-mux address (default)=1'b0;  multiplexed address=1'b1
   parameter RL_MRS_DLL_RESET       = 1'b1;    // 1'b0: DLL reset, 1'b1: DLL enabled
   parameter RL_MRS_IMPEDANCE_MATCH = 1'b1;    // 1'b0: internal 50ohms output buffer impedance, 1'b1: external 
   parameter RL_MRS_ODT             = 1'b0;    // 1'b0: disable term;  1'b1: enable term
   // specific to FPGA/memory devices and capture method
   parameter RL_IO_TYPE     = 2'b00;    // CIO  // CIO=2'b00  SIO_CIO_HYBRID=2'b01  SIO=2'b10
   parameter DEVICE_ARCH    = 2'b01;    // V5   // Virtex4=2'b00  Virtex5=2'b01
   parameter CAPTURE_METHOD = 2'b01;    // SerDes   // Direct Clocking=2'b00  SerDes=2'b01
   parameter CAL_ADDRESS    = {DEV_AD_WIDTH{1'b0}}; //saved location to perform calibration

 integer i;

    wire [63:0] header_word_0 = 64'hEFBEFECAFECAFECA; // Destination MAC
    wire [63:0] header_word_1 = 64'h00000008EFBEEFBE; // Source MAC + EtherType

    localparam HEADER_0 = 0;
    localparam HEADER_1 = 1;
    localparam PAYLOAD = 2;
    localparam DEAD = 3;

    reg [2:0] state, state_next;
    reg [7:0] counter, counter_next;
  reg 		RESET;
  reg 		intClk;
  
    reg [255:0] tdata[4:0];
    reg [4:0] tlast;
    wire[4:0] tready;
	 reg [31:0] tstrb[4:0];

   reg tvalid_0 = 0;
   reg tvalid_1 = 0;
   reg tvalid_2 = 0;
   reg tvalid_3 = 0;
   reg tvalid_4 = 0;

    wire tvalid_out_0;
    wire tvalid_out_1;
    wire tvalid_out_2;
    wire tvalid_out_3;

    reg tready_out_0 = 0;
    reg tready_out_1 = 0;
    reg tready_out_2 = 0;
    reg tready_out_3 = 0;

    reg [3:0] random = 0;
  
  reg  [1:0] clk_select;
   
  reg 		intRefClk;
  reg 		dip;
  reg     clk33;
	
  wire        CLK;
  wire        RefClk;  // 200MHz differential reference clock 
  wire [7:0]  DISPLAY;
  wire [3:0]  LED;
  wire [7:0]  TEST_HDR;

  wire [1:0]  RC_CK;
  wire [1:0]  RC_CK_N;
  wire [1:0]	RC_CS_N;
  wire 	  		RC_REF_N;
  wire 	  		RC_WE_N;
  wire [DEV_AD_WIDTH-1:0] 	RC_A;
  wire [DEV_BA_WIDTH-1:0] 	RC_BA;
  wire [1:0] 	RC_DM;
  wire [3:0]	RL_QK;
  wire [3:0] 	RL_QK_N;
  wire [1:0]	RL_QVLD;
  wire [RL_DQ_WIDTH-1:0] 	DQ;

  wire [NUM_OF_DKS-1:0]  RC_DK;
  wire [NUM_OF_DKS-1:0]  RC_DK_N;
  
  
  wire [1:0]  RC_CK_C2;
  wire [1:0]  RC_CK_N_C2;
  wire [1:0]	RC_CS_N_C2;
  wire 	  		RC_REF_N_C2;
  wire 	  		RC_WE_N_C2;
  wire [DEV_AD_WIDTH-1:0] 	RC_A_C2;
  wire [DEV_BA_WIDTH-1:0] 	RC_BA_C2;
  wire [1:0] 	RC_DM_C2;
  wire [3:0]	RL_QK_C2;
  wire [3:0] 	RL_QK_N_C2;
  wire [1:0]	RL_QVLD_C2;
  wire [RL_DQ_WIDTH-1:0] 	DQ_C2;
  reg [63:0] tstrb_temp;

  wire [NUM_OF_DKS-1:0]  RC_DK_C2;
  wire [NUM_OF_DKS-1:0]  RC_DK_N_C2;
  
  wire [3:0] 	bRL_QK;
  wire [3:0] 	bRL_QK_N;
  wire [3:0] 	bRL_QK_C2;
  wire [3:0] 	bRL_QK_N_C2;
	
  assign 	  CLK     = intClk;
  assign 	  RefClk  = intRefClk;

  assign 	  `BOARD_SKEW RL_QK[3:0]   = bRL_QK[3:0];
  assign 	  `BOARD_SKEW RL_QK_N[3:0] = bRL_QK_N[3:0];
  assign 	  `BOARD_SKEW RL_QK_C2[3:0]   = bRL_QK_C2[3:0];
  assign 	  `BOARD_SKEW RL_QK_N_C2[3:0] = bRL_QK_N_C2[3:0];
  
   

   // Generate system clock
   initial intClk = 0;
   always begin
    //#1.250 intClk = ~intClk;    //400MHz
    //#1.429 intClk = ~intClk;    //350MHz
    //#1.501 intClk = ~intClk;    //333MHz
    //#1.667 intClk = ~intClk;    //300MHz
    #2.000 intClk = ~intClk;    //250MHz
    //#2.500 intClk = ~intClk;    //200MHz
    //#3.333 intClk = ~intClk;    //150MHz
   end

   // Generate 200MHz reference clock
   initial intRefClk = 0;
   always begin
      #2.500 intRefClk = ~intRefClk;
   end
  
  //generate 33MHz test clock
  initial 
  clk33 =0;
   always begin
      #30.30 clk33 = ~clk33;
   end

   // Generate Reset
   initial begin
      clk_select = 2'b00;
      RESET = 0; dip = 0;           // reset on board is active low
      #1000 RESET = 1; 
   end


    always @(*) begin
state_next = state;
tdata[0] = 256'b0;
tdata[1] = 256'b0;
tdata[2] = 256'b0;
tdata[3] = 256'b0;
tdata[4] = 256'b0;
tlast[0] = 1'b0;
tlast[1] = 1'b0;
tlast[2] = 1'b0;
tlast[3] = 1'b0;
tlast[4] = 1'b0;
tstrb[0] = 32'b0;
tstrb[1] = 32'b0;
tstrb[2] = 32'b0;
tstrb[3] = 32'b0;
counter_next = counter;

case(state)
HEADER_0: begin
tdata[random] = {4{header_word_0}};
if(tready[random]) begin
state_next = HEADER_1;
end

tstrb[random] = 32'hffffffff;
if (random == 0)
tvalid_0 = 1;
else if (random == 1)
tvalid_1 = 1;
else if (random == 2)
tvalid_2 = 1;
else if (random == 3)
tvalid_3 = 1;
else if (random == 4)
tvalid_4 = 1;
end
HEADER_1: begin
tstrb[random] = 32'hffffffff;
tdata[random] = {4{header_word_1}};
if(tready[random]) begin
state_next = PAYLOAD;
end
end
PAYLOAD: begin
tdata[random] = {32{counter}};
tstrb[random] = tstrb_temp[63:32];
if(tready[random]) begin
counter_next = counter + 1'b1;
if(counter == 8'hEF) begin
state_next = DEAD;
counter_next = 8'b0;
tlast[random] = 1'b1;
end
end
end

DEAD: begin

counter_next = counter + 1'b1;
tlast[random] = 1'b0;
tvalid_0 = 0;
tvalid_1 = 0;
tvalid_2 = 0;
tvalid_3 = 0;
tvalid_4 = 0;
tstrb[0] = 32'b0;
tstrb[1] = 32'b0;
tstrb[2] = 32'b0;
tstrb[3] = 32'b0;
if(counter[7]==1'b1) begin
counter_next = 8'b0;
random = 3;//$random % 5;
state_next = HEADER_0;
end
end
endcase
end

always @(posedge CLK) begin
if(~RESET) begin
state <= HEADER_0;
counter <= 8'b0;
end
else begin
state <= state_next;
counter <= counter_next;
if(counter[5:0]>6'd32)
tstrb_temp <= 64'h00000000ffffffff<<32;
else
tstrb_temp <= 64'h00000000ffffffff<<counter[5:0];
end
end

always #211800
begin
tready_out_0 = 1'b1;
end

always #211850
begin
tready_out_3 = 1'b1;
end
// =============================================================================
// V5 implementation
// =============================================================================

// RLDRAM-2 Controller and User Application			     
 /* rld_mem_interface_top  #(
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
      .sysReset ( RESET   ),
      .sysClk_p ( CLK     ),
      .sysClk_n ( ~CLK    ),
      .refClk_p ( RefClk  ),    // 200MHz differential reference clock
		.refClk_n ( ~RefClk ),
      .clk33    ( clk33 ),
     
      // RLDRAM interface signals
      .RLD2_CK_P  ( RC_CK   ),
      .RLD2_CK_N  ( RC_CK_N ),      
      .RLD2_CS_N  ( RC_CS_N  ),
      .RLD2_REF_N ( RC_REF_N ),
      .RLD2_WE_N  ( RC_WE_N  ),      
      .RLD2_A     ( RC_A  ),
      .RLD2_BA    ( RC_BA ),
      .RLD2_DM    ( RC_DM ),      
      .RLD2_QK_P  ( RL_QK   ),
      .RLD2_QK_N  ( RL_QK_N ),      
      .RLD2_DK_P  ( RC_DK   ),
      .RLD2_DK_N  ( RC_DK_N ),      
      .RLD2_QVLD  ( RL_QVLD ),      
      .RLD2_DQ    ( DQ ),
		
      // observation points
      //.PASS_FAIL  (  ),		
      .dip				   ( dip ),
      .FPGA3_7SEG			( DISPLAY ),
      .DBG_LED				( LED ),
      .FPGA3_TEST_HDR   ( TEST_HDR )
);*/
rldram_top_test_module  #(
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
   amcversion  (
      // globals
      .sysReset ( RESET   ),
      .sysClk_p ( CLK     ),
		.intClk	 ( intClk ),
      .sysClk_n ( ~CLK    ),
      .refClk_p ( RefClk  ),    // 200MHz differential reference clock
		.refClk_n ( ~RefClk ),
     // .clk33    ( clk33 ),
     
	   .s_axis_0_tdata(tdata[0]),
		.s_axis_0_tstrb(tstrb[0]),
		.s_axis_0_tuser(128'b0),
		.s_axis_0_tvalid(tvalid_0),
		.s_axis_0_tready(tready[0]),
		.s_axis_0_tlast(tlast[0]),

		.s_axis_1_tdata(tdata[1]),
		.s_axis_1_tstrb(tstrb[0]),
		.s_axis_1_tuser(128'b0),
		.s_axis_1_tvalid(tvalid_1),
		.s_axis_1_tready(tready[1]),
		.s_axis_1_tlast(tlast[1]),

		.s_axis_2_tdata(tdata[2]),
		.s_axis_2_tstrb(tstrb[0]),
		.s_axis_2_tuser(128'b0),
		.s_axis_2_tvalid(tvalid_2),
		.s_axis_2_tready(tready[2]),
		.s_axis_2_tlast(tlast[2]),

		.s_axis_3_tdata(tdata[3]),
		.s_axis_3_tstrb(tstrb[0]),
		.s_axis_3_tuser(128'b0),
		.s_axis_3_tvalid(tvalid_3),
		.s_axis_3_tready(tready[3]),
		.s_axis_3_tlast(tlast[3]),


		.m_axis_0_tvalid(tvalid_out_0),
		.m_axis_0_tready(tready_out_0),
		.m_axis_1_tvalid(tvalid_out_1),
		.m_axis_1_tready(tready_out_1),

		.m_axis_2_tvalid(tvalid_out_2),
		.m_axis_2_tready(tready_out_2),

		.m_axis_3_tvalid(tvalid_out_3),
		.m_axis_3_tready(tready_out_3),
	  
	  
      // RLDRAM interface signals
      .RLD2_CK_P  ( RC_CK   ),
      .RLD2_CK_N  ( RC_CK_N ),      
      .RLD2_CS_N  ( RC_CS_N  ),
      .RLD2_REF_N ( RC_REF_N ),
      .RLD2_WE_N  ( RC_WE_N  ),      
      .RLD2_A     ( RC_A  ),
      .RLD2_BA    ( RC_BA ),
      .RLD2_DM    ( RC_DM ),      
      .RLD2_QK_P  ( RL_QK   ),
      .RLD2_QK_N  ( RL_QK_N ),      
      .RLD2_DK_P  ( RC_DK   ),
      .RLD2_DK_N  ( RC_DK_N ),      
      .RLD2_QVLD  ( RL_QVLD ),      
      .RLD2_DQ    ( DQ ),
		
		.RLD2_CK_P_C2  ( RC_CK_C2   ),
      .RLD2_CK_N_C2  ( RC_CK_N_C2 ),      
      .RLD2_CS_N_C2 ( RC_CS_N_C2  ),
      .RLD2_REF_N_C2 ( RC_REF_N_C2 ),
      .RLD2_WE_N_C2  ( RC_WE_N_C2  ),      
      .RLD2_A_C2    ( RC_A_C2  ),
      .RLD2_BA_C2    ( RC_BA_C2 ),
      .RLD2_DM_C2    ( RC_DM_C2 ),      
      .RLD2_QK_P_C2  ( RL_QK_C2   ),
      .RLD2_QK_N_C2  ( RL_QK_N_C2 ),      
      .RLD2_DK_P_C2  ( RC_DK_C2   ),
      .RLD2_DK_N_C2  ( RC_DK_N_C2 ),      
      .RLD2_QVLD_C2  ( RL_QVLD_C2 ),      
      .RLD2_DQ_C2    ( DQ_C2 ),
      // observation points
      //.PASS_FAIL  (  ),		
      .dip				   ( dip )
   //   .FPGA3_7SEG			( DISPLAY ),
   //   .DBG_LED				( LED ),
    //  .FPGA3_TEST_HDR   ( TEST_HDR )
);
		  
// RLDRAM-II memory models
// needs to be downloaded from Micron's website (not included in XAPP852)	
rldram2 ram0 (
    .ck     ( RC_CK[0] ),
    .ck_n   ( RC_CK_N[0] ),
    .cs_n   ( RC_CS_N[0] ),
    .we_n   ( RC_WE_N ),
    .ref_n  ( RC_REF_N ),
    .ba     ( RC_BA[2:0] ),
    .a      ( RC_A[19:0] ),
    .dm     ( RC_DM[0] ),
    .dk     ( RC_DK[NUM_OF_DKS/2-1:0] ),
    .dk_n   ( RC_DK_N[NUM_OF_DKS/2-1:0] ),
    .dq     ( DQ[RL_DQ_WIDTH/2-1:0] ),
    .qk     ( bRL_QK[2*NUM_OF_DEVS/2-1:0] ),
    .qk_n   ( bRL_QK_N[2*NUM_OF_DEVS/2-1:0] ),
    .qvld   ( RL_QVLD[0] ),
// JTAG PORTS
    .tck    (1'b0),
    .tms    (1'b0),
    .tdi    (1'b0),
    .tdo    (  )
);
    
rldram2 ram1 (
    .ck     ( RC_CK[1] ),
    .ck_n   ( RC_CK_N[1] ),
    .cs_n   ( RC_CS_N[1] ),
    .we_n   ( RC_WE_N ),
    .ref_n  ( RC_REF_N ),
    .ba     ( RC_BA[2:0] ),
    .a      ( RC_A[19:0] ),
    .dm     ( RC_DM[1] ),
    .dk     ( RC_DK[NUM_OF_DKS-1:NUM_OF_DKS/2] ),
    .dk_n   ( RC_DK_N[NUM_OF_DKS-1:NUM_OF_DKS/2] ),
    .dq     ( DQ[RL_DQ_WIDTH-1:RL_DQ_WIDTH/2] ),
    .qk     ( bRL_QK[2*NUM_OF_DEVS-1:2*NUM_OF_DEVS/2] ),
    .qk_n   ( bRL_QK_N[2*NUM_OF_DEVS-1:2*NUM_OF_DEVS/2] ),
    .qvld   ( RL_QVLD[1] ),
// JTAG PORTS
    .tck    (1'b0),
    .tms    (1'b0),
    .tdi    (1'b0),
    .tdo    (  )
); 
rldram2 ram2 (
    .ck     ( RC_CK_C2[0] ),
    .ck_n   ( RC_CK_N_C2[0] ),
    .cs_n   ( RC_CS_N_C2[0] ),
    .we_n   ( RC_WE_N_C2 ),
    .ref_n  ( RC_REF_N_C2 ),
    .ba     ( RC_BA_C2[2:0] ),
    .a      ( RC_A_C2[19:0] ),
    .dm     ( RC_DM_C2[0] ),
    .dk     ( RC_DK_C2[NUM_OF_DKS/2-1:0] ),
    .dk_n   ( RC_DK_N_C2[NUM_OF_DKS/2-1:0] ),
    .dq     ( DQ_C2[RL_DQ_WIDTH/2-1:0] ),
    .qk     ( bRL_QK_C2[2*NUM_OF_DEVS/2-1:0] ),
    .qk_n   ( bRL_QK_N_C2[2*NUM_OF_DEVS/2-1:0] ),
    .qvld   ( RL_QVLD_C2[0] ),
// JTAG PORTS
    .tck    (1'b0),
    .tms    (1'b0),
    .tdi    (1'b0),
    .tdo    (  )
);
    
rldram2 ram3 (
    .ck     ( RC_CK_C2[1] ),
    .ck_n   ( RC_CK_N_C2[1] ),
    .cs_n   ( RC_CS_N_C2[1] ),
    .we_n   ( RC_WE_N_C2 ),
    .ref_n  ( RC_REF_N_C2 ),
    .ba     ( RC_BA_C2[2:0] ),
    .a      ( RC_A_C2[19:0] ),
    .dm     ( RC_DM_C2[1] ),
    .dk     ( RC_DK_C2[NUM_OF_DKS-1:NUM_OF_DKS/2] ),
    .dk_n   ( RC_DK_N_C2[NUM_OF_DKS-1:NUM_OF_DKS/2] ),
    .dq     ( DQ_C2[RL_DQ_WIDTH-1:RL_DQ_WIDTH/2] ),
    .qk     ( bRL_QK_C2[2*NUM_OF_DEVS-1:2*NUM_OF_DEVS/2] ),
    .qk_n   ( bRL_QK_N_C2[2*NUM_OF_DEVS-1:2*NUM_OF_DEVS/2] ),
    .qvld   ( RL_QVLD_C2[1] ),
// JTAG PORTS
    .tck    (1'b0),
    .tms    (1'b0),
    .tdi    (1'b0),
    .tdo    (  )
);

endmodule
