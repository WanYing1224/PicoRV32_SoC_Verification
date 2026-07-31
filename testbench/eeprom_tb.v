`timescale 1ns/1ps
module eeprom_tb;

    reg  sck = 0, csb = 1, si = 0;
    wire so;
    reg  tb_non_responsive = 0;
    integer errors = 0;

    eeprom_model #(.WRITE_CYCLES(5)) dut (
        .sck (sck), 
        .csb (csb), 
        .si (si), 
        .so (so),
        .tb_non_responsive (tb_non_responsive)
    );

    // one bit out, one bit in, per call - mode 0,0: drive SI before rising edge, sample SO after falling edge
    task automatic xfer_bit(input bit_in, output bit_out);
        begin
            si = bit_in;
            #5 sck = 1;   // rising edge - DUT samples SI
            #5 sck = 0;   // falling edge - DUT drives SO
            bit_out = so;
        end
    endtask

    task automatic xfer_byte(input [7:0] byte_in, output [7:0] byte_out);
        integer i;
        reg b;
        begin
            for (i = 7; i >= 0; i = i - 1) begin
                xfer_bit(byte_in[i], b);
                byte_out[i] = b;
            end
        end
    endtask

    reg [7:0] junk;
    reg [7:0] rdata;
    reg [7:0] status;

    initial begin
        $display("=== B1: EEPROM read/write verification ===");

        // --- Case 1: write WITHOUT WREN first -> must be rejected ---
        csb = 0;
        xfer_byte(8'h02, junk);        // WRITE opcode
        xfer_byte(8'h05, junk);        // addr 5
        xfer_byte(8'hAA, junk);        // data
        csb = 1; #10;
        csb = 0; xfer_byte(8'h05, junk); csb = 1; // RDSR
        csb = 0; xfer_byte(8'h05, junk); xfer_byte(8'h00, status); csb = 1; #10;
        if (status[0] !== 1'b0) begin
            $display("FAIL: WIP set after a write that should have been rejected (WEL was 0)");
            errors = errors + 1;
        end 
        else
            $display("PASS: write without WREN correctly rejected");

        // --- Case 2: WREN, then WRITE, then read back ---
        csb = 0; xfer_byte(8'h06, junk); csb = 1; #10;      // WREN
        csb = 0;
        xfer_byte(8'h02, junk);        // WRITE
        xfer_byte(8'h05, junk);        // addr 5
        xfer_byte(8'hAA, junk);        // data = 0xAA
        csb = 1;
        // wait for WIP to clear (WRITE_CYCLES=5, sampled on sck/csb edges - just wait real time)
        #200;

        csb = 0; xfer_byte(8'h03, junk); xfer_byte(8'h05, junk); xfer_byte(8'h00, rdata); csb = 1; #10;
        if (rdata !== 8'hAA) begin
            $display("FAIL: read back %02h, expected AA", rdata);
            errors = errors + 1;
        end 
        else
            $display("PASS: write-then-readback matched (0xAA)");

        // --- Case 3: page-boundary wraparound (PAGE_SIZE=16, addr 14 -> write 4 bytes) ---
        csb = 0; xfer_byte(8'h06, junk); csb = 1; #10; // WREN
        csb = 0;
        xfer_byte(8'h02, junk);         // WRITE
        xfer_byte(8'h0E, junk);         // addr 14 (page 0, offset 14)
        xfer_byte(8'h11, junk);         // -> addr 14
        xfer_byte(8'h22, junk);         // -> addr 15
        xfer_byte(8'h33, junk);         // -> addr 0  (WRAP, not addr 16)
        xfer_byte(8'h44, junk);         // -> addr 1
        csb = 1; #200;

        csb = 0; xfer_byte(8'h03, junk); xfer_byte(8'h00, junk); xfer_byte(8'h00, rdata); csb = 1; #10;
        if (rdata !== 8'h33) begin
            $display("FAIL: page-wrap check - addr 0 = %02h, expected 33", rdata);
            errors = errors + 1;
        end 
        else
            $display("PASS: page-boundary wraparound correct (addr wrapped to 0, not 16)");

        // --- Case 4: WEL auto-clears after a write (second write without re-sending WREN must fail) ---
        csb = 0;
        xfer_byte(8'h02, junk);         // WRITE, no WREN resent
        xfer_byte(8'h05, junk);
        xfer_byte(8'hFF, junk);
        csb = 1; #200;
        csb = 0; xfer_byte(8'h03, junk); xfer_byte(8'h05, junk); xfer_byte(8'h00, rdata); csb = 1; #10;
        if (rdata === 8'hFF) begin
            $display("FAIL: write succeeded without re-sending WREN - WEL did not auto-clear");
            errors = errors + 1;
        end 
        else
            $display("PASS: WEL correctly auto-cleared, second write without WREN rejected (addr 5 still 0xAA)");

        if (errors == 0)
            $display("=== ALL B1 TESTS PASSED ===");
        else
            $display("=== %0d TEST(S) FAILED ===", errors);

        $finish;
    end

endmodule
