// Immediate Generator

/*
Instruction:        | instr
---------------------------------
Immediate Type:     | imm_sel
---------------------------------
Immediate Output:   | imm
*/

module imm_gen(input [31:0] instr, input [2:0] imm_sel, output reg [31:0] imm);
    // Associate each immediate type to a value
    localparam IMM_I = 3'd0;
    localparam IMM_S = 3'd1;
    localparam IMM_B = 3'd2;
    localparam IMM_U = 3'd3;
    localparam IMM_J = 3'd4;

    // Select immediate type depending on the input (imm_sel)
    always @(*) begin
        case (imm_sel)
            IMM_I: imm = {{20{instr[31]}}, instr[31:20]};
            IMM_S: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            IMM_B: imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            IMM_U: imm = {instr[31:12], 12'b0};
            IMM_J: imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            // Return zero if invalid immediate type is selected
            default: imm = 32'b0;
        endcase
    end
endmodule