/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        nf10_nic_output_port_lookup.v
 *
 *  Library:
 *        hw/std/pcores/nf10_sram_fifo
 *
 *  Module:
 *        fifomem
 *
 *  Author:
 *        Sam D'Amico
 *
 *  Description:
 *        Arbitrated FIFO to/from memory interface
 *
 *  Copyright notice:
 *        Copyright (C) 2010,2011 The Board of Trustees of The Leland Stanford
 *                                Junior University
 *
 *  Licence:
 *        This file is part of the NetFPGA 10G development base package.
 *
 *        This package is free software: you can redistribute it and/or modify
 *        it under the terms of the GNU Lesser General Public License as
 *        published by the Free Software Foundation, either version 3 of the
 *        License, or (at your option) any later version.
 *
 *        This package is distributed in the hope that it will be useful, but
 *        WITHOUT ANY WARRANTY; without even the implied warranty of
 *        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *        Lesser General Public License for more details.
 *
 *        You should have received a copy of the GNU Lesser General Public
 *        License along with the NetFPGA source package.  If not, see
 *        http://www.gnu.org/licenses/.
 *
 */

//TODO: might want to use almost_full instead of full for memory, as it might
//clip when full and not notify FIFOs.

module rldFifoMem
#(
///////////////////////////////////////////////////////////////////////////////
// Parameter Definitions
///////////////////////////////////////////////////////////////////////////////
  // Width of AXI data bus in bytes
  parameter integer TDATA_WIDTH        = 32,
  parameter integer TUSER_WIDTH        = 128,
  parameter integer NUM_QUEUES         = 4,
  parameter integer QUEUE_ID_WIDTH     = 2,
  parameter integer NUM_MEM_INPUTS     = 4,
  parameter integer NUM_MEM_CHIPS      = 2,
  parameter integer MEM_WIDTH          = 72,
  parameter integer MEM_ADDR_WIDTH     = 18,
  parameter integer MEM_NUM_WORDS      = 262144,
  parameter integer QUEUE_SIZE         = MEM_NUM_WORDS/4
)
(
    input                          clk,
    input                          reset,
    input  [(QUEUE_ID_WIDTH-1):0]   read_queue_id,
    output reg [(QUEUE_ID_WIDTH-1):0]  read_data_queue_id,
    input                          read_data_ready,
    output reg [((8*TDATA_WIDTH+6+16)-1):0]  read_data,
    output                         read_data_valid,
    output reg [(NUM_QUEUES-1):0]  read_empty,
    output reg                     read_burst_state,


    input [(QUEUE_ID_WIDTH-1):0]   write_queue_id,
    input [((8*TDATA_WIDTH+6+16)-1):0]  write_data,
    input                          write_data_valid,
    output reg [(NUM_QUEUES-1):0]  write_full,
    output reg                     next_write_burst_state,
	 
	 output reg [(NUM_MEM_CHIPS-1):0] apRdfRdEn,

    output  [(MEM_WIDTH*NUM_MEM_INPUTS-1):0]       apWriteData,
    
    output reg                         apValid,
	 output [3:0]									apWriteDM,
	 output 										apWriteDValid,
	 output [3:0] apConfA,
	 output [7:0] apConfWrD ,
	 output  apConfRd,
	 output apConfWr,
	 input [(NUM_MEM_CHIPS*8-1):0] apConfRdD,
	 
	 input [(NUM_MEM_CHIPS-1):0] rlWdfEmpty,
	 input [(NUM_MEM_CHIPS-1):0] rlWdfFull,
	 input [(NUM_MEM_CHIPS-1):0] rlRdfEmpty,
	 input [(NUM_MEM_CHIPS-1):0]rlafFull,
	 input [(NUM_MEM_CHIPS*13-1):0] rlWdfWrCount ,
	 input [(NUM_MEM_CHIPS*13-1):0] rlWdfWordCount,
	 input [(NUM_MEM_CHIPS*13-1):0] rlafWrCount,
	 input [(NUM_MEM_CHIPS*13-1):0] rlafWordCount,
	 
	 output issueCalibration,
	 input  InitDone,
	 
    input  [(MEM_WIDTH*NUM_MEM_INPUTS-1):0]       rldReadData,
    input  [(NUM_MEM_CHIPS-1):0]                  rldReadDataValid,
    output reg [(MEM_ADDR_WIDTH-1):0]  apAddr,
    output reg q_write_select,
	 output reg q_read_select,
	 input next_read_true,
	 input next_write_true,
	 output readSigForAdd
);

reg dout_burst_ready;
reg [(MEM_ADDR_WIDTH-3):0] next_num_used[(NUM_QUEUES-1):0];
reg [(MEM_ADDR_WIDTH-3):0] num_used[(NUM_QUEUES-1):0];
reg [(MEM_ADDR_WIDTH-1):0] next_read_addr[(NUM_QUEUES-1):0];
reg [(MEM_ADDR_WIDTH-1):0] read_addr[(NUM_QUEUES-1):0];
reg [(MEM_ADDR_WIDTH-1):0] next_write_addr[(NUM_QUEUES-1):0];
reg [(MEM_ADDR_WIDTH-1):0] write_addr[(NUM_QUEUES-1):0];
reg next_read_data_valid;
//reg read_data_valid_internal;
reg next_read_burst_state;
reg write_burst_state;
reg dout_ready;
reg read_mem_word_valid;
reg [(MEM_ADDR_WIDTH-1):0] next_din_addr;
reg next_din_ready;

reg [(MEM_WIDTH*NUM_MEM_INPUTS-1):0] next_dout;
reg [(MEM_ADDR_WIDTH-1):0] next_dout_addr;
reg                        next_dout_burst_ready;
reg [(QUEUE_ID_WIDTH-1):0] prev_write_queue_id;
reg [(NUM_QUEUES-1):0] next_read_empty;
reg [(NUM_QUEUES-1):0] next_write_full;






//for round robin reads and writes.

reg d_write_select;
reg d_read_select;

reg d_dead_select;
reg q_dead_select;
reg wb_sel_counter;

reg prev_din_ready;
reg prev_dout_burst_ready;

reg [(MEM_WIDTH*NUM_MEM_INPUTS-1):0]       dout;

wire  [(MEM_WIDTH*NUM_MEM_INPUTS-1):0]       din;
wire [(NUM_MEM_CHIPS-1):0]                  din_valid;


wire apValid_read;
reg prev_apValid_read;
reg apValid_write;

reg din_ready;


localparam BURST_STATE_OFF = 1'b0;
localparam BURST_STATE_HALFWAY = 1'b1;

genvar i;

assign apWriteDValid = prev_dout_burst_ready || dout_burst_ready;
assign apWriteDM = 4'd0;
assign apWriteData = next_dout;
assign din = rldReadData;
assign din_valid = rldReadDataValid;
assign apConfA = 4'd0;
assign apConfWrD = 8'd0; 
assign  apConfRd = 1'b0;
assign apConfWr = 1'b0;
assign issueCalibration = 1'b0;
	 

always @(posedge clk)
begin
    if(reset||~InitDone)
    begin
        read_burst_state <= BURST_STATE_OFF;
        write_burst_state <= BURST_STATE_OFF;
        prev_write_queue_id <= {(QUEUE_ID_WIDTH){1'b0}};
        dout <= {(MEM_WIDTH*NUM_MEM_INPUTS){1'b0}};
		  
        apAddr <= {(MEM_ADDR_WIDTH){1'b0}};
        dout_burst_ready <= 1'b0;
		  prev_dout_burst_ready <= 1'b0;
        //read_empty <= {(NUM_QUEUES){1'b1}};
        //write_full <= {(NUM_QUEUES){1'b0}};
        //din_addr <= {(MEM_ADDR_WIDTH){1'b0}};
        din_ready <= 1'b0;
      
		  prev_din_ready <= 1'b0;
		  prev_apValid_read <= 1'b0;
       
		  
		  q_write_select <= 1'b0;
		  q_read_select <= 1'b0;
		  q_dead_select <= 1'b0;
		  
		  wb_sel_counter <= 1'b0;
		  apValid_write <= 1'b0;
		  apValid <= 1'b0;
		  
		  apRdfRdEn <= ~rlRdfEmpty;

    end
    else
    begin
			apRdfRdEn <= ~rlRdfEmpty;
        read_burst_state <= next_read_burst_state;
        write_burst_state <= next_write_burst_state;
        prev_write_queue_id <= write_queue_id;
        dout <= next_dout;
        prev_apValid_read <= apValid_read;
		  
        dout_burst_ready <= next_dout_burst_ready;
		  prev_dout_burst_ready <= dout_burst_ready;
        //read_empty <= next_read_empty;
        //write_full <= next_write_full;
        
		  if(q_read_select)
		  begin
				apAddr <= next_din_addr;
				apValid <= apValid_read;
		  end
		  else 
		  begin
				apAddr <= next_dout_addr;
				if(q_write_select)
				begin
					apValid <= apValid_write;
				end else begin
					apValid <= 1'b0;
				end
		  end
				
        
		  
		  
		  prev_din_ready <= din_ready;
		  din_ready <= next_din_ready;
       
		  
		  
		  q_write_select <= d_write_select;
		  q_read_select <= d_read_select;
		  q_dead_select <= d_dead_select;
		  
		  apValid_write <= next_dout_burst_ready;
		  
		  if(q_write_select/*||q_read_select*/)
				wb_sel_counter <= wb_sel_counter + 1'b1;
		  else 
				wb_sel_counter <= 1'b0;
		  
    end
end

assign apValid_read = next_din_ready;//din_ready || prev_din_ready;

always @ (*) //this block will skip one clock after reset and then set q_write_select to 1
begin
	
	d_write_select = 1'b0;
	d_read_select = 1'b0;
	d_dead_select = 1'b0;
	
	d_write_select = (~reset && ~q_write_select && ~q_read_select && ~q_dead_select && InitDone) || (q_write_select && ~wb_sel_counter) ||(q_write_select && wb_sel_counter && ~next_read_true)|| (q_read_select && next_write_true/*&& wb_sel_counter*/) ;
	d_read_select = q_dead_select || (q_read_select && ~next_write_true)/*|| (q_read_select && ~wb_sel_counter)*/;
	d_dead_select =  q_write_select && wb_sel_counter && next_read_true;
	
	
	
	
end





generate
    for(i=0;i<NUM_QUEUES;i=i+1)
    begin : memqueues
        always @(posedge clk)
        begin
            if(reset)
            begin
                read_addr[i] <= ({(MEM_ADDR_WIDTH){1'b0}}+(MEM_NUM_WORDS>>2)*i);
                write_addr[i] <= ({(MEM_ADDR_WIDTH){1'b0}}+(MEM_NUM_WORDS>>2)*i);
                num_used[i] <= {(MEM_ADDR_WIDTH-2){1'b0}};
            end
            else
            begin
                read_addr[i] <= next_read_addr[i];
                write_addr[i] <= next_write_addr[i];
                num_used[i] <= next_num_used[i];
            end
        end
    end
endgenerate
/*
always @(posedge clk)
begin
    
    if(reset)
    begin
        read_data_valid_internal <= 1'b0;
    end
    else
    begin        
        read_data_valid_internal <= next_read_data_valid;
    end
end
*/
wire  [(MEM_WIDTH*NUM_MEM_INPUTS-1):0]       din_merged;
wire [(NUM_MEM_CHIPS-1):0] din_merged_empty;
wire din_merged_valid;
generate
    for(i=0;i<NUM_MEM_CHIPS;i=i+1)
    begin : memreadfifos
        fallthrough_small_fifo
            #(.WIDTH(MEM_WIDTH*2), .MAX_DEPTH_BITS(2))
            fifo(.din(din[((i+1)*MEM_WIDTH*2-1):(i*MEM_WIDTH*2)]),
                 .wr_en(din_valid[i]),
                 .rd_en(din_merged_valid),
                 .dout(din_merged[((i+1)*MEM_WIDTH*2-1):(i*MEM_WIDTH*2)]),
                 .empty(din_merged_empty[i]),
                 .reset(reset),
                 .clk(clk)
                );
    end
endgenerate

assign din_merged_valid = ((|din_merged_empty) == 0);

assign read_data_valid = din_merged_valid && read_mem_word_valid;//din_ready & read_data_valid_internal;

assign readSigForAdd = prev_apValid_read && apValid;


always @(din or din_merged or read_queue_id or write_queue_id or read_addr[0] or read_addr[1] or read_addr[2] or read_addr[3] or write_addr[0] or write_addr[1] or write_addr[2] or write_addr[3] or num_used[0] or  num_used[1] or num_used[2] or num_used[3] or read_burst_state or write_burst_state or read_data_valid or write_data_valid or write_data or dout_ready or dout_burst_ready or read_data_ready or q_write_select or q_read_select)
begin
    next_read_burst_state = BURST_STATE_OFF;
    next_write_burst_state = BURST_STATE_OFF;
    next_din_ready = 1'b0;
	 
    dout_ready = 1'b0;
	 if(reset) begin
		next_dout = {(MEM_WIDTH*NUM_MEM_INPUTS){1'b0}};
		next_dout_addr = {(MEM_ADDR_WIDTH){1'b0}};
	 end else begin
		next_dout_addr = next_dout_addr;
		next_dout = next_dout;
	 end
    next_din_addr = {(MEM_ADDR_WIDTH){1'b0}};
    read_data = din_merged[((8*TDATA_WIDTH+6+16)-1):0];
    read_data_queue_id = din_merged[((8*TDATA_WIDTH+6+16+QUEUE_ID_WIDTH)-1):(8*TDATA_WIDTH+16+6)];
    next_dout[((8*TDATA_WIDTH+6+16)-1):0] = write_data;
    next_dout[((8*TDATA_WIDTH+6+16+QUEUE_ID_WIDTH)-1):(8*TDATA_WIDTH+6+16)] = write_queue_id;
    next_dout[8*TDATA_WIDTH+6+16+QUEUE_ID_WIDTH] = write_data_valid;
    read_mem_word_valid = din_merged[8*TDATA_WIDTH+6+16+QUEUE_ID_WIDTH];

    next_read_data_valid = 1'b0;
    
    next_num_used[0] = num_used[0];
    next_num_used[1] = num_used[1];
    next_num_used[2] = num_used[2];
    next_num_used[3] = num_used[3];
    
    //if((MAX - num_used[write_queue_id]) > tuser[write_queue_id][SIZE_END:SIZE_START]) allow write;   

      // TODO: SRAM read and write full signals
      // 1 queue should not saturate though
    if(q_read_select && read_data_ready && ~(|rlafFull))//&& (read_burst_state == 0) /*&& ~read_empty*/)
    begin
        if(read_queue_id == 2'd0)
        begin
            next_din_addr = read_addr[0];
            next_read_addr[1] = read_addr[1];
            next_read_addr[2] = read_addr[2];
            next_read_addr[3] = read_addr[3];
            if(!read_empty[0])
            begin
                next_din_ready = 1'b1;            
                next_read_data_valid = 1'b1; 


                next_read_addr[0][MEM_ADDR_WIDTH-1:MEM_ADDR_WIDTH-QUEUE_ID_WIDTH] = 2'd0;
                next_read_addr[0][MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1:0] = read_addr[0][(MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1):0]+17'b1;
                if(read_burst_state == BURST_STATE_OFF)
                    next_read_burst_state = BURST_STATE_HALFWAY;
            end
            else
            begin
                next_read_addr[0] = read_addr[0];
            end
        end
            else if(read_queue_id == 2'd1)
            begin
                next_din_addr = read_addr[1];
                next_read_addr[0] = read_addr[0];
                next_read_addr[2] = read_addr[2];
                next_read_addr[3] = read_addr[3];
                if(!read_empty[1])
                begin
                    next_din_ready = 1'b1;            
                    next_read_data_valid = 1'b1;


                    next_read_addr[1][MEM_ADDR_WIDTH-1:MEM_ADDR_WIDTH-QUEUE_ID_WIDTH] = 2'd1;
                    next_read_addr[1][MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1:0] = read_addr[1][(MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1):0]+17'b1;
                    if(read_burst_state == BURST_STATE_OFF)
                        next_read_burst_state = BURST_STATE_HALFWAY;
                end
                else
                begin
                    next_read_addr[1] = read_addr[1];
                end
            end
            else if(read_queue_id == 2'd2)
            begin
                next_din_addr = read_addr[2];
                next_read_addr[0] = read_addr[0];
                next_read_addr[1] = read_addr[1];
                next_read_addr[3] = read_addr[3];

                if(!read_empty[2])
                begin
                    next_din_ready = 1'b1;            
                    next_read_data_valid = 1'b1;


                    next_read_addr[2][MEM_ADDR_WIDTH-1:MEM_ADDR_WIDTH-QUEUE_ID_WIDTH] = 2'd2;
                    next_read_addr[2][MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1:0] = read_addr[2][(MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1):0]+17'b1;
                    if(read_burst_state == BURST_STATE_OFF)
                        next_read_burst_state = BURST_STATE_HALFWAY;
                end   
                else
                begin
                    next_read_addr[2] = read_addr[2];
                end
            end
            else if(read_queue_id == 2'd3)
            begin
                next_din_addr = read_addr[3];
                next_read_addr[0] = read_addr[0];
                next_read_addr[1] = read_addr[1];
                next_read_addr[2] = read_addr[2];
                if(!read_empty[3])
                begin
                    next_din_ready = 1'b1;            
                    next_read_data_valid = 1'b1;


                    next_read_addr[3][MEM_ADDR_WIDTH-1:MEM_ADDR_WIDTH-QUEUE_ID_WIDTH] = 2'd3;
                    next_read_addr[3][MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1:0] = read_addr[3][(MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1):0]+17'b1;
                    if(read_burst_state == BURST_STATE_OFF)
                        next_read_burst_state = BURST_STATE_HALFWAY;
                    end
                    else
                    begin
                        next_read_addr[3] = read_addr[3];
                    end
                end
            end
            else
            begin
                next_read_addr[0] = read_addr[0];
                next_read_addr[1] = read_addr[1];
                next_read_addr[2] = read_addr[2];
                next_read_addr[3] = read_addr[3];
            end

    if(q_write_select && write_data_valid && (~write_burst_state) && ~(|rlafFull) /* && ~write_full*/)
    begin
        if(write_queue_id == 2'd0)
        begin
       		next_dout_addr = write_addr[0];
        	next_write_addr[1] = write_addr[1];
    		next_write_addr[2] = write_addr[2];
   	 		next_write_addr[3] = write_addr[3];

        	if(!write_full[0])
        	begin
            	next_write_addr[0][MEM_ADDR_WIDTH-1:MEM_ADDR_WIDTH-QUEUE_ID_WIDTH] = 2'd0;
            
            	next_write_addr[0][MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1:0] = write_addr[0][(MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1):0]+17'b1;
            	dout_ready = 1'b1;
            	
                    if(write_burst_state == BURST_STATE_OFF)
                	next_write_burst_state = BURST_STATE_HALFWAY;
        	end
        	else
        	begin
            	next_write_addr[0] = write_addr[0];
                dout_ready = 1'b0;
        	end
        end
        else if(write_queue_id == 2'd1)
        begin
        	next_dout_addr = write_addr[1];
        	next_write_addr[0] = write_addr[0];
    		next_write_addr[2] = write_addr[2];
    		next_write_addr[3] = write_addr[3];
        	if(!write_full[1])
        	begin
            	next_write_addr[1][MEM_ADDR_WIDTH-1:MEM_ADDR_WIDTH-QUEUE_ID_WIDTH] = 2'd1;
            
            	next_write_addr[1][MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1:0] = write_addr[1][(MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1):0]+17'b1;
            	dout_ready = 1'b1;
            	if(write_burst_state == BURST_STATE_OFF)
                	next_write_burst_state = BURST_STATE_HALFWAY;
        	end
        	else
        	begin
        	    next_write_addr[1] = write_addr[1];
        	end
        end

		else if(write_queue_id == 2'd2)
        begin
        	next_dout_addr = write_addr[2];
        	next_write_addr[0] = write_addr[0];
    		next_write_addr[1] = write_addr[1];
    		next_write_addr[3] = write_addr[3];

        	if(!write_full[2])
        	begin
            	next_write_addr[2][MEM_ADDR_WIDTH-1:MEM_ADDR_WIDTH-QUEUE_ID_WIDTH] = 2'd2;
            
            	next_write_addr[2][MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1:0] = write_addr[2][(MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1):0]+17'b1;
            	dout_ready = 1'b1;
            	if(write_burst_state == BURST_STATE_OFF)
                	next_write_burst_state = BURST_STATE_HALFWAY;
        	end
        	else
        	begin
            	next_write_addr[2] = write_addr[2];
        	end

        end
		else if(write_queue_id == 2'd3)
        begin
        	next_dout_addr = write_addr[3];
        	next_write_addr[0] = write_addr[0];
    		next_write_addr[1] = write_addr[1];
    		next_write_addr[2] = write_addr[2];
        	if(!write_full[3])
        	begin
            	next_write_addr[3][MEM_ADDR_WIDTH-1:MEM_ADDR_WIDTH-QUEUE_ID_WIDTH] = 2'd3;
            	next_write_addr[3][MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1:0] = write_addr[3][(MEM_ADDR_WIDTH-QUEUE_ID_WIDTH-1):0]+17'b1;
            	dout_ready = 1'b1;
            	if(write_burst_state == BURST_STATE_OFF)
                	next_write_burst_state = BURST_STATE_HALFWAY;
        	end
        	else
        	begin
        	    next_write_addr[3] = write_addr[3];
        	end

        end
    end
    else
    begin
    	next_write_addr[0] = write_addr[0];
    	next_write_addr[1] = write_addr[1];
    	next_write_addr[2] = write_addr[2];
        next_write_addr[3] = write_addr[3];
    end
    
    
    if(q_read_select && next_din_ready && (~dout_ready )) //(din_ready & ~dout_ready)
    begin
        next_num_used[read_queue_id] = num_used[read_queue_id] - 1;
    end
    if(dout_ready && q_write_select)//(dout_ready & ~din_ready)
    begin
        next_num_used[write_queue_id] = num_used[write_queue_id] + 1;
    end

    next_dout_burst_ready = /*~write_burst_state &&*/ dout_ready; //This is basically a write enable to the memory



end

//assign debug = {write_burst_state, read_burst_state, num_used[0], write_addr[0], read_addr[0]};

generate
    for(i=0;i<NUM_QUEUES;i=i+1)
    begin : emptyfull
        always @(num_used[i])
        begin
            read_empty[i] = num_used[i]==0;
            // TODO: fix full logic later
            write_full[i] = ((num_used[i])>=((QUEUE_SIZE)-5));
				
		  end
    end
endgenerate

endmodule
