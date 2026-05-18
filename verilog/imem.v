// Instruction Memory (4 kB) Behavioral Model

/*
Program Counter:        | pc
---------------------------------
Instruction Output:     | instr
*/

module imem(input [31:0] pc, output[31:0] instr);
    // 1024 memory cells, 4 bytes (32 bits) each
    reg [31:0] mem [0:1023];

    // Readout an instruction from the ram, using the program counter for the source address
    assign instr = mem[pc[11:2]];

    // Initialize memory to all NOP instructions (for simulation only)
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            mem[i] = 32'h00000013;
        end
    end
endmodule