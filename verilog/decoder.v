// RV32I Instruction Decoder

/*
Instruction:                    | instr
-------------------------------------------
Opcode:                         | opcode
-------------------------------------------
Funct7:                         | funct7
-------------------------------------------
Destination Register Address:   | rd
-------------------------------------------
Source Register 1 Address:      | rs1
-------------------------------------------
Source Register 2 Address:      | rs2
-------------------------------------------
Funct3:                         | funct3
*/

module decoder(input [31:0] instr, output [6:0] opcode, funct7, output [4:0] rd, rs1, rs2, output [2:0] funct3);
    // Decode instructions into parts
    assign opcode = instr[6:0];
    assign rd = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];
    assign funct7 = instr[31:25];
endmodule