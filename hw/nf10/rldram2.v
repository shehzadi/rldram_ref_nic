/****************************************************************************************
*
*    File Name:  rldram2.v
*      Version:  3.12
*        Model:  BUS Functional
*
* Dependencies:  rldram2_parameters.vh
*
*  Description:  Micron RLDRAM2 (Reduced Latency DRAM 2)
*
*   Limitation:  - doesn't check for average refresh timings
*                - positive ck and ck_n edges are used to form internal clock
*                - positive dk and dk_n edges are used to latch data
*                - JTAG test circuitry is not modeled
*
*         Note:  - Set simulator resolution to "ps" accuracy
*                - Set Debug = 0 to disable $display messages
*
*   Disclaimer   This software code and all associated documentation, comments or other 
*  of Warranty:  information (collectively "Software") is provided "AS IS" without 
*                warranty of any kind. MICRON TECHNOLOGY, INC. ("MTI") EXPRESSLY 
*                DISCLAIMS ALL WARRANTIES EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
*                TO, NONINFRINGEMENT OF THIRD PARTY RIGHTS, AND ANY IMPLIED WARRANTIES 
*                OF MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. MTI DOES NOT 
*                WARRANT THAT THE SOFTWARE WILL MEET YOUR REQUIREMENTS, OR THAT THE 
*                OPERATION OF THE SOFTWARE WILL BE UNINTERRUPTED OR ERROR-FREE. 
*                FURTHERMORE, MTI DOES NOT MAKE ANY REPRESENTATIONS REGARDING THE USE OR 
*                THE RESULTS OF THE USE OF THE SOFTWARE IN TERMS OF ITS CORRECTNESS, 
*                ACCURACY, RELIABILITY, OR OTHERWISE. THE ENTIRE RISK ARISING OUT OF USE 
*                OR PERFORMANCE OF THE SOFTWARE REMAINS WITH YOU. IN NO EVENT SHALL MTI, 
*                ITS AFFILIATED COMPANIES OR THEIR SUPPLIERS BE LIABLE FOR ANY DIRECT, 
*                INDIRECT, CONSEQUENTIAL, INCIDENTAL, OR SPECIAL DAMAGES (INCLUDING, 
*                WITHOUT LIMITATION, DAMAGES FOR LOSS OF PROFITS, BUSINESS INTERRUPTION, 
*                OR LOSS OF INFORMATION) ARISING OUT OF YOUR USE OF OR INABILITY TO USE 
*                THE SOFTWARE, EVEN IF MTI HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH 
*                DAMAGES. Because some jurisdictions prohibit the exclusion or 
*                limitation of liability for consequential or incidental damages, the 
*                above limitation may not apply to you.
*
*                Copyright 2003 Micron Technology, Inc. All rights reserved.
*
* Rev   Author   Date        Changes
* ---------------------------------------------------------------------------------------
* 2.00  JMK      06/16/06    Added ODT.
*                            Added tREF checking.
*                            Added configuration vs frequency checking.
*                            Model requires back to back LOAD_MODE commands during init.
*                            Added checking for unknown ck/cmd during init.
*                            Added checking for address muxing initialization sequence.
*                            Changed polarity of odt_state signal.
*                            Allow more than 3 consecutive LOAD_MODE commands during init.
*                            Fixed same bank write to read at 1/2 clock turn around.
* 2.10  JMK      07/14/06    Removed extra tDS or tDH error messages during writes.
* 2.20  JMK      07/14/06    Changed tRC to async calculation.
* 2.40  BAS      11/07/06    Added uni-directional bus option
* 2.60  BAS      12/11/06    Added JTAG functionality
* 2.70  BAS      01/05/07    Added F26A and F37Z Parts
* 2.80  JMK      07/18/07    Updaed initialization sequence.
*                            Changed tRC to sync calculation based on the configuration.
*                            Fixed a tCKDK calculation error.
*                            Changed the checking for configuration vs. frequency.
* 3.00  JMK      01/14/07    Fixed max address warning.
*                            Fixed a tCKDK calculation error.
* 3.10  JMK      05/20/08    Fixed an error in the qk_out assignment.
*                            Fixed tDS timing check.
*                            Decreased memory array size.
* 3.11  SPH      09/16/09    Fixed tCKDK error (only check for valid DK)
* 3.12  SPH      12/15/09    Remove invalid tRC check for AREF -> LMR
****************************************************************************************/

// DO NOT CHANGE THE TIMESCALE
// MAKE SURE YOUR SIMULATOR USES "PS" RESOLUTION
`timescale 1ps / 1ps

module rldram2 (
    ck,
    ck_n,
    cs_n,
    we_n,
    ref_n,
    ba,
    a,
    dm,
    dk,
    dk_n,
`ifdef SIO
    d,
    q,
`else
    dq,
`endif
    qk,
    qk_n,
    qvld,
// JTAG PORTS
    tck,
    tms,
    tdi,
    tdo
);

`include "rldram2_parameters.vh"

    // text macros
    `define DQ_PER_DK DQ_BITS/DK_BITS
    `define DQ_PER_DM DQ_BITS/DM_BITS
    `define BANKS     (1<<BA_BITS)
    `define MAX_BITS  (BA_BITS+A_BITS-BL_BITS+1)
    `define MAX_SIZE  (1<<(BA_BITS+A_BITS))
    `define MEM_SIZE  (1<<MEM_BITS)
    `define MAX_PIPE  20

    // Declare Ports
    input   ck;
    input   ck_n;
    input   cs_n;
    input   we_n;
    input   ref_n;
    input   [BA_BITS-1:0] ba;
    input   [A_BITS-1:0]  a;
    input   [DM_BITS-1:0] dm;
    input   [DK_BITS-1:0] dk;
    input   [DK_BITS-1:0] dk_n;
`ifdef SIO
    input   [DQ_BITS-1:0] d;
    output  [DQ_BITS-1:0] q;
`else
    inout   [DQ_BITS-1:0] dq;
`endif
    output  [QK_BITS-1:0] qk;
    output  [QK_BITS-1:0] qk_n;
    output  qvld;
    // declare jtag ports
    input   tck;
    input   tms;
    input   tdi;
    output  tdo;

                            
    // clock jitter
    real    tck_avg;
    time    tck_sample [TDLLK-1:0];
    time    tch_sample [TDLLK-1:0];
    time    tcl_sample [TDLLK-1:0];
    time    tck_i;
    time    tch_i;
    time    tcl_i;
    real    tch_avg;
    real    tcl_avg;
    time    tm_ck_pos;
    time    tm_ck_neg;
    real    tjit_per_rtime;
    integer tjit_cc_time;

    // clock skew
    real    out_delay;

    // Mode Registers
    reg     [2:0] configuration;
    reg     [BL_BITS:0] burst_length;
    reg     next_address_mux;
    reg     address_mux;
    reg     dll_locked;
    reg     dll_en;
    reg     external_resistor;
    reg     odt_en;
    integer read_latency;
    integer write_latency;
    integer trc_tck;
    integer tCKQK ;

    // cmd encoding
    parameter
        LOAD_MODE = 3'b000,
        WRITE     = 3'b001,
        REFRESH   = 3'b010,
        READ      = 3'b011,
        NOP       = 3'b100
    ;

    reg [8*9-1:0] cmd_string [4:0];
    initial begin
        cmd_string[LOAD_MODE] = "Load Mode";
        cmd_string[WRITE    ] = "Write    ";
        cmd_string[REFRESH  ] = "Refresh  ";
        cmd_string[READ     ] = "Read     ";
        cmd_string[NOP      ] = "No Op    ";
    end

    // command state
    reg     [2:0]         prev_cmd;
    reg     [A_BITS-1:0]  prev_addr;
    reg     [BA_BITS-1:0] prev_bank;
    reg     [`BANKS-1:0]  init_ref;
    reg     init_done;
    integer init_step;
    reg     odt_state;

    // cmd timers/counters
    integer mr_cntr;
    integer ck_nop;
    integer ck_cntr;
    integer ck_load_mode;
    integer ck_dll_reset;
    integer ck_refresh;
    integer ck_write;
    integer ck_read;
    integer ck_bank_refresh   [`BANKS-1:0];
    integer ck_bank_write     [`BANKS-1:0];
    integer ck_bank_read      [`BANKS-1:0];
    time    tm_refresh;
    time    tm_write;
    time    tm_read;
    time    tm_bank_refresh   [`BANKS-1:0];
    time    tm_bank_write     [`BANKS-1:0];
    time    tm_bank_read      [`BANKS-1:0];

    // pipelines
    reg     [`MAX_PIPE:0]   wr_pipeline;
    reg     [`MAX_PIPE:0]   rd_pipeline;
    reg     [BA_BITS-1:0]   wr_ba_pipeline [`MAX_PIPE:0];
    reg     [BA_BITS-1:0]   rd_ba_pipeline [`MAX_PIPE:0];
    reg     [A_BITS-1:0]    wr_addr_pipeline [`MAX_PIPE:0];
    reg     [A_BITS-1:0]    rd_addr_pipeline [`MAX_PIPE:0];
    
    // data state
    reg     [BL_MAX*DQ_BITS-1:0] wr_data;
    reg     [BL_MAX*DQ_BITS-1:0] rd_data;
    reg     [BL_MAX*DQ_BITS-1:0] bit_mask;
    reg     [BL_BITS-1:0]        wr_burst_position;
    reg     [BL_BITS-1:0]        rd_burst_position;
    reg     [BL_BITS:0]          wr_burst_cntr;
    reg     [BL_BITS:0]          rd_burst_cntr;
    reg     [DQ_BITS-1:0]        dq_temp;
    reg     [15:0] check_write_dk_high;
    reg     [15:0] check_write_dk_low;

    // data timers/counters
    integer ref_cntr    [`BANKS-1:0];
    integer tm_tckdk;
    time    tm_dm       [ 7:0];
    time    tm_dk       [ 7:0];
    time    tm_dk_pos   [15:0];
    time    tm_ckdk_pos [15:0];
    time    tm_dk_neg   [15:0];
    time    tm_ckdk_neg [15:0];
    time    tm_dq       [71:0];
    time    tm_cmd_addr [27:0];
    real    rtm_tref0;
    real    rtm_tref1;
    real    rtm_tref2;
    real    rtm_tref3;
    real    rtm_tref4;
    real    rtm_tref5;
    real    rtm_tref6;
    real    rtm_tref7;

    reg [8*7-1:0] cmd_addr_string [27:0];
    initial begin
        cmd_addr_string[ 0] = "CS_N   ";
        cmd_addr_string[ 1] = "WE_N   ";
        cmd_addr_string[ 2] = "REF_N  ";
        cmd_addr_string[ 3] = "BA 0   ";
        cmd_addr_string[ 4] = "BA 1   ";
        cmd_addr_string[ 5] = "BA 2   ";
        cmd_addr_string[ 6] = "ADDR  0";
        cmd_addr_string[ 7] = "ADDR  1";
        cmd_addr_string[ 8] = "ADDR  2";
        cmd_addr_string[ 9] = "ADDR  3";
        cmd_addr_string[10] = "ADDR  4";
        cmd_addr_string[11] = "ADDR  5";
        cmd_addr_string[12] = "ADDR  6";
        cmd_addr_string[13] = "ADDR  7";
        cmd_addr_string[14] = "ADDR  8";
        cmd_addr_string[15] = "ADDR  9";
        cmd_addr_string[16] = "ADDR 10";
        cmd_addr_string[17] = "ADDR 11";
        cmd_addr_string[18] = "ADDR 12";
        cmd_addr_string[19] = "ADDR 13";
        cmd_addr_string[20] = "ADDR 14";
        cmd_addr_string[21] = "ADDR 15";
        cmd_addr_string[22] = "ADDR 16";
        cmd_addr_string[23] = "ADDR 17";
        cmd_addr_string[24] = "ADDR 18";
        cmd_addr_string[25] = "ADDR 19";
        cmd_addr_string[26] = "ADDR 20";
        cmd_addr_string[27] = "ADDR 21";
    end

    reg [8*4-1:0] dk_string [1:0];
    initial begin
        dk_string[0] = "DK  ";
        dk_string[1] = "DK_N";
    end

    // Memory Storage
`ifdef MAX_MEM
    reg     [BL_MAX*DQ_BITS-1:0] memory  [0:`MAX_SIZE-1];
`else
    reg     [BL_MAX*DQ_BITS-1:0] memory  [0:`MEM_SIZE-1];
    reg     [`MAX_BITS-1:0]      address [0:`MEM_SIZE-1];
    reg     [MEM_BITS:0]         memory_index;
    reg     [MEM_BITS:0]         memory_used;
`endif

    // receive
    reg            ck_in;
    reg            ck_n_in;
    reg            cs_n_in;
    reg            we_n_in;
    reg            ref_n_in;
    reg     [2:0]  ba_in;
    reg     [21:0] a_in;
    reg     [7:0]  dm_in;
    reg     [15:0] dk_in;
    reg     [71:0] dq_in;

    reg     [7:0]  dm_in_pos;
    reg     [7:0]  dm_in_neg;
    reg     [71:0] dq_in_pos;
    reg     [71:0] dq_in_neg;
    reg            dq_in_valid;
    reg            dk_in_valid;
    integer        wdk_cntr;
    integer        wdq_cntr;
    integer        wdk_pos_cntr [15:0];
    reg            b2b_write;
    reg     [15:0] prev_dk_in;
    reg            diff_ck;

    always @(ck   ) ck_in     <= #BUS_DELAY ck;
    always @(ck_n ) ck_n_in   <= #BUS_DELAY ck_n;
    always @(cs_n ) cs_n_in   <= #BUS_DELAY cs_n;
    always @(we_n ) we_n_in   <= #BUS_DELAY we_n;
    always @(ref_n) ref_n_in  <= #BUS_DELAY ref_n;
    always @(ba   ) ba_in     <= #BUS_DELAY ba;
    always @(a    ) a_in      <= #BUS_DELAY a;
    always @(dm   ) dm_in     <= #BUS_DELAY dm;
    always @(dk or dk_n) dk_in<= #BUS_DELAY (dk_n<<8) | dk;
`ifdef SIO
    always @(d    ) dq_in     <= #BUS_DELAY d;
`else
    always @(dq   ) dq_in     <= #BUS_DELAY dq;
`endif
    // create internal clock
    always @(posedge ck_in)   diff_ck <= ck_in;
    always @(posedge ck_n_in) diff_ck <= ~ck_n_in;

    wire    [7:0]  dk_even  = dk_in[7:0];
    wire    [7:0]  dk_odd   = dk_in[15:8];
    wire    [2:0]  cmd_n_in = !cs_n_in ? {cs_n_in, we_n_in, ref_n_in} : cs_n_in ? NOP : 3'bxxx;  //deselect = nop 

    // transmit
    reg                    qk_out_en;
    reg                    qk_out_en_dly;
    reg                    qk_out;
    reg     [QK_BITS-1:0]  qk_out_dly;
    reg                    dq_out_en;
    reg     [DQ_BITS-1:0]  dq_out_en_dly;
    reg     [DQ_BITS-1:0]  dq_out;
    reg     [DQ_BITS-1:0]  dq_out_dly;
    integer                rdqsen_cntr;
    integer                rdqen_cntr;
    integer                rdq_cntr;

    wire weak_1;
    pullup (pull1) pu1 (weak_1);

    nmos pull_dm [DM_BITS-1:0]  (dm, weak_1, odt_en & odt_state);
`ifdef SIO
    bufif1 buf_q     [DQ_BITS-1:0] ( q,    dq_out_dly,    dq_out_en_dly);
`else
    nmos pull_dq [DQ_BITS-1:0]  (dq, weak_1, odt_en & odt_state);
    bufif1 buf_dq    [DQ_BITS-1:0] (dq,    dq_out_dly,    dq_out_en_dly);
`endif
    bufif1 buf_qk    [QK_BITS-1:0] (qk,    qk_out_dly,    1'b1);
    bufif1 buf_qk_n  [QK_BITS-1:0] (qk_n, ~qk_out_dly,    1'b1);
    bufif1 buf_qvld                (qvld,  qk_out_en_dly, 1'b1);

    initial begin
        if (BL_MAX < 2) 
            $display("%m ERROR: BL_MAX parameter must be >= 2.  \nBL_MAX = %d", BL_MAX);
        $timeformat (-12, 1, " ps", 1);
        reset_task;
        ck_cntr = 0;
    end

    // calculate the absolute value of a real number
    function real abs_value;
    input arg;
    real arg;
    begin
        if (arg < 0.0)
            abs_value = -1.0 * arg;
        else
            abs_value = arg;
    end
    endfunction

`ifdef MAX_MEM
`else
    function get_index;
        input [`MAX_BITS-1:0] addr;
        begin : index
            get_index = 0;
            for (memory_index=0; memory_index<memory_used; memory_index=memory_index+1) begin
                if (address[memory_index] == addr) begin
                    get_index = 1;
                    disable index;
                end
            end
        end
    endfunction
`endif

    task memory_write;
        input  [BA_BITS-1:0] bank;
        input  [A_BITS-BL_BITS:0] a;
        input  [BL_MAX*DQ_BITS-1:0] data;
        reg    [`MAX_BITS-1:0] addr;
        begin
            addr = {bank, a};
`ifdef MAX_MEM
            memory[addr] = data;
`else
            if (get_index(addr)) begin
                address[memory_index] = addr;
                memory[memory_index] = data;
            end else if (memory_used == `MEM_SIZE) begin
                $display ("%m: at time %t ERROR: Memory overflow.  Write to Address %h with Data %h will be lost.\nYou must increase the MEM_BITS parameter or define MAX_MEM.", $time, addr, data);
                if (STOP_ON_ERROR) $stop(0);
            end else begin
                address[memory_used] = addr;
                memory[memory_used] = data;
                memory_used = memory_used + 1;
            end
`endif
        end
    endtask

    task memory_read;
        input  [BA_BITS-1:0] bank;
        input  [A_BITS-BL_BITS:0]  a;
        output [BL_MAX*DQ_BITS-1:0] data;
        reg    [`MAX_BITS-1:0] addr;
        begin
            // chop off the lowest address bits
            addr = {bank, a};
`ifdef MAX_MEM
            data = memory[addr];
`else
            if (get_index(addr)) begin
                data = memory[memory_index];
            end else begin
                data = {BL_MAX*DQ_BITS{1'bx}};
            end
`endif
        end
    endtask

    // After this task runs, NOP commands must be issued for tDLLK clocks
    task initialize;
        input [A_BITS-1:0] mode_reg;
        integer i;
        begin
            if (DEBUG) $display ("%m: at time %t INFO: Performing Initialization Sequence", $time);
            cmd_task(      NOP, 'bx, 'bx);
            cmd_task(LOAD_MODE, 'bx, 0);
            cmd_task(LOAD_MODE, 'bx, 0);
            cmd_task(LOAD_MODE, 'bx, mode_reg);
            if (mode_reg[5]) begin
                cmd_task(LOAD_MODE, 'bx, mode_reg);
            end
            for (i=0; i<`BANKS; i=i+1) begin
                cmd_task(  REFRESH,   i, 'bx);
            end
            cmd_task(      NOP, 'bx, 'bx);
        end
    endtask
    
    task reset_task;
        integer i;
        begin
            // disable inputs
            dq_in_valid         = 0;
            dk_in_valid        <= 0;
            wdk_cntr            = 0;
            wdq_cntr            = 0;
            for (i=0; i<16; i=i+1) begin
                wdk_pos_cntr[i]    <= 0;
            end
            b2b_write          <= 0;
            // disable outputs
            dq_out_en           = 0;
            rdqen_cntr          = 0;
            rdq_cntr            = 0;
            // disable ODT
            odt_en              = 0;
            odt_state           = 1;
            // require initialization sequence
            init_done           = 0;
            init_step           = 0;
            mr_cntr             = 0;
            for (i=0; i<=`BANKS; i=i+1) begin
                ref_cntr[i] = 0;
            end
            // reset DLL
            dll_en              = 0;
            dll_locked          = 0;
            // clear pipelines
            wr_pipeline         = 0;
            rd_pipeline         = 0;
            // clear memory
`ifdef MAX_MEM
            for (i=0; i<=`MAX_SIZE; i=i+1) begin //erase memory ... one address at a time
                memory[i] <= 'bx;
            end
`else
            memory_used <= 0; //erase memory
`endif
        end
    endtask

    task chk_err;
        input samebank;
        input [BA_BITS-1:0] bank;
        input [2:0] fromcmd;
        input [2:0] cmd;
        reg err;
    begin
        // all matching case expressions will be evaluated
        casex ({samebank, fromcmd, cmd})
            {1'b0, LOAD_MODE, 3'b0xx   } : begin if ((init_step > 1) && (ck_cntr - ck_load_mode < TMRSC))                                                              $display ("%m: at time %t ERROR: tMRSC violation during %s", $time, cmd_string[cmd]);                                                end
//            {1'b0, REFRESH  , LOAD_MODE} : begin if (ck_cntr - ck_refresh < trc_tck)                                                                                   $display ("%m: at time %t ERROR:   tRC violation during %s to bank %d", $time, cmd_string[cmd], bank);                               end
            {1'b1, REFRESH  , REFRESH  } : begin if (ck_cntr - ck_bank_refresh[bank] < trc_tck)                                                                        $display ("%m: at time %t ERROR:   tRC violation during %s to bank %d", $time, cmd_string[cmd], bank);                               end
            {1'b1, REFRESH  , WRITE    } : begin if (ck_cntr - ck_bank_refresh[bank] < trc_tck)                                                                        $display ("%m: at time %t ERROR:   tRC violation during %s to bank %d", $time, cmd_string[cmd], bank);                               end
            {1'b1, REFRESH  , READ     } : begin if (ck_cntr - ck_bank_refresh[bank] < trc_tck)                                                                        $display ("%m: at time %t ERROR:   tRC violation during %s to bank %d", $time, cmd_string[cmd], bank);                               end
            {1'b0, WRITE    , LOAD_MODE} : begin if (ck_cntr - ck_write < trc_tck)                                                                                     $display ("%m: at time %t ERROR:   tRC violation during %s to bank %d", $time, cmd_string[cmd], bank);                               end
            {1'b1, WRITE    , REFRESH  } : begin if (ck_cntr - ck_bank_write[bank] < trc_tck)                                                                          $display ("%m: at time %t ERROR:   tRC violation during %s to bank %d", $time, cmd_string[cmd], bank);                               end
            {1'b1, WRITE    , WRITE    } : begin if (ck_cntr - ck_bank_write[bank] < trc_tck)                                                                          $display ("%m: at time %t ERROR:   tRC violation during %s to bank %d", $time, cmd_string[cmd], bank);                               end
`ifdef SIO
`else
            {1'b0, READ     , WRITE    } : begin if (ck_cntr - ck_read < burst_length/2)                                                                               $display ("%m: at time %t ERROR:  tRTW violation during %s to bank %d", $time, cmd_string[cmd], bank);                               end
            {1'b0, WRITE    , READ     } : begin if (ck_cntr - ck_write < burst_length/2 + 1)                                                                          $display ("%m: at time %t ERROR:  tWTR violation during %s to bank %d", $time, cmd_string[cmd], bank);                               end
`endif
            {1'b1, WRITE    , READ     } : begin if ((ck_cntr - ck_bank_write[bank] < trc_tck) || (ck_cntr - ck_bank_write[bank] < 4))                                 $display ("%m: at time %t ERROR:   tRC violation during %s to bank %d", $time, cmd_string[cmd], bank);                               end
            {1'b0, READ     , LOAD_MODE} : begin if (ck_cntr - ck_read < trc_tck)                                                                                      $display ("%m: at time %t ERROR:   tRC violation during %s to bank %d", $time, cmd_string[cmd], bank);                               end
            {1'b1, READ     , REFRESH  } : begin if (ck_cntr - ck_bank_read[bank] < trc_tck)                                                                           $display ("%m: at time %t ERROR:   tRC violation during %s to bank %d", $time, cmd_string[cmd], bank);                               end
            {1'b1, READ     , WRITE    } : begin if (ck_cntr - ck_bank_read[bank] < trc_tck)                                                                           $display ("%m: at time %t ERROR:   tRC violation during %s to bank %d", $time, cmd_string[cmd], bank);                               end
            {1'b1, READ     , READ     } : begin if (ck_cntr - ck_bank_read[bank] < trc_tck)                                                                           $display ("%m: at time %t ERROR:   tRC violation during %s to bank %d", $time, cmd_string[cmd], bank);                               end
        endcase
    end
    endtask

    task cmd_task;
        input [2:0] cmd;
        input [BA_BITS-1:0] bank;
        input [A_BITS-1:0] addr;
        reg [`BANKS:0] i;
        integer j;
        begin
            if (cmd < NOP) begin
                for (j=0; j<NOP; j=j+1) begin
                    chk_err(1'b0, bank, j, cmd);
                    chk_err(1'b1, bank, j, cmd);
                end
            end

            case (cmd)
                LOAD_MODE : begin
                    if ((init_step < 2) && (mr_cntr < 2) && (addr !== 0))
                        $display ("%m: at time %t WARNING: Recommended that all address pins be held LOW during dummy %s commands.", $time, cmd_string[LOAD_MODE]);
                    if (DEBUG) $display ("%m: at time %t INFO: %s", $time, cmd_string[cmd]);
                    // Configuration
                    configuration = addr[2:0] + (addr[2:0] == 3'b000);
                    // configuration
                    if ((configuration >= 1) && (configuration <= CONFIG_MAX)) begin
                        if (DEBUG) $display ("%m: at time %t INFO: %s configuration = %d", $time, cmd_string[cmd], configuration);
                    end else begin
                        $display ("%m: at time %t ERROR: %s Illegal configuration = %d", $time, cmd_string[cmd], configuration);
                    end
                    // Burst Length
                    burst_length = 1<<(addr[4:3] + 1);
                    if ((burst_length >= BL_MIN) && (burst_length <= BL_MAX)) begin
                        if (DEBUG) $display ("%m: at time %t INFO: %s Burst Length = %d", $time, cmd_string[cmd], burst_length);
                    end else begin
                        $display ("%m: at time %t ERROR: %s Illegal Burst Length = %d", $time, cmd_string[cmd], burst_length);
                    end
                    if ((burst_length == 8) && ((configuration == 1) || (configuration == 4))) begin
                        $display ("%m: at time %t ERROR: %s Burst Length 8 is illegal while Configuration = 1 or 4.", $time, cmd_string[cmd]);
                    end
                    // Address Mux
                    next_address_mux = addr[5];
                    if (!next_address_mux) begin
                        if (DEBUG) $display ("%m: at time %t INFO: %s Address Mux = NonMultiplexed", $time, cmd_string[cmd]);
                    end else if (next_address_mux) begin
                        if (DEBUG) $display ("%m: at time %t INFO: %s Address Mux = Multiplexed", $time, cmd_string[cmd]);
                    end else begin
                        $display ("%m: at time %t ERROR: %s Illegal Address Mux = %d", $time, cmd_string[cmd], next_address_mux);
                    end
                    // DLL Enable
                    if (!dll_en && addr[7]) begin
                        ck_dll_reset <= ck_cntr;
                        tCKQK = TCKQK ;
                    end
                    dll_en = addr[7];
                    if (!dll_en) begin
                        if (DEBUG) $display ("%m: at time %t INFO: %s DLL Reset = DLL reset", $time, cmd_string[cmd]);
                        $display ("%m: at time %t WARNING: Reads with DLL disabled may result in a violation of the tCKQK parameter.", $time);
                        dll_locked = 0;
                        tCKQK = TCKQK_DLL_OFF ;
                    end else if (dll_en) begin
                        if (DEBUG) $display ("%m: at time %t INFO: %s DLL Reset = DLL enabled", $time, cmd_string[cmd]);
                    end else begin
                        $display ("%m: at time %t ERROR: %s Illegal DLL Enable = %d", $time, cmd_string[cmd], dll_en);
                    end
                    // Resistor
                    external_resistor = addr[8];
                    if (!external_resistor) begin
                        if (DEBUG) $display ("%m: at time %t INFO: %s Resistor = Internal 50 Ohm", $time, cmd_string[cmd]);
                    end else if (external_resistor) begin
                        if (DEBUG) $display ("%m: at time %t INFO: %s Resistor = External", $time, cmd_string[cmd]);
                    end else begin
                        $display ("%m: at time %t ERROR: %s Illegal Resistor = %d", $time, cmd_string[cmd], external_resistor);
                    end
                    // ODT Enable
                    odt_en = addr[9];
                    if (!odt_en) begin
                        if (DEBUG) $display ("%m: at time %t INFO: %s On Die Termination = Off", $time, cmd_string[cmd]);
                    end else if (odt_en) begin
                        if (DEBUG) $display ("%m: at time %t INFO: %s On Die Termination = On", $time, cmd_string[cmd]);
                    end else begin
                        $display ("%m: at time %t ERROR: %s Illegal On Die Termination = %d", $time, cmd_string[cmd], odt_en);
                    end
                    if (addr[A_BITS-1:10] !== 0) begin
                        $display ("%m: at time %t ERROR: %s Reserved bits must be set to zero.", $time, cmd_string[cmd]);
                    end
                    trc_tck =  2 + configuration[2] + 2*configuration[1:0];
                    read_latency = trc_tck;
                    write_latency = read_latency + 1;
                    mr_cntr = mr_cntr + 1;
                    ck_load_mode <= ck_cntr;
                end
                REFRESH : begin
                    if (DEBUG) $display ("%m: at time %t INFO: %s bank %d", $time, cmd_string[cmd], bank);
                    init_ref[bank] = 1;
                    ck_refresh <= ck_cntr;
                    tm_bank_refresh[bank] <= $time;
                    ck_bank_refresh[bank] <= ck_cntr;
                    tm_refresh <= $time;
                    if (ref_cntr[bank] == ROWS/`BANKS-1) begin
                        ref_cntr[bank] = 0;
                    end
                    if (ref_cntr[bank] == 0) begin
                        case (bank)
                            0: rtm_tref0 <= $realtime;
                            1: rtm_tref1 <= $realtime;
                            2: rtm_tref2 <= $realtime;
                            3: rtm_tref3 <= $realtime;
                            4: rtm_tref4 <= $realtime;
                            5: rtm_tref5 <= $realtime;
                            6: rtm_tref6 <= $realtime;
                            7: rtm_tref7 <= $realtime;
                        endcase
                    end
                    ref_cntr[bank] = ref_cntr[bank] + 1;
                end
                WRITE : begin
                    if (!init_done) begin
                        $display ("%m: at time %t ERROR: %s Failure.  Initialization sequence is not complete.", $time, cmd_string[cmd]);
                        if (STOP_ON_ERROR) $stop(0);
                        if (STOP_ON_ERROR) $stop(0);
                    end else if (ck_cntr - ck_write < burst_length/2) begin
                        $display ("%m: at time %t ERROR: %s Failure.  Illegal burst interruption.", $time, cmd_string[cmd]);
                        if (STOP_ON_ERROR) $stop(0);
                    end else begin
                        if (addr>>A_BITS - burst_length/4) begin
                            $display ("%m: at time %t WARNING: addr = %h does not exist.  Maximum addr = %h when Burst Length = %d", $time, addr, (1<<A_BITS - burst_length/4) - 1, burst_length);
                        end
                        if (DEBUG) $display ("%m: at time %t INFO: %s bank %d addr %h", $time, cmd_string[cmd], bank, addr);
                        wr_pipeline[2*write_latency + 1]  = 1;
                        wr_ba_pipeline[2*write_latency + 1]  = bank;
                        wr_addr_pipeline[2*write_latency + 1] = addr;
                        tm_write <= $time;
                        tm_bank_write[bank] <= $time;
                        ck_bank_write[bank] <= ck_cntr;
                        ck_write <= ck_cntr;
                    end
                end
                READ : begin
                    if ((!dll_locked) & dll_en)
                        $display ("%m: at time %t WARNING: %s prior to DLL locked.  Failing to wait for synchronization to occur may result in a violation of the tCKQK parameter.", $time, cmd_string[cmd]);
                    if (!init_done) begin
                        $display ("%m: at time %t ERROR: %s Failure.  Initialization sequence is not complete.", $time, cmd_string[cmd]);
                        if (STOP_ON_ERROR) $stop(0);
                    end else if (ck_cntr - ck_read < burst_length/2) begin
                        $display ("%m: at time %t ERROR: %s Failure.  Illegal burst interruption.", $time, cmd_string[cmd]);
                        if (STOP_ON_ERROR) $stop(0);
                    end else begin
                        if (addr>>A_BITS - burst_length/4) begin
                            $display ("%m: at time %t WARNING: addr = %h does not exist.  Maximum addr = %h when Burst Length = %d", $time, addr, (1<<A_BITS - burst_length/4) - 1, burst_length);
                        end
                        if (DEBUG) $display ("%m: at time %t INFO: %s bank %d addr %h", $time, cmd_string[cmd], bank, addr);
                        rd_pipeline[2*read_latency - 1]  = 1;
                        rd_ba_pipeline[2*read_latency - 1]  = bank;
                        rd_addr_pipeline[2*read_latency - 1] = addr;
                        tm_read <= $time;
                        tm_bank_read[bank] <= $time;
                        ck_bank_read[bank] <= ck_cntr;
                        ck_read <= ck_cntr;
                    end
                end
            endcase
            if (!init_done) begin
                case (init_step)
                    0 : begin
                        if (cmd != NOP) begin
                            if ($time < 200000000) 
                                $display ("%m: at time %t WARNING: 200 us is required before the first command.", $time);
                            init_step = init_step + 1;
                        end else if (($time > 0) && (cmd !== NOP)) begin // unknown state
                            $display ("%m: at time %t ERROR: Command signals are not allowed to go to an unknown state during power up.", $time);
                        end
                    end
                    1 : begin
                        if (ck_cntr - ck_load_mode != 1)
                            $display ("%m: at time %t ERROR: 3 back to back %s commands are required during initialization.", $time, cmd_string[LOAD_MODE]);
                        if ((mr_cntr >= 3) &&  (cmd_n_in != LOAD_MODE)) begin
                            address_mux = next_address_mux;
                            init_ref = 0;                       // require refresh commands
                            ck_nop = ck_cntr;                   // require nop commands
                            mr_cntr = 0;                        // require another load mode
                            init_step = init_step + 1;
                        end
                    end
                    2: begin
                        if (address_mux) begin
                            if (mr_cntr == 1) begin
                                init_ref = 0;                   // require refresh commands
                                ck_nop = ck_cntr;               // require nop commands
                                init_step = init_step + 1;
                            end
                        end else begin
                            init_step = init_step + 1;
                        end
                    end
                    3 : begin
                        if (&init_ref) begin
                            if (DEBUG) $display ("%m: at time %t INFO: Initialization Sequence is complete", $time);
                            init_done = 1;
                        end
                    end
                endcase
            end
        end
    endtask

    task data_task;
        reg [BA_BITS-1:0] wr_bank;
        reg [BA_BITS-1:0] rd_bank;
        reg [A_BITS-1:0] wr_addr;
        reg [A_BITS-1:0] rd_addr;
        integer i;
        integer j;
        begin

            if (diff_ck) begin
                for (i=0; i<16; i=i+1) begin
                    if (dll_locked && dq_in_valid && (i % 8 < DK_BITS)) begin
                        tm_tckdk = 1.0*tm_ckdk_neg[i] - tm_ck_neg;
                        if ((abs_value(tm_tckdk) < tck_avg/2.0) && ((tm_tckdk < TCKDK_MIN) || (tm_tckdk > TCKDK_MAX)))
                            $display ("%m: at time %t ERROR: tCKDK violation on %s bit %d", $time, dk_string[i/8], i%8); 
                    end
                    if (check_write_dk_high[i])
                        $display ("%m: at time %t ERROR: %s bit %d latching edge required during the preceding clock period.", $time, dk_string[i/8], i%8);
                end
                check_write_dk_high <= 0;
            end else begin
                for (i=0; i<16; i=i+1) begin
                    if (dll_locked && dq_in_valid && (i % 8 < DK_BITS)) begin
                        tm_tckdk = 1.0*tm_ckdk_pos[i] - tm_ck_pos;
                        if ((abs_value(tm_tckdk) < tck_avg/2.0) && ((tm_tckdk < TCKDK_MIN) || (tm_tckdk > TCKDK_MAX)))
                            $display ("%m: at time %t ERROR: tCKDK violation on %s bit %d", $time, dk_string[i/8], i%8); 
                    end
                    if (check_write_dk_low[i])
                        $display ("%m: at time %t ERROR: %s bit %d latching edge required during the preceding clock period", $time, dk_string[i/8], i%8);
                end
                check_write_dk_low <= 0;
            end

            if (wr_pipeline[0]) begin
                wr_bank = wr_ba_pipeline[0];
                wr_addr = wr_addr_pipeline[0];
                wr_burst_cntr = 0;
                memory_read(wr_bank, wr_addr*burst_length/BL_MAX, wr_data);
            end
            if (rd_pipeline[0]) begin
                rd_bank = rd_ba_pipeline[0];
                rd_addr = rd_addr_pipeline[0];
                rd_burst_cntr = 0;
            end

            // burst counter
            if (wr_burst_cntr < burst_length) begin
                wr_burst_position = wr_addr*burst_length + wr_burst_cntr;
                wr_burst_cntr = wr_burst_cntr + 1;
            end
            if (rd_burst_cntr < burst_length) begin
                rd_burst_position = rd_addr*burst_length + rd_burst_cntr;
                rd_burst_cntr = rd_burst_cntr + 1;
            end

            // write dk counter
            if (wr_pipeline[2]) begin
                wdk_cntr = burst_length;
            end
            // write dk
            if (wdk_cntr > 0) begin  // write data
                if (wdk_cntr%2) begin
                    check_write_dk_high <= ({DK_BITS{1'b1}}<<8) | {DK_BITS{1'b1}};
                end else begin
                    check_write_dk_low <= ({DK_BITS{1'b1}}<<8) | {DK_BITS{1'b1}};
                end
            end
            if (wdk_cntr > 0) begin
                wdk_cntr = wdk_cntr - 1;
            end

            // write dq
            if (dq_in_valid) begin // write data
                bit_mask = 0;
                if (diff_ck) begin
                    for (i=0; i<DM_BITS; i=i+1) begin
                        bit_mask = bit_mask | ({`DQ_PER_DM{~dm_in_neg[i]}}<<(wr_burst_position*DQ_BITS + i*`DQ_PER_DM));
                    end
                    wr_data = (dq_in_neg<<(wr_burst_position*DQ_BITS) & bit_mask) | (wr_data & ~bit_mask);
                end else begin
                    for (i=0; i<DM_BITS; i=i+1) begin
                        bit_mask = bit_mask | ({`DQ_PER_DM{~dm_in_pos[i]}}<<(wr_burst_position*DQ_BITS + i*`DQ_PER_DM));
                    end
                    wr_data = (dq_in_pos<<(wr_burst_position*DQ_BITS) & bit_mask) | (wr_data & ~bit_mask);
                end
                dq_temp = wr_data>>(wr_burst_position*DQ_BITS);
                if (DEBUG) $display ("%m: at time %t INFO: WRITE @dk= bank = %h addr = %h data = %h",$time, wr_bank, wr_addr, dq_temp);
                if (wr_burst_cntr%BL_MIN == 0) begin
                    memory_write(wr_bank, wr_addr*burst_length/BL_MAX, wr_data);
                end
            end
            if (wr_pipeline[1]) begin
                wdq_cntr = burst_length;
            end
            if (wdq_cntr > 0) begin
                dq_in_valid = 1'b1;
                wdq_cntr = wdq_cntr - 1;
            end else begin
                dq_in_valid = 1'b0;
                dk_in_valid <= 1'b0;
                for (i=0; i<16; i=i+1) begin
                    wdk_pos_cntr[i]    <= 0;
                end
            end
            if (wr_pipeline[0]) begin
                b2b_write <= 1'b0;
            end
            if (wr_pipeline[2]) begin
                if (dk_in_valid) begin
                    b2b_write <= 1'b1;
                end
                dk_in_valid <= 1'b1;
            end
            // read dqs enable counter
            if (rd_pipeline[RDQSEN_PRE]) begin
                rdqsen_cntr = RDQSEN_PRE + burst_length + RDQSEN_PST - 1;
            end
            if (rdqsen_cntr > 0) begin
                rdqsen_cntr = rdqsen_cntr - 1;
                qk_out_en = 1'b1;
            end else begin
                qk_out_en = 1'b0;
            end
            // read dqs
            qk_out = (diff_ck == 0);
            
            // read dq enable counter
            if (rd_pipeline[RDQEN_PRE]) begin
                rdqen_cntr = RDQEN_PRE + burst_length + RDQEN_PST;
            end
            if (rdqen_cntr > 0) begin
                rdqen_cntr = rdqen_cntr - 1;
                dq_out_en = 1'b1;
            end else begin
                dq_out_en = 1'b0;
            end
            // read dq
            if (rd_pipeline[0]) begin
                rdq_cntr = burst_length;
            end
            if (rdq_cntr > 0) begin // read data
                if (rd_burst_cntr % 2) begin
                    memory_read(rd_bank, rd_addr*burst_length/BL_MAX, rd_data);
                end
                dq_temp = rd_data>>(rd_burst_position*DQ_BITS);
                dq_out = dq_temp;
                if (DEBUG) $display ("%m: at time %t INFO: READ  @dk= bank = %h addr = %h data = %h",$time, rd_bank, rd_addr, dq_temp);
                rdq_cntr = rdq_cntr - 1;
            end else begin
                dq_out = {DQ_BITS{1'b1}};
            end

            // delay signals prior to output
            out_delay       = tck_avg/2.0;
            odt_state      <= #(out_delay) ~dq_out_en;
            qk_out_en_dly  <= #(out_delay) qk_out_en;
            qk_out_dly     <= #(out_delay) {QK_BITS {qk_out    }};
            dq_out_en_dly  <= #(out_delay) {DQ_BITS {dq_out_en }};
            dq_out_dly     <= #(out_delay) {DQ_BITS {dq_out    }};
        end
    endtask

    always @(diff_ck) begin : main
        integer i;
        reg error;

        error = 0;
        if ((diff_ck !== 1'b0) && (diff_ck !== 1'b1))
            $display ("%m: at time %t ERROR: CK and CK_N are not allowed to go to an unknown state.", $time);
        data_task;
        if (diff_ck) begin
            // check setup of command signals
            if ($time > TCS) begin
                for (i=0; i<28; i=i+1) begin
                    if ($time - tm_cmd_addr[i] < TCS) 
                        $display ("%m: at time %t ERROR:   tCS violation on %s by %t", $time, cmd_addr_string[i], tm_cmd_addr[i] + TCS - $time);
                end
            end

            // check tREF
            if ($realtime - rtm_tref0 > TREF*1.0e9) begin error = 1; i = 0; rtm_tref0 <= $realtime; end
            if ($realtime - rtm_tref1 > TREF*1.0e9) begin error = 1; i = 1; rtm_tref1 <= $realtime; end
            if ($realtime - rtm_tref2 > TREF*1.0e9) begin error = 1; i = 2; rtm_tref2 <= $realtime; end
            if ($realtime - rtm_tref3 > TREF*1.0e9) begin error = 1; i = 3; rtm_tref3 <= $realtime; end
            if ($realtime - rtm_tref4 > TREF*1.0e9) begin error = 1; i = 4; rtm_tref4 <= $realtime; end
            if ($realtime - rtm_tref5 > TREF*1.0e9) begin error = 1; i = 5; rtm_tref5 <= $realtime; end
            if ($realtime - rtm_tref6 > TREF*1.0e9) begin error = 1; i = 6; rtm_tref6 <= $realtime; end
            if ($realtime - rtm_tref7 > TREF*1.0e9) begin error = 1; i = 7; rtm_tref7 <= $realtime; end
            if (error) begin
                $display ("%m: at time %t ERROR:  tREF violation bank %d during %s", $time, i, cmd_string[cmd_n_in]);
                ref_cntr[i] = 0;
            end

            // update current state
            if (!dll_locked && (ck_cntr - ck_dll_reset == TDLLK)) begin
                // check configuration vs tRC (also enforces the minimum tCK period)
                if (trc_tck*tck_avg < TRC)
                      $display ("%m: at time %t ERROR: Configuration = %d is illegal @tCK(avg) = %f.  tRC*tCK(avg) must be >= %d ps", $time, configuration, tck_avg, TRC);
                dll_locked = 1;
            end
            // respond to the current command
            if (address_mux) begin
                if (prev_cmd != NOP) begin
                    //                             A21    , A20    , A10     , A[18:17]        , A16     , A15     , A[14:13]        , A[12:11]   , A[10:8]        , A[7:6]   , A[5:3],       , A[2:1]   , A0
                    cmd_task(prev_cmd, prev_bank, {a_in[5], a_in[0], a_in[10], prev_addr[18:17], a_in[17], a_in[18], prev_addr[14:13], a_in[14:13], prev_addr[10:8], a_in[9:8], prev_addr[5:3], a_in[4:3], prev_addr[0]});
                end
            end else begin
                cmd_task(cmd_n_in, ba_in, a_in);
            end
            prev_cmd = cmd_n_in;
            prev_addr = a_in;
            prev_bank = ba_in;

            tjit_cc_time = $time - tm_ck_pos - tck_i;
            tck_i   = $time - tm_ck_pos;
            tck_avg = tck_avg - tck_sample[ck_cntr%TDLLK]/$itor(TDLLK);
            tck_avg = tck_avg + tck_i/$itor(TDLLK);
            tck_sample[ck_cntr%TDLLK] = tck_i;
            tjit_per_rtime = tck_i - tck_avg;

            if (dll_locked) begin
                // check tCK min/max/jitter
                if (abs_value(tjit_per_rtime) - TJIT_PER >= 1.0) 
                    $display ("%m: at time %t ERROR: tJIT(per) violation by %f ps.", $time, abs_value(tjit_per_rtime) - TJIT_PER);
                if (abs_value(tjit_cc_time) - TJIT_CC >= 1.0) 
                    $display ("%m: at time %t ERROR: tJIT(cc) violation by %f ps.", $time, abs_value(tjit_cc_time) - TJIT_CC);
                if (TCK_MIN - tck_avg >= 1.0)
                    $display ("%m: at time %t ERROR: tCK(avg) minimum violation by %f ps.", $time, TCK_MIN - tck_avg);
                if (tck_avg - TCK_MAX >= 1.0) 
                    $display ("%m: at time %t ERROR: tCK(avg) maximum violation by %f ps.", $time, tck_avg - TCK_MAX);
                if (tm_ck_pos + TCK_MIN - TJIT_PER > $time) 
                    $display ("%m: at time %t ERROR: tCK(abs) minimum violation by %t", $time, tm_ck_pos + TCK_MIN - TJIT_PER - $time);
                if (tm_ck_pos + TCK_MAX + TJIT_PER < $time) 
                    $display ("%m: at time %t ERROR: tCK(abs) maximum violation by %t", $time, $time - tm_ck_pos - TCK_MAX - TJIT_PER);

                // check tCKL
                if (tcl_avg < TCKL_MIN*tck_avg) 
                    $display ("%m: at time %t ERROR: tCKL(avg) minimum violation on CK by %t", $time, TCKL_MIN*tck_avg - tcl_avg);
                if (tcl_avg > TCKL_MAX*tck_avg) 
                    $display ("%m: at time %t ERROR: tCKL(avg) maximum violation on CK by %t", $time, tcl_avg - TCKL_MAX*tck_avg);
            end

            // calculate the tch avg jitter
            tch_avg = tch_avg - tch_sample[ck_cntr%TDLLK]/$itor(TDLLK);
            tch_avg = tch_avg + tch_i/$itor(TDLLK);
            tch_sample[ck_cntr%TDLLK] = tch_i;

            // update timers/counters
            tcl_i <= $time - tm_ck_neg;
            ck_cntr <= ck_cntr + 1;
            tm_ck_pos <= $time;
        end else begin
            if (dll_locked) begin
                // check tCKH
                if (tch_avg < TCKH_MIN*tck_avg) 
                    $display ("%m: at time %t ERROR: tCKH(avg) minimum violation on CK by %t", $time, TCKH_MIN*tck_avg - tch_avg);
                if (tch_avg > TCKH_MAX*tck_avg) 
                    $display ("%m: at time %t ERROR: tCKH(avg) maximum violation on CK by %t", $time, tch_avg - TCKH_MAX*tck_avg);
            end

            // calculate the tcl avg jitter
            tcl_avg = tcl_avg - tcl_sample[ck_cntr%TDLLK]/$itor(TDLLK);
            tcl_avg = tcl_avg + tcl_i/$itor(TDLLK);
            tcl_sample[ck_cntr%TDLLK] = tcl_i;

            // update timers/counters
            tch_i <= $time - tm_ck_pos;
            tm_ck_neg <= $time;
        end

        // shift pipelines
        if (|wr_pipeline || |rd_pipeline) begin
            wr_pipeline = wr_pipeline>>1;
            rd_pipeline = rd_pipeline>>1;
            for (i=0; i<`MAX_PIPE; i=i+1) begin
                wr_ba_pipeline[i] = wr_ba_pipeline[i+1];
                rd_ba_pipeline[i] = rd_ba_pipeline[i+1];
                wr_addr_pipeline[i] = wr_addr_pipeline[i+1];
                rd_addr_pipeline[i] = rd_addr_pipeline[i+1];
            end
        end
    end

    // receiver(s)
    task dk_even_receiver;
        input [3:0] i;
        reg [DQ_BITS-1:0] bit_mask;
        begin
            bit_mask = {`DQ_PER_DK{1'b1}}<<(i*`DQ_PER_DK);
            if (dk_even[i]) begin
                dm_in_pos[i] = dm_in[i];
                dq_in_pos = (dq_in & bit_mask) | (dq_in_pos & ~bit_mask);
            end
        end
    endtask

    always @(posedge dk_even[ 0]) dk_even_receiver( 0);
    always @(posedge dk_even[ 1]) dk_even_receiver( 1);
    always @(posedge dk_even[ 2]) dk_even_receiver( 2);
    always @(posedge dk_even[ 3]) dk_even_receiver( 3);
    always @(posedge dk_even[ 4]) dk_even_receiver( 4);
    always @(posedge dk_even[ 5]) dk_even_receiver( 5);
    always @(posedge dk_even[ 6]) dk_even_receiver( 6);
    always @(posedge dk_even[ 7]) dk_even_receiver( 7);

    task dk_odd_receiver;
        input [3:0] i;
        reg [DQ_BITS-1:0] bit_mask;
        begin
            bit_mask = {`DQ_PER_DK{1'b1}}<<(i*`DQ_PER_DK);
            if (dk_odd[i]) begin
                dm_in_neg[i] = dm_in[i];
                dq_in_neg = (dq_in & bit_mask) | (dq_in_neg & ~bit_mask);
            end
        end
    endtask

    always @(posedge dk_odd[ 0]) dk_odd_receiver( 0);
    always @(posedge dk_odd[ 1]) dk_odd_receiver( 1);
    always @(posedge dk_odd[ 2]) dk_odd_receiver( 2);
    always @(posedge dk_odd[ 3]) dk_odd_receiver( 3);
    always @(posedge dk_odd[ 4]) dk_odd_receiver( 4);
    always @(posedge dk_odd[ 5]) dk_odd_receiver( 5);
    always @(posedge dk_odd[ 6]) dk_odd_receiver( 6);
    always @(posedge dk_odd[ 7]) dk_odd_receiver( 7);
 
    //Processes to check hold and pulse width of control signals
    task cmd_addr_timing_check;
    input i;
    integer i;
    begin
        if ($time - tm_ck_pos < TCH) 
            $display ("%m: at time %t ERROR:  tCH violation on %s by %t", $time, cmd_addr_string[i], tm_ck_pos + TCH - $time);
        // Control input signals may not have pulse widths less than tCK/2
        if (dll_locked && ($time - tm_cmd_addr[i] < $rtoi(0.5*tck_avg)))
            $display ("%m: at time %t ERROR: Pulse width violation on %s by %t", $time, cmd_addr_string[i], tm_cmd_addr[i] + 0.5*tck_avg - $time);
        tm_cmd_addr[i] = $time;
    end
    endtask

    always @(cs_n_in    ) cmd_addr_timing_check( 0);
    always @(we_n_in    ) cmd_addr_timing_check( 1);
    always @(ref_n_in   ) cmd_addr_timing_check( 2);
    always @(ba_in  [ 0]) cmd_addr_timing_check( 3);
    always @(ba_in  [ 1]) cmd_addr_timing_check( 4);
    always @(ba_in  [ 2]) cmd_addr_timing_check( 5);
    always @(a_in   [ 0]) cmd_addr_timing_check( 6);
    always @(a_in   [ 1]) cmd_addr_timing_check( 7);
    always @(a_in   [ 2]) cmd_addr_timing_check( 8);
    always @(a_in   [ 3]) cmd_addr_timing_check( 9);
    always @(a_in   [ 4]) cmd_addr_timing_check(10);
    always @(a_in   [ 5]) cmd_addr_timing_check(11);
    always @(a_in   [ 6]) cmd_addr_timing_check(12);
    always @(a_in   [ 7]) cmd_addr_timing_check(13);
    always @(a_in   [ 8]) cmd_addr_timing_check(14);
    always @(a_in   [ 9]) cmd_addr_timing_check(15);
    always @(a_in   [10]) cmd_addr_timing_check(16);
    always @(a_in   [11]) cmd_addr_timing_check(17);
    always @(a_in   [12]) cmd_addr_timing_check(18);
    always @(a_in   [13]) cmd_addr_timing_check(19);
    always @(a_in   [14]) cmd_addr_timing_check(20);
    always @(a_in   [15]) cmd_addr_timing_check(21);
    always @(a_in   [16]) cmd_addr_timing_check(22);
    always @(a_in   [17]) cmd_addr_timing_check(23);
    always @(a_in   [18]) cmd_addr_timing_check(24);
    always @(a_in   [19]) cmd_addr_timing_check(25);
    always @(a_in   [20]) cmd_addr_timing_check(26);
    always @(a_in   [21]) cmd_addr_timing_check(27);

    // Processes to check setup and hold of data signals
    task dm_timing_check;
    input i;
    reg [2:0] i;
    begin
        if (dk_in_valid) begin
            if ($time - tm_dk[i] < TDH) 
                $display ("%m: at time %t ERROR:   tDH violation on DM bit %d by %t", $time, i, tm_dk[i] + TDH - $time);
        end
        tm_dm[i] = $time;
    end
    endtask

    always @(dm_in[ 0]) dm_timing_check( 0);
    always @(dm_in[ 1]) dm_timing_check( 1);
    always @(dm_in[ 2]) dm_timing_check( 2);
    always @(dm_in[ 3]) dm_timing_check( 3);
    always @(dm_in[ 4]) dm_timing_check( 4);
    always @(dm_in[ 5]) dm_timing_check( 5);
    always @(dm_in[ 6]) dm_timing_check( 6);
    always @(dm_in[ 7]) dm_timing_check( 7);

    task dq_timing_check;
    input i;
    reg [6:0] i;
    begin
        if (dk_in_valid) begin
            if ($time - tm_dk[i/`DQ_PER_DK] < TDH) 
                $display ("%m: at time %t ERROR:   tDH violation on DQ bit %d by %t", $time, i, tm_dk[i/`DQ_PER_DK] + TDH - $time);
        end
        tm_dq[i] = $time;
    end 
    endtask

    always @(dq_in[ 0]) dq_timing_check( 0);
    always @(dq_in[ 1]) dq_timing_check( 1);
    always @(dq_in[ 2]) dq_timing_check( 2);
    always @(dq_in[ 3]) dq_timing_check( 3);
    always @(dq_in[ 4]) dq_timing_check( 4);
    always @(dq_in[ 5]) dq_timing_check( 5);
    always @(dq_in[ 6]) dq_timing_check( 6);
    always @(dq_in[ 7]) dq_timing_check( 7);
    always @(dq_in[ 8]) dq_timing_check( 8);
    always @(dq_in[ 9]) dq_timing_check( 9);
    always @(dq_in[10]) dq_timing_check(10);
    always @(dq_in[11]) dq_timing_check(11);
    always @(dq_in[12]) dq_timing_check(12);
    always @(dq_in[13]) dq_timing_check(13);
    always @(dq_in[14]) dq_timing_check(14);
    always @(dq_in[15]) dq_timing_check(15);
    always @(dq_in[16]) dq_timing_check(16);
    always @(dq_in[17]) dq_timing_check(17);
    always @(dq_in[18]) dq_timing_check(18);
    always @(dq_in[19]) dq_timing_check(19);
    always @(dq_in[20]) dq_timing_check(20);
    always @(dq_in[21]) dq_timing_check(21);
    always @(dq_in[22]) dq_timing_check(22);
    always @(dq_in[23]) dq_timing_check(23);
    always @(dq_in[24]) dq_timing_check(24);
    always @(dq_in[25]) dq_timing_check(25);
    always @(dq_in[26]) dq_timing_check(26);
    always @(dq_in[27]) dq_timing_check(27);
    always @(dq_in[28]) dq_timing_check(28);
    always @(dq_in[29]) dq_timing_check(29);
    always @(dq_in[30]) dq_timing_check(30);
    always @(dq_in[31]) dq_timing_check(31);
    always @(dq_in[32]) dq_timing_check(32);
    always @(dq_in[33]) dq_timing_check(33);
    always @(dq_in[34]) dq_timing_check(34);
    always @(dq_in[35]) dq_timing_check(35);
    always @(dq_in[36]) dq_timing_check(36);
    always @(dq_in[37]) dq_timing_check(37);
    always @(dq_in[38]) dq_timing_check(38);
    always @(dq_in[39]) dq_timing_check(39);
    always @(dq_in[40]) dq_timing_check(40);
    always @(dq_in[41]) dq_timing_check(41);
    always @(dq_in[42]) dq_timing_check(42);
    always @(dq_in[43]) dq_timing_check(43);
    always @(dq_in[44]) dq_timing_check(44);
    always @(dq_in[45]) dq_timing_check(45);
    always @(dq_in[46]) dq_timing_check(46);
    always @(dq_in[47]) dq_timing_check(47);
    always @(dq_in[48]) dq_timing_check(48);
    always @(dq_in[49]) dq_timing_check(49);
    always @(dq_in[50]) dq_timing_check(50);
    always @(dq_in[51]) dq_timing_check(51);
    always @(dq_in[52]) dq_timing_check(52);
    always @(dq_in[53]) dq_timing_check(53);
    always @(dq_in[54]) dq_timing_check(54);
    always @(dq_in[55]) dq_timing_check(55);
    always @(dq_in[56]) dq_timing_check(56);
    always @(dq_in[57]) dq_timing_check(57);
    always @(dq_in[58]) dq_timing_check(58);
    always @(dq_in[59]) dq_timing_check(59);
    always @(dq_in[60]) dq_timing_check(60);
    always @(dq_in[61]) dq_timing_check(61);
    always @(dq_in[62]) dq_timing_check(62);
    always @(dq_in[63]) dq_timing_check(63);
    always @(dq_in[64]) dq_timing_check(64);
    always @(dq_in[65]) dq_timing_check(65);
    always @(dq_in[66]) dq_timing_check(66);
    always @(dq_in[67]) dq_timing_check(67);
    always @(dq_in[68]) dq_timing_check(68);
    always @(dq_in[69]) dq_timing_check(69);
    always @(dq_in[70]) dq_timing_check(70);
    always @(dq_in[71]) dq_timing_check(71);

    task dk_pos_timing_check;
    input i;
    reg [3:0] i;
    reg [4:0] j;
    begin
        if (dk_in_valid && ((wdk_pos_cntr[i] < burst_length/2) || b2b_write)) begin
            if (dk_in[i] ^ prev_dk_in[i]) begin
                if (dll_locked) begin
                    if (($time - tm_dk_neg[i] < $rtoi(TDKL_MIN*tck_avg)) || ($time - tm_dk_neg[i] > $rtoi(TDKL_MAX*tck_avg)))
                        $display ("%m: at time %t ERROR: tDKL violation on %s bit %d", $time, dk_string[i/8], i%8);
                    if (tm_dk_pos[i] + TDK_MIN - TJIT_PER > $time) 
                        $display ("%m: at time %t ERROR: tDK(abs) minimum violation by %t", $time, tm_dk_pos[i] + TDK_MIN - TJIT_PER - $time);
                    if (tm_dk_pos[i] + TDK_MAX + TJIT_PER < $time) 
                        $display ("%m: at time %t ERROR: tDK(abs) maximum violation by %t", $time, $time - tm_dk_pos[i] - TDK_MAX - TJIT_PER);
                end
                if ($time - tm_dm[i%8] < TDS) 
                    $display ("%m: at time %t ERROR: tDS violation on DM bit %d by %t", $time, i,  tm_dm[i%8] + TDS - $time);
                if (!dq_out_en) begin
                    for (j=0; j<`DQ_PER_DK; j=j+1) begin
                        if ($time - tm_dq[i*`DQ_PER_DK+j] < TDS) 
                            $display ("%m: at time %t ERROR: tDS violation on DQ bit %d by %t", $time, i*`DQ_PER_DK+j, tm_dq[i*`DQ_PER_DK+j] + TDS - $time);
                    end
                end
                if ((wdk_pos_cntr[i] < burst_length/2) && !b2b_write) begin
                    wdk_pos_cntr[i] <= wdk_pos_cntr[i] + 1;
                end else begin
                    wdk_pos_cntr[i] <= 1;
                end
                check_write_dk_low[i] <= 1'b0;
                tm_dk[i%8] <= $time;
            end else begin
                $display ("%m: at time %t ERROR: Invalid latching edge on %s bit %d", $time, dk_string[i/8], i%8);
            end
        end
        tm_ckdk_pos[i] <= $time;
        tm_dk_pos[i] = $time;
        prev_dk_in[i] <= dk_in[i];
    end
    endtask

    always @(posedge dk_in[ 0]) dk_pos_timing_check( 0);
    always @(posedge dk_in[ 1]) dk_pos_timing_check( 1);
    always @(posedge dk_in[ 2]) dk_pos_timing_check( 2);
    always @(posedge dk_in[ 3]) dk_pos_timing_check( 3);
    always @(posedge dk_in[ 4]) dk_pos_timing_check( 4);
    always @(posedge dk_in[ 5]) dk_pos_timing_check( 5);
    always @(posedge dk_in[ 6]) dk_pos_timing_check( 6);
    always @(posedge dk_in[ 7]) dk_pos_timing_check( 7);
    always @(negedge dk_in[ 8]) dk_pos_timing_check( 8);
    always @(negedge dk_in[ 9]) dk_pos_timing_check( 9);
    always @(negedge dk_in[10]) dk_pos_timing_check(10);
    always @(negedge dk_in[11]) dk_pos_timing_check(11);
    always @(negedge dk_in[12]) dk_pos_timing_check(12);
    always @(negedge dk_in[13]) dk_pos_timing_check(13);
    always @(negedge dk_in[14]) dk_pos_timing_check(14);
    always @(negedge dk_in[15]) dk_pos_timing_check(15);

    task dk_neg_timing_check;
    input i;
    reg [3:0] i;
    reg [4:0] j;
    begin
        if (dk_in_valid && (wdk_pos_cntr[i] > 0) && check_write_dk_high[i]) begin
            if (dk_in[i] ^ prev_dk_in[i]) begin
                if (dll_locked) begin
                    if (($time - tm_dk_pos[i] < $rtoi(TDKH_MIN*tck_avg)) || ($time - tm_dk_pos[i] > $rtoi(TDKH_MAX*tck_avg)))
                        $display ("%m: at time %t ERROR: tDKH violation on %s bit %d", $time, dk_string[i/8], i%8);
                end
                if ($time - tm_dm[i%8] < TDS) 
                    $display ("%m: at time %t ERROR: tDS violation on DM bit %d by %t", $time, i,  tm_dm[i%8] + TDS - $time);
                if (!dq_out_en) begin
                    for (j=0; j<`DQ_PER_DK; j=j+1) begin
                        if ($time - tm_dq[i*`DQ_PER_DK+j] < TDS) 
                            $display ("%m: at time %t ERROR: tDS violation on DQ bit %d by %t", $time, i*`DQ_PER_DK+j, tm_dq[i*`DQ_PER_DK+j] + TDS - $time);
                    end
                end
                check_write_dk_high[i] <= 1'b0;
                tm_dk[i%8] <= $time;
            end else begin
                $display ("%m: at time %t ERROR: Invalid latching edge on %s bit %d", $time, dk_string[i/8], i%8);
            end
        end
        tm_ckdk_neg[i] <= $time;
        tm_dk_neg[i] = $time;
        prev_dk_in[i] <= dk_in[i];
    end
    endtask

    always @(negedge dk_in[ 0]) dk_neg_timing_check( 0);
    always @(negedge dk_in[ 1]) dk_neg_timing_check( 1);
    always @(negedge dk_in[ 2]) dk_neg_timing_check( 2);
    always @(negedge dk_in[ 3]) dk_neg_timing_check( 3);
    always @(negedge dk_in[ 4]) dk_neg_timing_check( 4);
    always @(negedge dk_in[ 5]) dk_neg_timing_check( 5);
    always @(negedge dk_in[ 6]) dk_neg_timing_check( 6);
    always @(negedge dk_in[ 7]) dk_neg_timing_check( 7);
    always @(posedge dk_in[ 8]) dk_neg_timing_check( 8);
    always @(posedge dk_in[ 9]) dk_neg_timing_check( 9);
    always @(posedge dk_in[10]) dk_neg_timing_check(10);
    always @(posedge dk_in[11]) dk_neg_timing_check(11);
    always @(posedge dk_in[12]) dk_neg_timing_check(12);
    always @(posedge dk_in[13]) dk_neg_timing_check(13);
    always @(posedge dk_in[14]) dk_neg_timing_check(14);
    always @(posedge dk_in[15]) dk_neg_timing_check(15);



//----------------------------------------- JTAG CONTROLLER ----------------------------------------------------

    //------------- JTAG STATES ----------------
    `define TAP_RESET      4'h0
    `define TAP_IDLE       4'h1
    `define TAP_DR_SCAN    4'h2
    `define TAP_CAPTURE_DR 4'h3
    `define TAP_SHIFT_DR   4'h4
    `define TAP_EXIT1_DR   4'h5
    `define TAP_PAUSE_DR   4'h6
    `define TAP_EXIT2_DR   4'h7
    `define TAP_UPDATE_DR  4'h8
    `define TAP_IR_SCAN    4'h9
    `define TAP_CAPTURE_IR 4'hA
    `define TAP_SHIFT_IR   4'hB
    `define TAP_EXIT1_IR   4'hC
    `define TAP_PAUSE_IR   4'hD
    `define TAP_EXIT2_IR   4'hE
    `define TAP_UPDATE_IR  4'hF

    //------------- INSTRUCTION CODES --------------
    `define EXTEST         8'h00
    `define IDCODE         8'h21
    `define SAMPLE_PRELOAD 8'h05
    `define CLAMP          8'h07
    `define HIGHZ          8'h03
    `define BYPASS         8'hFF

    //------------- INTEGER DECLARATIONS --------------

    integer tclk_cnt ;
    integer      i;

    //------------- REGISTER DECLARATIONS --------------
    reg          bypass_reg               ;
    reg  [  7:0] instruction_reg          ;
    reg  [ 31:0] ID_reg                   ;
    reg  [112:0] boundary_scan_reg        ;

    reg          bypass_reg_next          ;
    reg  [  7:0] instruction_reg_next     ;
    reg  [ 31:0] ID_reg_next              ;
    reg  [112:0] boundary_scan_reg_next   ;

    reg  [112:0] boundary_scan_reg_info   ;
    reg  [  3:0] current_state            ;
    reg  [  3:0] next_state               ;

    reg          tdo_out                  ;
    reg          tdo_reg                  ;
    reg          tdo_reg_next             ;

    wire tdi_in = (tdi == 1'b0)? 1'b0 : 1'b1 ;

    //------------- TIME DECLARATIONS --------------

    realtime tclk_period    ;
    realtime pos_tclk_edge  ;
    realtime neg_tclk_edge  ;
    realtime tms_transition ;
    realtime tdi_transition ;

    //------------- INITIALIZATION OF VARIABLES --------------
    initial begin
        current_state = `TAP_RESET                                  ;
        boundary_scan_reg_info = 113'h0BEADBEADBEADBEADBEADBEADBEAD ;
        tdo_out                = 1'bz                               ;
        tdo_reg                = 1'bz                               ;
        tdo_reg_next           = 1'bz                               ;
        tclk_cnt               = 0                                  ;
        tclk_period            = 0                                  ;
        pos_tclk_edge          = 0                                  ;
        neg_tclk_edge          = 0                                  ;
        tms_transition         = 0                                  ;
        tdi_transition         = 0                                  ;
    end

    //------------- TIMING CHECKS -----------------------------
    // measure clock period
    integer  tclk_pos_edge_cnt ;
    always @(posedge tck) begin
        tclk_period = $realtime - pos_tclk_edge ;
        pos_tclk_edge = $realtime ;
        if (tclk_cnt < 2) begin
            tclk_cnt = tclk_cnt + 1 ;
        end
        if (tclk_cnt == 2) begin
            if (tclk_period < TTHTH - 0.01) begin
                $display ("%m: at time %t ERROR: tTHTH minimum violation on TCK by %t", $time, TTHTH - tclk_period);
            end
            if (($realtime - neg_tclk_edge) < TTLTH - 0.01) begin
                $display ("%m: at time %t ERROR: tTLTH minimum violation on TCK by %t", $time, TTLTH - ($time - neg_tclk_edge));
            end
            if (($realtime - tms_transition) < TMVTH - 0.01) begin
                $display ("%m: at time %t ERROR: tMVTH minimum violation on TCK by %t", $time, TMVTH - ($time - tms_transition));
            end
            if (($realtime - tdi_transition) < TDVTH - 0.01) begin
                $display ("%m: at time %t ERROR: tDVTH minimum violation on TCK by %t", $time, TDVTH - ($time - tdi_transition));
            end
        end
    end
    //measure duty cycle
    always @(negedge tck) begin
        neg_tclk_edge = $realtime ;
        if (tclk_cnt == 2) begin
            if (($realtime - pos_tclk_edge) < TTHTL - 0.01) begin
                $display ("%m: at time %t ERROR: tTHTL minimum violation on TCK by %t", $time, TTHTL - ($time - pos_tclk_edge));
            end
        end
    end
    always @(tms) begin
        tms_transition = $realtime ;
        if (tclk_cnt == 2) begin
            if (($realtime - pos_tclk_edge) < TTHMX - 0.01) begin
                $display ("%m: at time %t ERROR: tTHMX minimum violation on TCK by %t", $time, TTHMX - ($time - pos_tclk_edge));
            end
        end
    end
    always @(tdi) begin
        tdi_transition = $realtime ;
        if (tclk_cnt == 2) begin
            if (($realtime - pos_tclk_edge) < TTHDX - 0.01) begin
                $display ("%m: at time %t ERROR: tTHDX minimum violation on TCK by %t", $time, TTHDX - ($time - pos_tclk_edge));
            end
        end
    end

    //------------- INSTRUCTION MODES --------------

    wire mode_valid                 = (current_state == `TAP_RESET)      |
                                      (current_state == `TAP_IDLE)       |
                                      (current_state == `TAP_DR_SCAN)    |
                                      (current_state == `TAP_CAPTURE_DR) |
                                      (current_state == `TAP_SHIFT_DR)   |
                                      (current_state == `TAP_EXIT1_DR)   |
                                      (current_state == `TAP_PAUSE_DR)   |
                                      (current_state == `TAP_EXIT2_DR)   |
                                      (current_state == `TAP_UPDATE_DR)  |
                                      (current_state == `TAP_IR_SCAN)    |
                                      (current_state == `TAP_CAPTURE_IR) |
                                      (current_state == `TAP_UPDATE_IR)  ;

    wire extest_mode                = ~(|instruction_reg) & mode_valid;
    wire id_code_mode               = ~instruction_reg[7] & ~instruction_reg[6] &  instruction_reg[5] & ~instruction_reg[4] &
                                      ~instruction_reg[3] & ~instruction_reg[2] & ~instruction_reg[1] &  instruction_reg[0] &
                                       mode_valid;
    wire sample_preload_mode        = ~instruction_reg[7] & ~instruction_reg[6] & ~instruction_reg[5] & ~instruction_reg[4] &
                                      ~instruction_reg[3] &  instruction_reg[2] & ~instruction_reg[1] &  instruction_reg[0] &
                                       mode_valid;
    wire clamp_mode                 = ~instruction_reg[7] & ~instruction_reg[6] & ~instruction_reg[5] & ~instruction_reg[4] &
                                      ~instruction_reg[3] &  instruction_reg[2] &  instruction_reg[1] &  instruction_reg[0] &
                                       mode_valid;
    wire highZ_mode                 = ~instruction_reg[7] & ~instruction_reg[6] & ~instruction_reg[5] & ~instruction_reg[4] &
                                      ~instruction_reg[3] & ~instruction_reg[2] &  instruction_reg[1] &  instruction_reg[0] &
                                       mode_valid;
    wire bypass_mode                =  (&instruction_reg) & mode_valid;


    wire boundary_scan_shift_en     = (extest_mode         & (current_state == `TAP_SHIFT_DR)   ) |
                                      (sample_preload_mode & (current_state == `TAP_SHIFT_DR)   ) ;
    wire boundary_scan_load_en      = (extest_mode         & (current_state == `TAP_CAPTURE_DR) ) |
                                      (sample_preload_mode & (current_state == `TAP_CAPTURE_DR) ) ;

    wire instruction_reg_shift_en   = (current_state == `TAP_SHIFT_IR)   ;
    wire instruction_reg_reset_en   = (current_state == `TAP_RESET)      ;
    wire instruction_reg_load_en    = (current_state == `TAP_CAPTURE_IR) ;

    wire ID_reg_shift_en            = (id_code_mode        & (current_state == `TAP_SHIFT_DR)   ) ;
    wire ID_reg_load_en             = (id_code_mode        & (current_state == `TAP_CAPTURE_DR) ) ;

    wire bypass_reg_shift_en        = (bypass_mode         & (current_state == `TAP_SHIFT_DR)   ) |
                                      (clamp_mode          & (current_state == `TAP_SHIFT_DR)   ) |
                                      (highZ_mode          & (current_state == `TAP_SHIFT_DR)   ) ;
    wire bypass_reg_load_en         = (bypass_mode         & (current_state == `TAP_CAPTURE_DR)  ) |
                                      (clamp_mode          & (current_state == `TAP_CAPTURE_DR)  ) |
                                      (highZ_mode          & (current_state == `TAP_CAPTURE_DR)  ) ;

    always@* begin
        //-------------------- Boundary scan operations ---------------------------
        if (boundary_scan_shift_en) begin
            tdo_out = boundary_scan_reg[0] ;
            for (i=0; i<112; i=i+1) begin
                boundary_scan_reg_next[i] = boundary_scan_reg[i+1] ;
            end
            boundary_scan_reg_next[112] = tdi_in ;
        end else if (boundary_scan_load_en) begin
            boundary_scan_reg_next = boundary_scan_reg_info ;
        end else begin
            boundary_scan_reg_next = boundary_scan_reg ;
        end
        //-------------------- Instruction Register operations ---------------------------
        if (instruction_reg_shift_en) begin
            tdo_out = instruction_reg[0] ;
            for (i=0; i<7; i=i+1) begin
                instruction_reg_next[i] = instruction_reg[i+1] ;
            end
            instruction_reg_next[7] = tdi_in ;
        end else if (instruction_reg_reset_en) begin
            instruction_reg_next = `IDCODE ;
        end else if (instruction_reg_load_en) begin
            instruction_reg_next[1:0] = 2'b01 ;
        end else begin
            instruction_reg_next = instruction_reg ;
        end
        //-------------------- ID Register operations ---------------------------
        if (ID_reg_shift_en) begin
            tdo_out = ID_reg[0] ;
            for (i=0; i<31; i=i+1) begin
                ID_reg_next[i] = ID_reg[i+1] ;
            end
            ID_reg_next[31] = tdi_in ;
        end else if (ID_reg_load_en) begin
            ID_reg_next = ID ;
        end else begin
            ID_reg_next = ID_reg ;
        end
        //-------------------- Bypass Register operations ---------------------------
        if (bypass_reg_shift_en) begin
            tdo_out = bypass_reg ;
            bypass_reg_next = tdi_in ;
        end else if (bypass_reg_load_en) begin
            bypass_reg_next = 1'b0 ;
        end else begin
            bypass_reg_next = bypass_reg;
        end
        //-------------------- TAP RESET TDO HIGHZ STATE ---------------------------
        if ((current_state == `TAP_SHIFT_DR) | (current_state == `TAP_SHIFT_IR)) begin
            tdo_reg_next      <= tdo_out ;
        end else begin
            tdo_reg_next      <= 1'bz ;
        end

    end

    always @* begin
        if (current_state == `TAP_RESET) begin
            if(tms == 1'b0) begin
                next_state = `TAP_IDLE ;
            end else begin
                next_state = `TAP_RESET ;
            end
        end
        if (current_state == `TAP_IDLE) begin
            if(tms == 1'b0) begin
                next_state = `TAP_IDLE ;
            end else begin
                next_state = `TAP_DR_SCAN ;
            end
        end
        if (current_state == `TAP_DR_SCAN) begin
            if(tms == 1'b0) begin
                next_state = `TAP_CAPTURE_DR ;
            end else begin
                next_state = `TAP_IR_SCAN ;
            end
        end
        if (current_state == `TAP_CAPTURE_DR) begin
            if(tms == 1'b0) begin
                next_state = `TAP_SHIFT_DR ;
            end else begin
                next_state = `TAP_EXIT1_DR ;
            end
        end
        if (current_state == `TAP_SHIFT_DR) begin
            if(tms == 1'b0) begin
                next_state = `TAP_SHIFT_DR ;
            end else begin
                next_state = `TAP_EXIT1_DR ;
            end
        end
        if (current_state == `TAP_EXIT1_DR) begin
            if(tms == 1'b0) begin
                next_state = `TAP_PAUSE_DR ;
            end else begin
                next_state = `TAP_UPDATE_DR ;
            end
        end
        if (current_state == `TAP_PAUSE_DR) begin
            if(tms == 1'b0) begin
                next_state = `TAP_PAUSE_DR ;
            end else begin
                next_state = `TAP_EXIT2_DR ;
            end
        end
        if (current_state == `TAP_EXIT2_DR) begin
            if(tms == 1'b0) begin
                next_state = `TAP_SHIFT_DR ;
            end else begin
                next_state = `TAP_UPDATE_DR ;
            end
        end
        if (current_state == `TAP_UPDATE_DR) begin
            if(tms == 1'b0) begin
                next_state = `TAP_IDLE ;
            end else begin
                next_state = `TAP_DR_SCAN ;
            end
        end
        if (current_state == `TAP_IR_SCAN) begin
            if(tms == 1'b0) begin
                next_state = `TAP_CAPTURE_IR ;
            end else begin
                next_state = `TAP_RESET ;
            end
        end
        if (current_state == `TAP_CAPTURE_IR) begin
            if(tms == 1'b0) begin
                next_state = `TAP_SHIFT_IR ;
            end else begin
                next_state = `TAP_EXIT1_IR ;
            end
        end
        if (current_state == `TAP_SHIFT_IR) begin
            if(tms == 1'b0) begin
                next_state = `TAP_SHIFT_IR ;
            end else begin
                next_state = `TAP_EXIT1_IR ;
            end
        end
        if (current_state == `TAP_EXIT1_IR) begin
            if(tms == 1'b0) begin
                next_state = `TAP_PAUSE_IR ;
            end else begin
                next_state = `TAP_UPDATE_IR ;
            end
        end
        if (current_state == `TAP_PAUSE_IR) begin
            if(tms == 1'b0) begin
                next_state = `TAP_PAUSE_IR ;
            end else begin
                next_state = `TAP_EXIT2_IR ;
            end
        end
        if (current_state == `TAP_EXIT2_IR) begin
            if(tms == 1'b0) begin
                next_state = `TAP_SHIFT_IR ;
            end else begin
                next_state = `TAP_UPDATE_IR ;
            end
        end
        if (current_state == `TAP_UPDATE_IR) begin
            if(tms == 1'b0) begin
                next_state = `TAP_IDLE ;
            end else begin
                next_state = `TAP_DR_SCAN ;
            end
        end
    end

    always@(posedge tck) begin
        current_state <= next_state ;
        boundary_scan_reg <= boundary_scan_reg_next ;
        bypass_reg        <= bypass_reg_next ;
        ID_reg            <= ID_reg_next ;
        instruction_reg   <= instruction_reg_next ;
    end

    always@(negedge tck) begin
        tdo_reg           <= tdo_reg_next ;
    end

    //-------------------- Output Port Assignments ---------------------------

    assign tdo = tdo_reg ;

endmodule
