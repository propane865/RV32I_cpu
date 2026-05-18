// SRAM wrapper for imem (4 kB Instruction Memory)
// Uses two sky130_sram_2kbyte_1rw1r_32x512_8 macros (2KB each)
// Module imem is read-only from CPU perspective; writes only used at init/load time

// Port mapping: addr[11:2] = word address (1024 words x 32-bit)
// Lower half is addr[8:0] in sram0 (words 0-511)
// Upper half is addr[8:0] in sram1 (words 512-1023)

`ifdef USE_POWER_PINS
`define PWR_PINS inout vccd1, inout vssd1,
`define PWR_CONN .vccd1(vccd1), .vssd1(vssd1),
`else
`define PWR_PINS
`define PWR_CONN
`endif

module imem(input [31:0] pc, output [31:0] instr);
    // Addressable 1024 words
    wire [9:0] word_addr = pc[11:2];

    // Enable to read/write on upper half (sram1), disable to read/write on lower half (sram0)         
    wire sel_upper = word_addr[9];

    // 9-bit address for each 512-word macro
    wire [8:0] sram_addr = word_addr[8:0];

    // Unused
    wire [31:0] dout0_lo, dout0_hi;

    // Lower 2KB: words 0-511
    sky130_sram_2kbyte_1rw1r_32x512_8 sram0 (
        `PWR_CONN
        // Port 0 (RW), Inactive
        .clk0  (1'b0),
        .csb0  (1'b1),
        .web0  (1'b1),
        .wmask0(4'b0000),
        .addr0 (9'b0),
        .din0  (32'b0),
        .dout0 (dout0_lo),
        // Port 1 (R), fetch port
        .clk1  (1'b0),           // Asynchronous read (clockless)
        .csb1  (~sel_upper),     // Select if the address is in the lower half
        .addr1 (sram_addr),
        .dout1 (instr_lo)
    );

    // Upper 2KB: words 512-1023
    sky130_sram_2kbyte_1rw1r_32x512_8 sram1 (
        `PWR_CONN
        .clk0  (1'b0),
        .csb0  (1'b1),
        .web0  (1'b1),
        .wmask0(4'b0000),
        .addr0 (9'b0),
        .din0  (32'b0),
        .dout0 (dout0_hi),
        .clk1  (1'b0),
        .csb1  (sel_upper),      // Select if the address is in the upper half
        .addr1 (sram_addr),
        .dout1 (instr_hi)
    );

    wire [31:0] instr_lo, instr_hi;
    assign instr = sel_upper ? instr_hi : instr_lo;
endmodule