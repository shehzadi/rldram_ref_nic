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
// Copyright (c) 2006-2007 Xilinx, Inc. All rights reserved.
//
// This copyright and support notice must be retained as part 
// of this text at all times. 
//*****************************************************************************
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor: Xilinx
// \   \   \/     Version: 1.1
//  \   \         Filename: rld_mem_interface_top.v
//  /   /         Timestamp: 24 August 2007
// /___/   /\     
// \   \  /  \
//  \___\/\___\
//
//
//	Device:  Virtex-5
//	Purpose: Top level of the RLD2 Memory Interface, ready for ML561.
//		Instantiates the main design along with the infastructure 
//		for clocks and resets.  It also includes Chipscope modules.
// Revision History:
//   Rev 1.0 - initial release
//   Rev 1.1 - Pass RL_CK_FREQ parameter to sub-modules, changed default mode to 
//             config 3, Memory DLL enabled by default. 
//*****************************************************************************

`timescale 1ns/100ps

module  rld_mem_interface_top  (
   refClk_p,
   refClk_n,
   sysClk_p,
   sysClk_n,
   sysReset,
   dip,
   clk33,

   FPGA3_7SEG,
   DBG_LED,
   FPGA3_TEST_HDR,

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
	issueCalibration, 
   apRdfRdEn, 
   rldReadData, 
   rldReadDataValid, 
   apAddr, 
   apValid, 
   apWriteDM, 
   apWriteData, 
   apWriteDValid, 
   apConfA, 
   apConfWrD, 
   apConfRd, 
   apConfWr, 
   apConfRdD, 
   rlWdfEmpty, 
   rlWdfFull, 
   rlRdfEmpty, 
   rlafEmpty, 
   rlafFull, 
   rlWdfWrCount, 
   rlWdfWordCount, 
   rlafWrCount, 
   rlafWordCount,
	Init_Done
	

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

   // System signals and debug
   input            refClk_p;
   input            refClk_n;
   input            sysClk_p;
   input            sysClk_n;
   input            sysReset;
   input            dip;
   input            clk33;

   output [7:0]     FPGA3_7SEG;
   output [3:0]     DBG_LED;
   output [7:0]     FPGA3_TEST_HDR;

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

   // output [2:0]     PASS_FAIL;
	
   input                         issueCalibration;


   // application interface signals
   input                         apRdfRdEn;
   output [(2*RL_DQ_WIDTH)-1:0]  rldReadData;
   output                        rldReadDataValid;

   input  [APP_AD_WIDTH-1:0]     apAddr;
   input                         apValid;
   input  [(2*NUM_OF_DEVS)-1:0]  apWriteDM;
   input  [(2*RL_DQ_WIDTH)-1:0]  apWriteData;
   input                         apWriteDValid;
   input  [3:0]                  apConfA;
   input  [7:0]                  apConfWrD;
   input                         apConfRd;
   input                         apConfWr;

   output [7:0]                  apConfRdD;
   output                        rlWdfEmpty;
   output                        rlWdfFull;
   output                        rlRdfEmpty;
   output                        rlafEmpty;
   output                        rlafFull;
   output [12:0]                 rlWdfWrCount;   // write data FIFO (wdfifo) write count
   output [12:0]                 rlWdfWordCount; // write data FIFO (wdfifo) write count
   output [12:0]                 rlafWrCount;    // command/address FIFO (rafifo) write count
   output [12:0]                 rlafWordCount;  // command/address FIFO (rafifo) word count
   output Init_Done;
  

   // wires 
   wire           clk;
   wire           clk90;
   wire           sysClk;
   wire           refClk;
   wire           sync_system_reset;
   wire           dcmLocked;
   wire           calibration_done;
   wire           rstConfig;
   wire           Init_Done;
   wire           Init_Done_270;
   wire           rstHard;
   wire           rstHard_90;
   wire           rstHard_180;
   wire           rstHard_270;
   wire           rstHard_refClk;
   wire [3:0]               rstCmd;
   wire [DEV_AD_WIDTH-1:0]  rstAd;
   wire [DEV_BA_WIDTH-1:0]  rstBa;
   wire [17:0]    confMReg;
   wire           issueMRS;
   wire           mrsDone_o;
   wire [2:0]     PASS_FAIL;

   // chipscope specific signals
   wire [35:0]    cs_control0;
   wire           cs_clk0;
   wire [255:0]   cs_data0;
   wire [15:0]    cs_trig0;
   wire [1023:0]  cs_io;


   // assign debug signals to test header on ML561
   assign FPGA3_TEST_HDR = { DBG_LED[3], PASS_FAIL[2], dcmLocked, Init_Done,
                             dip, rstHard, refClk, clk };

   // -----------------------------------------------------------------------------
   // rld_infrastructure_top
   //   Adds clock and reset signals
   // -----------------------------------------------------------------------------
   rld_infrastructure_top  #(
      .SIMULATION_ONLY    ( SIMULATION_ONLY ),     // if set, it shortens the wait time
      .RL_DQ_WIDTH        ( RL_DQ_WIDTH ),
      .DEV_DQ_WIDTH       ( DEV_DQ_WIDTH ),
      .DEV_AD_WIDTH       ( DEV_AD_WIDTH ),
      .DEV_BA_WIDTH       ( DEV_BA_WIDTH ),
      .DUPLICATE_CONTROLS ( DUPLICATE_CONTROLS ),
      // specific to FPGA/memory devices and capture method
      .RL_IO_TYPE         ( RL_IO_TYPE ),
      .DEVICE_ARCH        ( DEVICE_ARCH ),
      .CAPTURE_METHOD     ( CAPTURE_METHOD )
   )
   infrastructure_top0  (
      .sysClk_p          ( sysClk_p ),
      .sysClk_n          ( sysClk_n ),
      .refClk_p          ( refClk_p ),
      .refClk_n          ( refClk_n ),
      .sysReset          ( sysReset ),     // system reset input, acive low, asynchronous
      .clk33             ( clk33 ),

      .confMReg          ( confMReg ),
      .issueMRS          ( issueMRS ),
      .calibration_done  ( calibration_done ),

      .sysClk            ( sysClk ),
      .clk               ( clk ),          // global clock to all modules 
      .clk90             ( clk90 ),
      .refClk            ( refClk ),
      .dcmlocked         ( dcmLocked ),

      .sync_system_reset ( sync_system_reset ),  // system reset, synchronized to clk
      .rstHard           ( rstHard ),
      .rstHard_90        ( rstHard_90 ),
      .rstHard_180       ( rstHard_180 ),
      .rstHard_270       ( rstHard_270 ),
      .rstHard_refClk    ( rstHard_refClk ),
      .rstConfig         ( rstConfig ),

      .Init_Done         ( Init_Done ),
      .Init_Done_270     ( Init_Done_270 ),
      .mrsDone_o         ( mrsDone_o ),

      .rstCmd            ( rstCmd ),
      .rstAd             ( rstAd ),
      .rstBa             ( rstBa )
);


   // -----------------------------------------------------------------------------
   // rld_main
   //   RLDRAM-2 Controller and User Application
   // -----------------------------------------------------------------------------
   rld_main  #(
      .RL_DQ_WIDTH            ( RL_DQ_WIDTH ),
      .DEV_DQ_WIDTH           ( DEV_DQ_WIDTH ),
      .DEV_AD_WIDTH           ( DEV_AD_WIDTH ),
      .DEV_BA_WIDTH           ( DEV_BA_WIDTH ),
      .DUPLICATE_CONTROLS     ( DUPLICATE_CONTROLS ),
      // specific to rld_conf 
      .RL_MRS_CONF            ( RL_MRS_CONF ),
      .RL_MRS_BURST_LENGTH    ( RL_MRS_BURST_LENGTH ),
      .RL_MRS_ADDR_MUX        ( RL_MRS_ADDR_MUX ),
      .RL_MRS_DLL_RESET       ( RL_MRS_DLL_RESET ),
      .RL_MRS_IMPEDANCE_MATCH ( RL_MRS_IMPEDANCE_MATCH ),
      .RL_MRS_ODT             ( RL_MRS_ODT ),
      // specific to FPGA/memory devices and capture method
      .RL_IO_TYPE             ( RL_IO_TYPE ),
      .DEVICE_ARCH            ( DEVICE_ARCH ),
      .CAPTURE_METHOD         ( CAPTURE_METHOD ),
      .CAL_ADDRESS            ( CAL_ADDRESS )
   )
   main0  (
      .clk               ( clk ),
      .clk90             ( clk90 ),
      .refClk            ( refClk ),
      .rstHard           ( rstHard ),
      .rstHard_90        ( rstHard_90 ),
      .rstHard_180       ( rstHard_180 ),
      .rstHard_270       ( rstHard_270 ),
      .rstHard_refClk    ( rstHard_refClk ),
      .sync_sysReset     ( sync_system_reset ),
      .dcmLocked         ( dcmLocked ),

      .calibration_done  ( calibration_done ),
      .rstConfig         ( rstConfig ),
      .rstCmd            ( rstCmd ),
      .rstAd             ( rstAd ),
      .rstBa             ( rstBa ),
      .confMReg          ( confMReg ),
      .Init_Done         ( Init_Done ),
      .issueMRS          ( issueMRS ),
      .mrsDone_o         ( mrsDone_o ),

      .PASS_FAIL         ( PASS_FAIL ),

      .rld2_ck_p         ( RLD2_CK_P ),
      .rld2_ck_n         ( RLD2_CK_N ),
      .rld2_dk_p         ( RLD2_DK_P ),
      .rld2_dk_n         ( RLD2_DK_N ),
      .rld2_qk_p         ( RLD2_QK_P ),
      .rld2_qk_n         ( RLD2_QK_N ),
      .rld2_a            ( RLD2_A ),
      .rld2_ba           ( RLD2_BA ),
      .rld2_cs_n         ( RLD2_CS_N ),
      .rld2_we_n         ( RLD2_WE_N ),
      .rld2_ref_n        ( RLD2_REF_N ),
      .rld2_dm           ( RLD2_DM ),
      .rld2_dq           ( RLD2_DQ ),
      .rld2_qvld         ( RLD2_QVLD ),
   
      .cs_io             ( cs_io ),
		.issueCalibration(issueCalibration), 
		 .apRdfRdEn(apRdfRdEn), 
		 .rldReadData(rldReadData), 
		 .rldReadDataValid(rldReadDataValid), 
		 .apAddr(apAddr), 
		 .apValid(apValid), 
		 .apWriteDM(apWriteDM), 
		 .apWriteData(apWriteData), 
		 .apWriteDValid(apWriteDValid), 
		 .apConfA(apConfA), 
		 .apConfWrD(apConfWrD), 
		 .apConfRd(apConfRd), 
		 .apConfWr(apConfWr), 
		 .apConfRdD(apConfRdD), 
		 .rlWdfEmpty(rlWdfEmpty), 
		 .rlWdfFull(rlWdfFull), 
		 .rlRdfEmpty(rlRdfEmpty), 
		 .rlafEmpty(rlafEmpty), 
		 .rlafFull(rlafFull), 
		 .rlWdfWrCount(rlWdfWrCount), 
		 .rlWdfWordCount(rlWdfWordCount), 
		 .rlafWrCount(rlafWrCount), 
		 .rlafWordCount(rlafWordCount)
   );


   // -----------------------------------------------------------------------------
   // rld_seven_seg
   //   - module used to control ML561 LEDs
   //   - useful for debug/demo	
   // -----------------------------------------------------------------------------
   rld_seven_seg  seven_seg0  (
      .clk            ( clk ),
      .rst_n          ( ~sync_system_reset ),
   
      .init_done      ( Init_Done ),
      .valid          ( cs_io[90] ),
      .PASS_FAIL      ( PASS_FAIL ),
   
      .seven_seg_n    ( FPGA3_7SEG[6:0] ),
      .seven_seg_dp_n ( FPGA3_7SEG[7] ),
      .LED            ( DBG_LED ),
   
      .cs_io          ( cs_io ),
      .dip            ( dip )
   ); 


   // -----------------------------------------------------------------------------
   // Chipscope module instantiations
   // -----------------------------------------------------------------------------
   /*icon  i_icon  (
      .control0  ( cs_control0 )
   );

   ila256  i_ila0  (
      .control ( cs_control0 ),
      .clk     ( cs_clk0 ),
      .data    ( cs_data0 ),
      .trig0   ( cs_trig0 )
   ); */

   assign cs_clk0  = clk;
   //assign cs_clk0  = ~clk90; //use clk270 for checking phy signals
   assign cs_data0 = { cs_io[255:0] };
   

   assign cs_trig0 = { 10'b0,
                       PASS_FAIL[2],    //Error Signal
                       cs_io[111:100],  // f_cs, data cal SM for debug
                       cs_io[95:93]     // ref[2], we[1], cs[0]
                      };

endmodule



// -----------------------------------------------------------------------------
// Define "icon" module for Chipscope
// -----------------------------------------------------------------------------
module  icon  (
   control0
);

   output [35:0]  control0;

endmodule



// -----------------------------------------------------------------------------
// Define "ila256" module for Chipscope
// -----------------------------------------------------------------------------
module  ila256  (
   control,
   clk,
   data,
   trig0
);

   input  [35:0]  control;
   input          clk;
   input  [255:0] data;
   input  [15:0]  trig0;

endmodule


