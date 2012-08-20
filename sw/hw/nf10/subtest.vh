/****************************************************************************************
*
*    File Name:  subtest.vh
*
*  Description:  Micron SDRAM RLDRAM 2 (Reduced Latency DRAM) test bench test case
*                This file is included by tb.v
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


    initial begin : test
        integer i;
        power_up;
        nop             (200);
        load_mode       (0, 'h0);
        load_mode       (0, 'h0);
        load_mode       (0, 'h80 | min_config);          // DLL ENABLED
        nop             (tmrsc-1);
    
        refresh    (0);
        refresh    (1);
        refresh    (2);
        refresh    (3);
        refresh    (4);
        refresh    (5);
        refresh    (6);
        refresh    (7);
        nop             (TDLLK);

        for (i=0; i<3; i=i+1) begin : bl_loop                  // run the test at BL2, BL4, and BL8
            if ((i == 2) && ((min_config == 1) || (min_config == 4))) begin
                disable bl_loop;
            end
            
            load_mode       (0, 'h80 | (i<<3) | min_config);
            nop             (tmrsc-1);
        
            // Test 
            write           (0, 0, 0, 'hC3D2E1F0);
            nop             (trc-1);                           // write to write - same bank

            write           (0, 1, 0, 'h23456789);
            nop             (trc_sbwr-1);                      // write to read - same bank

            read_verify     (0, 0, 0, 'hC3D2E1F0);
            nop             (trc-1);                           // read to read - same bank

            read_verify     (0, 1, 0, 'h23456789);
            nop             (trc-1);                           // read to write - same bank

            write           (0, 0, 0, 'h02101100);
            nop             (bl/2-1);                          // write to write - different bank

            write           (1, 0, 0, 'h31021011);
            nop             (bl/2-1);                          // write to write - different bank

            write           (2, 0, 0, 'h22120122);
            nop             (bl/2-1);                          // write to write - different bank

            write           (3, 0, 0, 'h13130133);
            nop             (bl/2-1);                          // write to write - different bank

            write           (4, 0, 0, 'h41140144);
            nop             (bl/2-1);                          // write to write - different bank

            write           (5, 0, 0, 'h25150155);
            nop             (bl/2-1);                          // write to write - different bank

            write           (6, 0, 0, 'h16160166);
            nop             (bl/2-1);                          // write to write - different bank

            write           (7, 0, 0, 'h17170177);
    `ifdef SIO
    `else
            nop             (bl/2);                            // write to read - different bank
    `endif

            read_verify     (0, 0, 0, 'h02101100);
            nop             (bl/2-1);                          // read to read - different bank

            read_verify     (1, 0, 0, 'h31021011);
            nop             (bl/2-1);                          // read to read - different bank

            read_verify     (2, 0, 0, 'h22120122);
            nop             (bl/2-1);                          // read to read - different bank

            read_verify     (3, 0, 0, 'h13130133);
            nop             (bl/2-1);                          // read to read - different bank

            read_verify     (4, 0, 0, 'h41140144);
            nop             (bl/2-1);                          // read to read - different bank

            read_verify     (5, 0, 0, 'h25150155);
            nop             (bl/2-1);                          // read to read - different bank

            read_verify     (6, 0, 0, 'h16160166);
            nop             (bl/2);                            // read to read + 1 - different bank

            read_verify     (7, 0, 0, 'h17170177);
    `ifdef SIO
    `else
            nop             (bl/2-1);                          // read to write - different bank
    `endif
            write           (0, 0, 0, 'hC3D2E1F0);
            nop             (trc-1);                           // write to read - same bank

            read_verify     (0, 0, 0, 'hC3D2E1F0);
            nop             (rl + bl);
        end

        // JTAG test section

        // command          argument(s)                                    comments
        // -------          -----------                                    --------
        // tms_high         (count)
        // tms_low          (count)
        // scan             (dr_ir, wdata, rdata, mask, shift_count)       DR=0, IR=1

        @(negedge jtag_tck); // sync up to TCK
        tb.tms_high(5); // go to test_logic_reset
        tb.tms_low(1); // go to run_test_idle
        tb.scan(0, 0, ID, 32'hFFFFFFFF, 32);

        test_done;
    end
