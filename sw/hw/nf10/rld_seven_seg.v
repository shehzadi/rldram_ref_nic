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
// Copyright (c) 2006 Xilinx, Inc. All rights reserved.
//
// This copyright and support notice must be retained as part 
// of this text at all times. 
//*****************************************************************************
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor: Xilinx
// \   \   \/     Version: 1.0
//  \   \         Filename: rld_seven_seg.v
//  /   /         Timestamp: 24 August 2007
// /___/   /\     
// \   \  /  \
//  \___\/\___\
//
//
//	Device:  Virtex-5
//	Purpose: This module generates external signals for LEDs and the 7-segment
//		display on the ML561.  Can be used for Demo or Debug.
//
//*****************************************************************************

`timescale 1ns/100ps

module  rld_seven_seg  (
   clk,
   rst_n,

   init_done,
   valid,
   PASS_FAIL,

   seven_seg_n,
   seven_seg_dp_n,
   LED,

   // chipscope debug ports
   cs_io,
   dip
);
		
parameter READ_DIV_CNT_WIDTH = 28;		
		
   input        clk, rst_n;
   input        valid;
   input        init_done;
   input        dip;
   input  [2:0] PASS_FAIL;

   output [6:0] seven_seg_n;
   output       seven_seg_dp_n;
   output [3:0] LED;

   inout [1023:0] cs_io; // for debug


   reg [6:0]      seven_seg_n;
   reg [26:0]     count1, count2;
   reg [READ_DIV_CNT_WIDTH-1:0] read_div_cnt;
   reg            init_done_reg, pass_reg, error_reg;
   reg            valid_r1;

   wire [3:0] disp_data;

   assign seven_seg_dp_n = 1'b1;

   assign LED[0] = count2[26];	// System Clock
   assign LED[1] = init_done_reg;
   assign LED[2] = pass_reg;
   assign LED[3] = error_reg;

   assign disp_data = read_div_cnt[READ_DIV_CNT_WIDTH-1:READ_DIV_CNT_WIDTH-4];  

	
   // want to produce a slow blinking lights to check system clock
   always @( posedge clk )
   begin
      if ( !rst_n )
         count2 <= ~{27'd0};     // reset
      else
         count2 <= count2 + 1;   // increment
      	
      if ( !rst_n )
         read_div_cnt <= 0;
      else
         if ( valid_r1 )
            read_div_cnt <= read_div_cnt + 1;
         else
            read_div_cnt <= read_div_cnt;
   end


   // register outputs for LEDs
   always @( posedge clk )
   begin
      if ( !rst_n )
      begin
         init_done_reg <= 1'b0;
         pass_reg      <= 1'b0;
         error_reg     <= 1'b0;
         valid_r1      <= 1'b0;
      end
      else
      begin
         init_done_reg <= init_done;
         valid_r1      <= valid;
      			
         if ( init_done )   // if not in reset state
         begin
            error_reg <= PASS_FAIL[2] && ~PASS_FAIL[1];
            pass_reg  <= ~PASS_FAIL[2] && PASS_FAIL[1];
         end
         else
         begin
            error_reg <= error_reg;
            pass_reg  <= pass_reg;
         end
      end
   end


// output 7-Seg display
always @( posedge clk )
begin
   if ( !rst_n )
      seven_seg_n <= 7'b111_1111;   // clear the display
   else
      if ( ~init_done_reg )
         seven_seg_n <= 7'b1000110;   // "C" for Calibration
      else
         if ( error_reg )
            seven_seg_n <= 7'b0111111;   // "-" for Error
         else 
            //if ( dip )
		begin   // update the display
		   case ( disp_data )
		      4'h0 :   seven_seg_n <= 7'b100_0000;
		      4'h1 :   seven_seg_n <= 7'b111_1001;
		      4'h2 :   seven_seg_n <= 7'b010_0100;
		      4'h3 :   seven_seg_n <= 7'b011_0000;
		      4'h4 :   seven_seg_n <= 7'b001_1001;
		      4'h5 :   seven_seg_n <= 7'b001_0010;
		      4'h6 :   seven_seg_n <= 7'b000_0010;
		      4'h7 :   seven_seg_n <= 7'b111_1000;
		      4'h8 :   seven_seg_n <= 7'b000_0000;
		      4'h9 :   seven_seg_n <= 7'b001_1000;
		      4'hA :   seven_seg_n <= 7'b000_1000;
		      4'hB :   seven_seg_n <= 7'b000_0011;
		      4'hC :   seven_seg_n <= 7'b100_0110;
		      4'hD :   seven_seg_n <= 7'b010_0001;
		      4'hE :   seven_seg_n <= 7'b000_0110;
		      4'hF :   seven_seg_n <= 7'b000_1110;
		      default: seven_seg_n <= 7'b111_1111;
		   endcase
		end
             //else   // output error signals
             //begin
             //   seven_seg_n <= {1'b0, ~cs_io[44], ~cs_io[46], 1'b1, ~cs_io[47], ~cs_io[45], 1'b1};
             //end
end


endmodule
