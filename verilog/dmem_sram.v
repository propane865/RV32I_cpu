// SRAM wrapper for dmem, 4KB byte-addressable data memory
// Uses two sky130_sram_2kbyte_1rw1r_32x512_8 macros
// Handles byte (width=00), halfword (width=01), word (width=10) accesses with sign/zero extension on read

`ifdef USE_POWER_PINS
`define PWR_PINS inout vccd1, inout vssd1,
`define PWR_CONN .vccd1(vccd1), .vssd1(vssd1),
`else
`define PWR_PINS
`define PWR_CONN
`endif

module dmem (input clk, input w_ena, input is_signed, input [1:0] width, input [31:0] addr, input [31:0] w_data, output reg [31:0] r_data);
    // Word address and bank select
    wire [9:0] word_addr = addr[11:2];
    wire sel_upper = word_addr[9];
    wire [8:0] sram_addr = word_addr[8:0];

    // Byte offset within the word (for sub-word reads)
    wire [1:0] byte_off = addr[1:0];

    // Generate wmask from width and byte offset (wmask gates which bytes get written)
    reg [3:0] wmask;
    always @(*) begin
        case (width)
            // Byte
            2'b00: begin  
                wmask = 4'b0001 << byte_off;
            end
            // Halfword
            2'b01: begin  
                wmask = 4'b0011 << byte_off;
            end
            // Word
            2'b10: begin  
                wmask = 4'b1111;
            end
            default: wmask = 4'b0000;
        endcase
    end

    // Replicate write data across all byte lanes
    wire [31:0] wdata_rep;
    assign wdata_rep = (width == 2'b00) ? {4{w_data[7:0]}} : (width == 2'b01) ? {2{w_data[15:0]}} : w_data;

    wire cs_lo = ~sel_upper;
    wire cs_hi = sel_upper;

    wire [31:0] rdata_lo, rdata_hi;

    // Lower 2KB: words 0-511
    sky130_sram_2kbyte_1rw1r_32x512_8 sram0 (
        `PWR_CONN
        // Port 0 (RW)
        .clk0  (clk),
        .csb0  (~cs_lo),           // Active-low chip select
        .web0  (~w_ena),           // Active-low write enable
        .wmask0(wmask),
        .addr0 (sram_addr),
        .din0  (wdata_rep),
        .dout0 (rdata_lo),
        // Port 1 (R), Inactive
        .clk1  (1'b0),
        .csb1  (1'b1),
        .addr1 (9'b0),
        .dout1 ()
    );

    // Upper 2KB: words 512-1023
    sky130_sram_2kbyte_1rw1r_32x512_8 sram1 (
        `PWR_CONN
        .clk0  (clk),
        .csb0  (~cs_hi),
        .web0  (~w_ena),
        .wmask0(wmask),
        .addr0 (sram_addr),
        .din0  (wdata_rep),
        .dout0 (rdata_hi),
        .clk1  (1'b0),
        .csb1  (1'b1),
        .addr1 (9'b0),
        .dout1 ()
    );

    wire [31:0] raw = sel_upper ? rdata_hi : rdata_lo;

    // Sign/zero extension on read
    always @(*) begin
        case (width)
            2'b00: r_data = is_signed ? {{24{raw[byte_off*8 +: 1][0]}}, raw[byte_off*8 +: 8]} : {24'b0, raw[byte_off*8 +: 8]};
            2'b01: r_data = is_signed ? {{16{raw[byte_off*8+15]}}, raw[byte_off*8 +: 16]} : {16'b0, raw[byte_off*8 +: 16]};
            2'b10: r_data = raw;
            default: r_data = 32'b0;
        endcase
    end

endmodule