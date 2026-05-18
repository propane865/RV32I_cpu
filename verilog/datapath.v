// Link components of the CPU to form the datapath

/*
Clock:                  | clk
--------------------------------------
Reset:                  | rst
--------------------------------------
Program Counter:        | pc_out
--------------------------------------
Memory Address:         | dmem_addr
--------------------------------------
Memory Write Data:      | dmem_wdata
--------------------------------------
Memory Read Data:       | dmem_rdata
--------------------------------------
Memory Write Enable:    | dmem_w_ena
--------------------------------------
Memory Data Width:      | width
*/

module datapath(input clk, rst, output [31:0] pc_out, dmem_addr, dmem_wdata, dmem_rdata, output [1:0] dmem_width, output dmem_w_ena);
    // Initialize relevant wires
    wire [31:0] pc_current, pc_plus4, pc_target, instr, rs1_data, rs2_data, wb_data, alu_a, alu_b, alu_out, imm;
    wire [6:0] opcode, funct7;
    wire [4:0] rd, rs1, rs2;
    wire [2:0] funct3;

    wire alu_src, alu_cin, alu_invert, alu_sgn, alu_dir, alu_pass, reg_w_ena, mem_w_ena, mem_signed, branch, jump, jalr;
    wire [1:0] wb_sel, mem_width, alu_src_a;
    wire [2:0] alu_op, imm_sel, branch_cond;
    wire gr, le, eq;

    wire [31:0] mem_rdata;

    // ===============================================Stage 1 - Fetch===============================================

    // Load the Program Counter
    pc PC(
        .clk(clk),
        .rst(rst),
        .pc_src(pc_src),
        .pc_target(pc_target),
        .pc_out(pc_current),
        .pc_plus4(pc_plus4)
    );

    // Load instruction memory and link to the program counter
    imem IMEM(.pc(pc_current), .instr(instr));

    // ===============================================Stage 2 - Decode===============================================

    // Load the instruction decoder, and decode an instruction from memory
    decoder DEC(
        .instr(instr),
        .opcode(opcode),
        .rd(rd), .rs1(rs1), .rs2(rs2),
        .funct3(funct3), .funct7(funct7)
    );

    // Load the registers of the CPU, link inputs to the decoder
    regfile RF(
        .clk(clk),
        .w_ena(reg_w_ena),
        .rs1(rs1), .rs2(rs2), .rd(rd),
        .w_data(wb_data), .r_data1(rs1_data), .r_data2(rs2_data)
    );

    // Generate immediates from the instruction, depending on type of immediate
    imm_gen IMMGEN(.instr(instr), .imm_sel(imm_sel), .imm(imm));

    // Controller converts the input signals from the decoder to raw signals, which are passed to other CPU components
    control CTRL(
        .opcode(opcode),
        .funct7(funct7), .funct3(funct3),
        .alu_src(alu_src), .alu_src_a(alu_src_a),
        .reg_w_ena(reg_w_ena), .mem_w_ena(mem_w_ena),
        .mem_signed(mem_signed),
        .alu_cin(alu_cin), .alu_invert(alu_invert),
        .alu_sgn(alu_sgn), .alu_pass(alu_pass),
        .branch(branch), .jump(jump), .jalr(jalr),
        .wb_sel(wb_sel), .mem_width(mem_width),
        .alu_op(alu_op),
        .imm_sel(imm_sel),
        .branch_cond(branch_cond)
    );

    // ===============================================Stage 3 - Execute===============================================
    
    // Determine ALU inputs A and B:

    // alu_src_a = 2'b10: The immediate is passed to input A. 
    // alu_src_a = 2'b01: The program counter is passed instead.
    // If alu_src takes on any other value, then source register 1 is passed to imput A.
    assign alu_a = (alu_src_a == 2'b10) ? imm : (alu_src_a == 2'b01) ? pc_current : rs1_data;

    // If alu_src is 1'b1, then the immediate is passed to input B.
    // Otherwise, the source register 2 is passed to input B.
    assign alu_b = alu_src ? imm : rs2_data;

    // Instantiate the ALU with relevant inputs and outputs
    alu ALU(
        .a(alu_a), .b(alu_b), .cin(alu_cin),
        .pass(alu_pass), .invert(alu_invert), .sgn(alu_sgn),
        .op(alu_op),
        .out(alu_out), .cout(alu_cout)
    );

    // Branch comparator, returns the comparison between two source registers to determine CPU branching
    wire gr_b, le_b, eq_b;
    comp32 BCOMP(
        .a(rs1_data), .b(rs2_data),
        .u(funct3[1]),
        .gr(gr_b), .le(le_b), .eq(eq_b)
    );

    // Determine if a branch condition is met using the comparator. The signal (branch_cond) determines the type of comparison.
    reg condition_met_r;
    always @(*) begin
        case (branch_cond)
            3'b000: condition_met_r = eq_b;
            3'b001: condition_met_r = ~eq_b;
            3'b100: condition_met_r = le_b;
            3'b101: condition_met_r = gr_b | eq_b;
            3'b110: condition_met_r = le_b;
            3'b111: condition_met_r = gr_b | eq_b;
            default: condition_met_r = 1'b0;
        endcase
    end

    // Set the value of the program counter to a target value if jump instructions are passed, or if B-type instructions are passed, with satisfied branch conditions
    assign pc_src = jump | (branch & condition_met_r);

    // Set the program counter to source register 1 plus immediate if JALR is passed.
    // Else, set the program counter to its current value plus the immediate (passed by the J-type instruction). 
    assign pc_target = jalr ? (rs1_data + imm) & ~32'b1 : pc_current + imm;

    // ===============================================Stage 4 - Memory===============================================

    // Instantiate the data memory with relevant inputs and outputs.
    // The memory address being read from or written to is calculated by the ALU.
    // The data being written is the data within the source register 2, as referenced by any S-type operation.
    dmem DMEM(
        .clk(clk), .w_ena(mem_w_ena),
        .width(mem_width), .is_signed(mem_signed),
        .addr(alu_out),
        .w_data(rs2_data), .r_data(mem_rdata)
    );

    // ===============================================Stage 5 - Writeback===============================================

    // Determine the data to writeback into the registers.
    // wb_sel = 2'b00: Writeback the ALU output
    // wb_sel = 2'b01: Writeback the Memory Readout
    // wb_sel = 2'b10: Writeback the program counter plus 4
    reg [31:0] wb_data_r;
    always @(*) begin
        case (wb_sel)
            2'b00: wb_data_r = alu_out;
            2'b01: wb_data_r = mem_rdata;
            2'b10: wb_data_r = pc_plus4;
            default: wb_data_r = 32'b0;
        endcase
    end
    assign wb_data = wb_data_r;

    // Map internal signals to outputs
    assign pc_out = pc_current;
    assign dmem_addr = alu_out;
    assign dmem_wdata = rs2_data;
    assign dmem_rdata = mem_rdata;
    assign dmem_w_ena = mem_w_ena;
    assign dmem_width = mem_width;
endmodule