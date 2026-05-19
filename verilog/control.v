// CPU Control Unit

/*
Opcode:                         | opcode
-----------------------------------------------
Funct7:                         | funct7
-----------------------------------------------
Funct3:                         | funct3
-----------------------------------------------
ALU Source Select B:            | alu_src
-----------------------------------------------
Register Write Enable:          | reg_w_ena
-----------------------------------------------
Memory Write Enable:            | mem_w_ena
-----------------------------------------------
Memory Signed Read:             | mem_signed
-----------------------------------------------
ALU Input CIN:                  | alu_cin
-----------------------------------------------
ALU Input INVERT:               | alu_invert
-----------------------------------------------
ALU Input SIGNED COMPARISON:    | alu_sgn
-----------------------------------------------
ALU Input PASS:                 | alu_pass
-----------------------------------------------
Enable Branching:               | branch
-----------------------------------------------
Program Counter JAL:            | jump
-----------------------------------------------
Program Counter JALR:           | jalr
-----------------------------------------------
ALU Source Select A:            | alu_src_a
-----------------------------------------------
Writeback Selection:            | wb_sel
-----------------------------------------------
Memory R/W Width:               | mem_width
*/

module control(input [6:0] opcode, funct7, input [2:0] funct3, output reg alu_src, reg_w_ena, mem_w_ena, mem_signed, alu_cin, alu_invert, alu_sgn, alu_pass, branch, jump, jalr, output reg [1:0] alu_src_a, wb_sel, mem_width, output reg [2:0] alu_op, imm_sel, branch_cond);
    // Opcodes
    localparam OP = 7'b0110011;
    localparam OP_IMM = 7'b0010011;
    localparam LOAD = 7'b0000011;
    localparam STORE = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam LUI = 7'b0110111;
    localparam AUIPC = 7'b0010111;
    localparam JAL = 7'b1101111;
    localparam JALR = 7'b1100111;

    // ALU Operations
    localparam ALU_AND = 3'b000;
    localparam ALU_OR = 3'b001;
    localparam ALU_XOR = 3'b010;
    localparam ALU_ADD = 3'b011;
    localparam ALU_SHL = 3'b100;
    localparam ALU_SHA = 3'b101;
    localparam ALU_CMP = 3'b110;
    localparam ALU_EQ = 3'b111;

    // Immediate Constants
    localparam IMM_I = 3'd0;
    localparam IMM_S = 3'd1;
    localparam IMM_B = 3'd2;
    localparam IMM_U = 3'd3;
    localparam IMM_J = 3'd4;

    always @(*) begin
        // Initialize default signal values
        alu_op = ALU_ADD;
        alu_cin = 0;
        alu_invert = 0;
        alu_sgn = 0;
        alu_pass = 0;
        alu_src = 0;
        alu_src_a = 2'b0;
        reg_w_ena = 0;
        mem_w_ena = 0;
        mem_width = 2'b10;
        mem_signed = 0;
        wb_sel = 2'b00;
        branch = 0;
        jump = 0;
        jalr = 0;
        imm_sel = IMM_I;
        branch_cond = funct3;

        case (opcode)
            // R-type instructions
            OP: begin
                // Enable register writing, ALU inputs are from the registers
                reg_w_ena = 1;
                alu_src = 0;
                case (funct3)
                    // ADD/SUB: Addition and Subtraction
                    3'h0: begin
                        // Add (Default)
                        alu_op = ALU_ADD;

                        // Change to Subtract if funct7[5] is 1'b1, by inverting the output and incrementing using (alu_cin).
                        alu_cin = funct7[5];
                        alu_invert = funct7[5];
                    end

                    // XOR
                    3'h4: alu_op = ALU_XOR;

                    // OR
                    3'h6: alu_op = ALU_OR;

                    // AND
                    3'h7: alu_op = ALU_AND;

                    // SLL: Left Shift
                    3'h1: begin
                        // SLL
                        alu_op = ALU_SHL;

                        // Disable invert for left shift
                        alu_invert = 0;
                    end

                    // SRL/SRA: Right Shift
                    3'h5: begin
                        // Enable invert for right shift
                        alu_invert = 1;

                        // If funct7[5] is 1'b1, then do arithmetic shift, else do logical shift
                        case (funct7[5])
                            1'b0: begin
                                // SRL
                                alu_op = ALU_SHL;
                            end
                            1'b1: begin
                                // SRA
                                alu_op = ALU_SHA;
                            end
                        endcase
                    end

                    // SLT: Signed Comparison
                    3'h2: begin
                        alu_op = ALU_CMP;
                        
                        // Disable invert for less-than comparisons
                        alu_invert = 0;

                        // Enable signed comparison in ALU
                        alu_sgn = 1;
                    end

                    // SLTU: Unsigned Comparison
                    3'h3: begin
                        alu_op = ALU_CMP;
                        
                        // Disable invert for less-than comparisons
                        alu_invert = 0;

                        // Disable signed comparison in ALU
                        alu_sgn = 0;
                    end
                endcase
            end

            // I-type instructions
            OP_IMM: begin

                // Enable register writing, ALU input B is from the immediate
                reg_w_ena = 1;
                alu_src = 1;

                // Use I-type immediate encoding
                imm_sel = IMM_I;

                case (funct3)
                    // ADDI: Add Immediate
                    3'h0: alu_op = ALU_ADD;

                    // XORI: XOR Immediate
                    3'h4: alu_op = ALU_XOR;

                    // ORI: OR Immediate
                    3'h6: alu_op = ALU_OR;

                    // ANDI: AND Immediate
                    3'h7: alu_op = ALU_AND;

                    // SLLI: Shift Left by Immediate
                    3'h1: begin
                        // SLLI
                        alu_op = ALU_SHL;

                        // Disable invert for left shift
                        alu_invert = 0;
                    end

                    // SRLI/SRAI: Shift Right by Immediate
                    3'h5: begin
                        // Enable invert for right shift
                        alu_invert = 1;

                        // If funct7[5] is 1'b1, then do arithmetic shift, else do logical shift
                        case (funct7[5])
                            1'b0: begin
                                // SRLI
                                alu_op = ALU_SHL;
                            end
                            1'b1: begin
                                // SRAI
                                alu_op = ALU_SHA;
                            end
                        endcase
                    end

                    // SLTI: Signed Comparison with Immediate
                    3'h2: begin
                        alu_op = ALU_CMP;

                        // Disable invert for less-than comparisons
                        alu_invert = 0;

                        // Enable signed comparison for ALU
                        alu_sgn = 1;
                    end

                    // SLTIU: Unsigned Comparison with Immediate
                    3'h3: begin
                        alu_op = ALU_CMP;

                        // Disable invert for less-than comparisons
                        alu_invert = 0;

                        // Disable signed comparison for ALU
                        alu_sgn = 0;
                    end
                endcase
            end

            // Load instructions (I-type)
            LOAD: begin
                // Enable register writing, ALU input B is from the immediate
                reg_w_ena = 1;
                alu_src = 1;

                // Set ALU to ADD to compute the memory read address (rs1 + imm)
                alu_op = ALU_ADD;

                // Use I-type immediate encoding
                imm_sel = IMM_I;

                // Select writeback from memory readout rather than ALU
                wb_sel = 2'b01;

                // Determine whether to load a byte, a halfword, or a word from the instruction
                mem_width = funct3[1:0];

                // Determine whether to read the memory as a signed or unsigned value from the instruction
                mem_signed = ~funct3[2];
            end

            // Store instructions (S-type)
            STORE: begin
                // Enable register writing, ALU input B is from the immediate
                mem_w_ena = 1;
                alu_src = 1;

                // Set ALU to ADD to compute the memory write address (rs1 + imm)
                alu_op = ALU_ADD;

                // Use S-type immediate encoding
                imm_sel = IMM_S;

                // Determine whether to store a byte, a halfword, or a word from the instruction
                mem_width = funct3[1:0];
            end

            // Branch instructions (B-type)
            BRANCH: begin
                // Enable CPU branching
                branch = 1;

                // ALU is not used for these instructions, but both ALU inputs are from the registers
                alu_src = 0;

                // Use B-type immediate encoding
                imm_sel = IMM_B;

                // Branch condition type is determined by the instruction
                branch_cond = funct3;
            end

            // Load Upper Immediate (U-type)
            LUI: begin
                // Enable register writing, ALU input A is from the immediate
                reg_w_ena = 1;
                alu_src_a = 2'b10;

                // Enable ALU passthrough (no operation is performed on the input A)
                alu_pass = 1;

                // Use U-type immediate encoding
                imm_sel = IMM_U;
            end

            // Add Upper Immediate to Program Counter (U-type)
            AUIPC: begin
                // Enable register writing
                reg_w_ena = 1;

                // Set ALU to ADD to compute (imm + pc_current)
                alu_op = ALU_ADD;

                // ALU input B is from the immediate
                alu_src = 1;

                // ALU input A is from the program counter
                alu_src_a = 2'b01;

                // Use U-type immediate encoding
                imm_sel = IMM_U;
            end

            // Jump And Link (J-type)
            JAL: begin
                // Enable register writing
                reg_w_ena = 1;

                // Allow program counter to be rewritten to a target value
                jump = 1;

                // Select memory writeback from program counter plus 4
                wb_sel = 2'b10;

                // Use J-type immediate encoding
                imm_sel = IMM_J;
            end

            // Jump And Link Register (I-type)
            JALR: begin
                // Enable register writing
                reg_w_ena = 1;

                // Allow program counter to be rewritten to a target value
                jump = 1;

                // Allow the target value of the program counter to be computed as (rs1 + imm) instead of (pc_current + imm).
                jalr = 1;

                // Select memory writeback from program counter plus 4
                wb_sel = 2'b10;

                // Set ALU to ADD to compute (rs1 + imm)
                alu_op = ALU_ADD;

                // ALU input B is from the immediate
                alu_src = 1;

                // Use I-type immediate encoding
                imm_sel = IMM_I;
            end
        endcase
    end
endmodule