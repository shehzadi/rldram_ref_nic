/****************************************************************************************
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
****************************************************************************************/

`define sg25
`define x36

    // Parameters current with 576Mb datasheet rev C

    // Timing parameters based on Speed Grade

                                          // SYMBOL     UNITS    DESCRIPTION
                                          // ------     -----    -----------
`ifdef sg18
    parameter TCK_MIN          =    1875; // tCK        ps       Minimum Clock Cycle Time
    parameter TCK_MAX          =    5700; // tCK        ps       Maximum Clock Cycle Time
    parameter TDK_MIN          =    1875; // tDK        ps       Minimum Clock Cycle Time
    parameter TDK_MAX          =    5700; // tCK        ps       Maximum Clock Cycle Time
    parameter TJIT_PER         =     100; // tJIT(per)  ps       Period JItter
    parameter TJIT_CC          =     200; // tJIT(cc)   ps       Cycle to Cycle jitter
    parameter TCKDK_MIN        =    -300; // tCK        ps       Clock to input data clock
    parameter TCKDK_MAX        =     300; // tCK        ps       Clock to input data clock
    parameter TAS              =     300; // tAS        ps       Address input setup time
    parameter TCS              =     300; // tAS        ps       Command input setup time
    parameter TDS              =     170; // tDS        ps       Data in and data mask to DK setup time
    parameter TAH              =     170; // tAH        ps       Address input hold time
    parameter TCH              =     170; // tAH        ps       Command input hold time
    parameter TDH              =     170; // tDH        ps       Data in and data mask to DK hold time
    parameter TCKQK            =     200; // tCKQK      ps       QK edge to clock skew edge
    parameter TQKQ0            =     200; // tQKQ0      ps       QK edge to output data edge
    parameter TQKQ1            =     200; // tQKQ1      ps       QK edge to output data edge
    parameter TQKQ             =     220; // tQKQ       ps       QK edge to any output data edge
    parameter TQKVLD           =     220; // tQKVLD     ps       QK edge to QVLD
    parameter TRC              =   15000; // tRC        ps       Random cycle time
`elsif sg25E
    parameter TCK_MIN          =    2500; // tCK        ps       Minimum Clock Cycle Time
    parameter TCK_MAX          =    5700; // tCK        ps       Maximum Clock Cycle Time
    parameter TDK_MIN          =    2500; // tDK        ps       Minimum Clock Cycle Time
    parameter TDK_MAX          =    5700; // tCK        ps       Maximum Clock Cycle Time
    parameter TJIT_PER         =     150; // tJIT(per)  ps       Period JItter
    parameter TJIT_CC          =     300; // tJIT(cc)   ps       Cycle to Cycle jitter
    parameter TCKDK_MIN        =    -450; // tCK        ps       Clock to input data clock
    parameter TCKDK_MAX        =     500; // tCK        ps       Clock to input data clock
    parameter TAS              =     400; // tAS        ps       Address input setup time
    parameter TCS              =     400; // tAS        ps       Command input setup time
    parameter TDS              =     250; // tDS        ps       Data in and data mask to DK setup time
    parameter TAH              =     250; // tAH        ps       Address input hold time
    parameter TCH              =     250; // tAH        ps       Command input hold time
    parameter TDH              =     250; // tDH        ps       Data in and data mask to DK hold time
    parameter TCKQK            =     250; // tCKQK      ps       QK edge to clock skew edge
    parameter TQKQ0            =     250; // tQKQ0      ps       QK edge to output data edge
    parameter TQKQ1            =     250; // tQKQ1      ps       QK edge to output data edge
    parameter TQKQ             =     300; // tQKQ       ps       QK edge to any output data edge
    parameter TQKVLD           =     300; // tQKVLD     ps       QK edge to QVLD
    parameter TRC              =   15000; // tRC        ps       Random cycle time
`elsif sg25
    parameter TCK_MIN          =    2500; // tCK        ps       Minimum Clock Cycle Time
    parameter TCK_MAX          =    5700; // tCK        ps       Maximum Clock Cycle Time
    parameter TDK_MIN          =    2500; // tDK        ps       Minimum Clock Cycle Time
    parameter TDK_MAX          =    5700; // tCK        ps       Maximum Clock Cycle Time
    parameter TJIT_PER         =     150; // tJIT(per)  ps       Period JItter
    parameter TJIT_CC          =     300; // tJIT(cc)   ps       Cycle to Cycle jitter
    parameter TCKDK_MIN        =    -450; // tCK        ps       Clock to input data clock
    parameter TCKDK_MAX        =     500; // tCK        ps       Clock to input data clock
    parameter TAS              =     400; // tAS        ps       Address input setup time
    parameter TCS              =     400; // tAS        ps       Command input setup time
    parameter TDS              =     250; // tDS        ps       Data in and data mask to DK setup time
    parameter TAH              =     400; // tAH        ps       Address input hold time
    parameter TCH              =     400; // tAH        ps       Command input hold time
    parameter TDH              =     250; // tDH        ps       Data in and data mask to DK hold time
    parameter TCKQK            =     250; // tCKQK      ps       QK edge to clock skew edge
    parameter TQKQ0            =     200; // tQKQ0      ps       QK edge to output data edge
    parameter TQKQ1            =     200; // tQKQ1      ps       QK edge to output data edge
    parameter TQKQ             =     300; // tQKQ       ps       QK edge to any output data edge
    parameter TQKVLD           =     300; // tQKVLD     ps       QK edge to QVLD
    parameter TRC              =   20000; // tRC        ps       Random cycle time
`elsif sg33
    parameter TCK_MIN          =    3300; // tCK        ps       Minimum Clock Cycle Time
    parameter TCK_MAX          =    5700; // tCK        ps       Maximum Clock Cycle Time
    parameter TDK_MIN          =    3300; // tDK        ps       Minimum Clock Cycle Time
    parameter TDK_MAX          =    5700; // tCK        ps       Maximum Clock Cycle Time
    parameter TJIT_PER         =     200; // tJIT(per)  ps       Period JItter
    parameter TJIT_CC          =     400; // tJIT(cc)   ps       Cycle to Cycle jitter
    parameter TCKDK_MIN        =    -450; // tCK        ps       Clock to input data clock
    parameter TCKDK_MAX        =    1200; // tCK        ps       Clock to input data clock
    parameter TAS              =     500; // tAS        ps       Address input setup time
    parameter TCS              =     500; // tAS        ps       Command input setup time
    parameter TDS              =     300; // tDS        ps       Data in and data mask to DK setup time
    parameter TAH              =     500; // tAH        ps       Address input hold time
    parameter TCH              =     500; // tAH        ps       Command input hold time
    parameter TDH              =     300; // tDH        ps       Data in and data mask to DK hold time
    parameter TCKQK            =     300; // tCKQK      ps       QK edge to clock skew edge
    parameter TQKQ0            =     250; // tQKQ0      ps       QK edge to output data edge
    parameter TQKQ1            =     250; // tQKQ1      ps       QK edge to output data edge
    parameter TQKQ             =     350; // tQKQ       ps       QK edge to any output data edge
    parameter TQKVLD           =     350; // tQKVLD     ps       QK edge to QVLD
    parameter TRC              =   19800; // tRC        ps       Random cycle time
`else
    `define sg5
    parameter TCK_MIN          =    5000; // tCK        ps       Minimum Clock Cycle Time
    parameter TCK_MAX          =    5700; // tCK        ps       Maximum Clock Cycle Time
    parameter TDK_MIN          =    5000; // tDK        ps       Minimum Clock Cycle Time
    parameter TDK_MAX          =    5700; // tCK        ps       Maximum Clock Cycle Time
    parameter TJIT_PER         =     250; // tJIT(per)  ps       Period JItter
    parameter TJIT_CC          =     500; // tJIT(cc)   ps       Cycle to Cycle jitter
    parameter TCKDK_MIN        =    -300; // tCK        ps       Clock to input data clock
    parameter TCKDK_MAX        =    1500; // tCK        ps       Clock to input data clock
    parameter TAS              =     800; // tAS        ps       Address input setup time
    parameter TCS              =     800; // tAS        ps       Command input setup time
    parameter TDS              =     400; // tDS        ps       Data in and data mask to DK setup time
    parameter TAH              =     800; // tAH        ps       Address input hold time
    parameter TCH              =     800; // tAH        ps       Command input hold time
    parameter TDH              =     400; // tDH        ps       Data in and data mask to DK hold time
    parameter TCKQK            =     500; // tCKQK      ps       QK edge to clock skew edge
    parameter TQKQ0            =     300; // tQKQ0      ps       QK edge to output data edge
    parameter TQKQ1            =     300; // tQKQ1      ps       QK edge to output data edge
    parameter TQKQ             =     400; // tQKQ       ps       QK edge to any output data edge
    parameter TQKVLD           =     400; // tQKVLD     ps       QK edge to QVLD
    parameter TRC              =   20000; // tRC        ps       Random cycle time
`endif

    // Timing Parameters
    parameter TCKQK_DLL_OFF    =    3500; // tCKQK      ps       QK edge to clock skew edge
    parameter TCKH_MIN         =    0.45; // tCKH       tCK      Minimum CK Clock HIGH time
    parameter TCKH_MAX         =    0.55; // tCKH       tCK      Maximum CK Clock HIGH time
    parameter TDKH_MIN         =    0.45; // tDKH       tCK      Minimum DK Clock HIGH time
    parameter TDKH_MAX         =    0.55; // tDKH       tCK      Maximum DK Clock HIGH time
    parameter TCKL_MIN         =    0.45; // tCKL       tCK      Minimum CK Clock LOW time
    parameter TCKL_MAX         =    0.55; // tCKL       tCK      Maximum CK Clock LOW time
    parameter TDKL_MIN         =    0.45; // tDKL       tCK      Minimum DK Clock LOW time
    parameter TDKL_MAX         =    0.55; // tDKL       tCK      Maximum DK Clock LOW time
    parameter TQKH_MIN         =     0.9; // tQKH       tCK      Minimum Output data clock HIGH time
    parameter TQKH_MAX         =     1.1; // tQKH       tCK      Maximum Output data clock HIGH time
    parameter TQKL_MIN         =     0.9; // tQKL       tCK      Minimum Output data clock LOW time
    parameter TQKL_MAX         =     1.1; // tQKL       tCK      Maximum Output data clock LOW time
    parameter TREF             =      32; // tREF       ms       Refresh Interval

    // Command and Address
    parameter BL_MIN           =       2; // BL         tCK      Minimum Burst Length
    parameter BL_MAX           =       8; // BL         tCK      Maximum Burst Length
    parameter CONFIG_MAX       =       5; // CONFIG              Maximum Configuration
    parameter TMRSC            =       6; // TMRSC      tCK      Load Mode Register command cycle time
    parameter TDLLK            =    1024; // tDLLK      tCK      DLL locking time

    // JTAG
    parameter TTHTH            =   20000; // tTHTH     ps        Minimum clock cycle time
    parameter TTLTH            =   10000; // tTLTH     ps        Minimum clock low time
    parameter TTHTL            =   10000; // tTHTL     ps        Minimum clock high time
    parameter TMVTH            =    5000; // tMVTH     ps        Minimum TMS setup time
    parameter TTHMX            =    5000; // tHMX      ps        Minimum TMS hold
    parameter TDVTH            =    5000; // TDVTH     ps        Minimum TDI setup
    parameter TTHDX            =    5000; // TTHDX     ps        Minimum TDI hold

    // Size Parameters based on Part Width
`ifdef x9
    parameter QK_BITS          =       1;
    parameter DK_BITS          =       1;
    parameter DM_BITS          =       1;
    parameter A_BITS           =      22;
    parameter DQ_BITS          =       9;
    `ifdef SIO
    parameter ID               = 32'h019a7059; // JTAG ID Register
    `else
    parameter ID               = 32'h011a7059; // JTAG ID Register
    `endif
`elsif x18
    parameter QK_BITS          =       2;
    parameter DK_BITS          =       1;
    parameter DM_BITS          =       1;
    parameter A_BITS           =      21;
    parameter DQ_BITS          =      18;
    `ifdef SIO
    parameter ID               = 32'h119a7059; // JTAG ID Register
    `else
    parameter ID               = 32'h111a7059; // JTAG ID Register
    `endif
`else
    `define x36
    parameter QK_BITS          =       2;
    parameter DK_BITS          =       2;
    parameter DM_BITS          =       1;
    parameter A_BITS           =      20;
    parameter DQ_BITS          =      36;
    parameter ID               = 32'h211a7059; // JTAG ID Register
`endif

    // Size Parameters
    parameter BA_BITS          =       3; // Set this parmaeter to control how many Bank Address bits are used
    parameter MEM_BITS         =      12; // Set this parameter to control how many write data bursts can be stored in memory.  The default is 2^12=4096.
    parameter BL_BITS          =       3; // the number of bits required to count to MAX_BL
    parameter ROWS            = 16*1024*8; // 16K Rows per bank

    // Simulation parameters
    parameter STOP_ON_ERROR    =       1; // If set to 1, the model will halt on command sequence/major errors
    parameter DEBUG            =       1; // Turn on Debug messages
    parameter BUS_DELAY        =       0; // delay in nanoseconds

    parameter RDQSEN_PRE       =       1; // DQS driving time prior to first read strobe
    parameter RDQSEN_PST       =       0; // DQS driving time after last read strobe
    parameter RDQEN_PRE        =       0; // DQ/DM driving time prior to first read data
    parameter RDQEN_PST        =       0; // DQ/DM driving time after last read data

