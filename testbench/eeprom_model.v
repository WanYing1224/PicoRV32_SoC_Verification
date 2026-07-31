// eeprom_model.v — real bit-level SPI slave behavioral model
// Based on 25AA010A/25LC010A (DS22040A/DS22040C), SPI Mode 0,0
// CSB low = frame active. Opcode(8) then Addr(8, only [6:0] used) then data byte(s).

module eeprom_model #(
    parameter MEM_BYTES    = 128,
    parameter PAGE_SIZE    = 16,
    parameter WRITE_CYCLES = 20      // scaled down for sim; real part is ~5ms max
) (
    input  wire sck,
    input  wire csb,
    input  wire si,
    output reg  so,
    input  wire tb_non_responsive
);

    localparam OP_WRSR  = 8'h01;
    localparam OP_WRITE = 8'h02;
    localparam OP_WRDI  = 8'h04;
    localparam OP_RDSR  = 8'h05;
    localparam OP_WREN  = 8'h06;
    localparam OP_READ  = 8'h03;

    localparam S_OPCODE=0, S_ADDR=1, S_READ=2, S_WRITE=3, S_RDSR=4, S_WRSR=5, S_IGNORE=6;

    reg [2:0]  state;
    reg [7:0]  shreg_in;
    reg [3:0]  bitcnt;
    reg [7:0]  opcode;
    reg [6:0]  addr;
    reg [7:0]  mem [0:MEM_BYTES-1];
    reg        WEL, WIP;
    reg [31:0] write_timer;
    reg        wrote_this_frame;   // per-frame flag - do NOT use a cumulative counter here

    always @(posedge sck or posedge csb) begin
        if (WIP && write_timer > 0)
            write_timer <= write_timer - 1;
        else if (WIP && write_timer == 0)
            WIP <= 0;
    end

    always @(posedge csb) begin
        state            <= S_OPCODE;
        bitcnt           <= 0;
        wrote_this_frame <= 0;
    end

    always @(posedge sck) begin
        if (!csb) begin
            shreg_in <= {shreg_in[6:0], si};
            bitcnt   <= bitcnt + 1;

            case (state)
                S_OPCODE: if (bitcnt == 7) begin
                    opcode <= {shreg_in[6:0], si};
                    bitcnt <= 0;
                    case ({shreg_in[6:0], si})
                        OP_WREN:  begin WEL <= 1; state <= S_IGNORE; end
                        OP_WRDI:  begin WEL <= 0; state <= S_IGNORE; end
                        OP_RDSR:  state <= S_RDSR;
                        OP_READ:  state <= S_ADDR;
                        OP_WRITE: state <= S_ADDR;
                        OP_WRSR:  state <= S_WRSR;
                        default:  state <= S_IGNORE;
                    endcase
                end

                S_ADDR: if (bitcnt == 7) begin
                    addr   <= {shreg_in[5:0], si};
                    bitcnt <= 0;
                    state  <= (opcode == OP_READ) ? S_READ : S_WRITE;
                end

                S_WRITE: if (bitcnt == 7) begin
                    bitcnt <= 0;
                    if (!WEL) begin
                        $display("[EEPROM] WRITE REJECTED - WEL not set");
                    end else if (tb_non_responsive) begin
                        $display("[EEPROM] non-responsive mode");
                    end else begin
                        mem[addr]        <= {shreg_in[6:0], si};
                        wrote_this_frame <= 1;
                        addr             <= {addr[6:4], addr[3:0] + 1'b1}; // wraps within page
                    end
                end

                S_WRSR: if (bitcnt == 7) begin
                    bitcnt <= 0;
                    state  <= S_IGNORE;
                end

                default: ; // S_READ / S_RDSR: output side handled below. S_IGNORE: eat remaining bits.
            endcase
        end
    end

    always @(negedge sck) begin
        if (!csb && state == S_RDSR)
            so <= {4'b0000, 2'b00, WEL, WIP} >> (3'd7 - bitcnt[2:0]);
        else if (!csb && state == S_READ)
            so <= mem[addr] >> (3'd7 - bitcnt[2:0]);
        else
            so <= 1'bz;
    end

    always @(posedge csb) begin
        if (wrote_this_frame) begin
            WIP         <= 1;
            write_timer <= WRITE_CYCLES;
            WEL         <= 0; // auto-clears - must resend WREN before next write
        end
    end

endmodule
