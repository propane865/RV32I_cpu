`timescale 1ns/1ps

module core_tb;

    // DUT signals
    reg clk, rst;
    wire dmem_w_ena;
    wire [1:0] dmem_width;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata, pc_out;

    rv32i_core DUT (.clk(clk), .rst(rst), .pc_out(pc_out), .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata), .dmem_w_ena(dmem_w_ena), .dmem_width(dmem_width));

    // Clock 
    initial clk = 0;
    always #5 clk = ~clk;

    // Shorthand paths
    `define RF   DUT.DP.RF.regs
    `define IMEM DUT.DP.IMEM.mem
    `define DMEM DUT.DP.DMEM.mem

    // Helpers
    integer failed = 0;

    function [31:0] read_reg;
        input [4:0] rnum;
        begin
            read_reg = (rnum == 5'b0) ? 32'b0 : `RF[rnum];
        end
    endfunction

    task check_reg;
        input [4:0]   rnum;
        input [31:0]  expected;
        input [127:0] name;
        begin
            if (read_reg(rnum) !== expected) begin
                $display("FAIL %-20s | x%-2d = 0x%08h | expected 0x%08h",
                        name, rnum, read_reg(rnum), expected);
                failed = failed + 1;
            end else
                $display("PASS %-20s | x%-2d = 0x%08h", name, rnum, read_reg(rnum));
        end
    endtask

    task check_mem_word;
        input [11:0]  addr;
        input [31:0]  expected;
        input [127:0] name;
        reg [31:0] got;
        begin
            got = {`DMEM[addr+3], `DMEM[addr+2], `DMEM[addr+1], `DMEM[addr]};
            if (got !== expected) begin
                $display("FAIL %-20s | mem[0x%03h] = 0x%08h | expected 0x%08h",
                         name, addr, got, expected);
                failed = failed + 1;
            end else
                $display("PASS %-20s | mem[0x%03h] = 0x%08h", name, addr, got);
        end
    endtask

    task run_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
            #1;
        end
    endtask

    // Clear memories and reset core
    task clear_mem;
        integer j;
        begin
            for (j = 0; j < 1024; j = j + 1) `IMEM[j] = 32'h00000013;
            for (j = 0; j < 4096; j = j + 1) `DMEM[j] = 8'h00;
        end
    endtask

    task release_reset;
        begin
            @(posedge clk);
            @(posedge clk);
            rst = 0;
            #1;
        end
    endtask

    // Test 1: Arithmetic & Logic
    task test_arith;
        begin
            $display("\n--- Test 1: Arithmetic & Logic ---");
            rst = 1;
            clear_mem;
            `IMEM[0] = 32'h00500093; // ADDI x1, x0, 5
            `IMEM[1] = 32'h00300113; // ADDI x2, x0, 3
            `IMEM[2] = 32'h002081b3; // ADD  x3, x1, x2
            `IMEM[3] = 32'h40208233; // SUB  x4, x1, x2
            `IMEM[4] = 32'h0020f2b3; // AND  x5, x1, x2
            `IMEM[5] = 32'h0020e333; // OR   x6, x1, x2
            `IMEM[6] = 32'h0020c3b3; // XOR  x7, x1, x2
            `IMEM[7] = 32'hfff00413; // ADDI x8, x0, -1
            `IMEM[8] = 32'h001404b3; // ADD  x9, x8, x1
            release_reset;
            run_cycles(10);
            check_reg(1, 32'h00000005, "ADDI +5");
            check_reg(2, 32'h00000003, "ADDI +3");
            check_reg(3, 32'h00000008, "ADD");
            check_reg(4, 32'h00000002, "SUB");
            check_reg(5, 32'h00000001, "AND");
            check_reg(6, 32'h00000007, "OR");
            check_reg(7, 32'h00000006, "XOR");
            check_reg(8, 32'hFFFFFFFF, "ADDI -1");
            check_reg(9, 32'h00000004, "ADD overflow");
        end
    endtask

    // Test 2: Shifts
    task test_shifts;
        begin
            $display("\n--- Test 2: Shifts ---");
            rst = 1;
            clear_mem;
            `IMEM[0] = 32'h00100093; // ADDI x1, x0, 1
            `IMEM[1] = 32'h00409113; // SLLI x2, x1, 4
            `IMEM[2] = 32'h00215193; // SRLI x3, x2, 2
            `IMEM[3] = 32'hff800213; // ADDI x4, x0, -8
            `IMEM[4] = 32'h40225293; // SRAI x5, x4, 2
            `IMEM[5] = 32'h00225313; // SRLI x6, x4, 2
            release_reset;
            run_cycles(7);
            check_reg(1, 32'h00000001, "ADDI base");
            check_reg(2, 32'h00000010, "SLLI x4");
            check_reg(3, 32'h00000004, "SRLI x2");
            check_reg(4, 32'hFFFFFFF8, "ADDI -8");
            check_reg(5, 32'hFFFFFFFE, "SRAI sign");
            check_reg(6, 32'h3FFFFFFE, "SRLI zero");
        end
    endtask

    // Test 3: Loads & Stores
    task test_loads_stores;
        begin
            $display("\n--- Test 3: Loads & Stores ---");
            rst = 1;
            clear_mem;
            `IMEM[0]  = 32'h0ab00093; // ADDI x1, x0, 0xAB
            `IMEM[1]  = 32'h00102023; // SW   x1, 0(x0)
            `IMEM[2]  = 32'h00002103; // LW   x2, 0(x0)
            `IMEM[3]  = 32'h00100223; // SB   x1, 4(x0)
            `IMEM[4]  = 32'h00400183; // LB   x3, 4(x0)
            `IMEM[5]  = 32'h00404203; // LBU  x4, 4(x0)
            `IMEM[6]  = 32'h1ff00293; // ADDI x5, x0, 0x1FF
            `IMEM[7]  = 32'h00501423; // SH   x5, 8(x0)
            `IMEM[8]  = 32'h00801303; // LH   x6, 8(x0)
            `IMEM[9]  = 32'hfff00293; // ADDI x5, x0, -1
            `IMEM[10] = 32'h00501623; // SH   x5, 12(x0)
            `IMEM[11] = 32'h00c05383; // LHU  x7, 12(x0)
            `IMEM[12] = 32'h00c01403; // LH   x8, 12(x0)
            release_reset;
            run_cycles(14);
            check_reg(2, 32'h000000AB, "LW");
            check_reg(3, 32'hFFFFFFAB, "LB sign-ext");
            check_reg(4, 32'h000000AB, "LBU zero-ext");
            check_reg(6, 32'h000001FF, "LH positive");
            check_reg(7, 32'h0000FFFF, "LHU zero-ext");
            check_reg(8, 32'hFFFFFFFF, "LH sign-ext");
            check_mem_word(12'h000, 32'h000000AB, "SW roundtrip");
        end
    endtask

    // Test 4: Comparisons
    task test_comparisons;
        begin
            $display("\n--- Test 4: Comparisons ---");
            rst = 1;
            clear_mem;
            `IMEM[0] = 32'h00500093; // ADDI x1, x0, 5
            `IMEM[1] = 32'h00300113; // ADDI x2, x0, 3
            `IMEM[2] = 32'hfff00193; // ADDI x3, x0, -1
            `IMEM[3] = 32'h0011a233; // SLT  x4, x2, x1
            `IMEM[4] = 32'h0020a2b3; // SLT  x5, x1, x2
            `IMEM[5] = 32'h0011a333; // SLT  x6, x3, x1
            `IMEM[6] = 32'h0011b3b3; // SLTU x7, x3, x1
            `IMEM[7] = 32'h00602413; // SLTI x8, x1, 6
            `IMEM[8] = 32'h0011b493; // SLTIU x9, x3, 1
            release_reset;
            run_cycles(10);
            check_reg(4, 32'h00000001, "SLT true");
            check_reg(5, 32'h00000000, "SLT false");
            check_reg(6, 32'h00000001, "SLT neg<pos");
            check_reg(7, 32'h00000000, "SLTU wrap");
            check_reg(8, 32'h00000001, "SLTI");
            check_reg(9, 32'h00000000, "SLTIU wrap");
        end
    endtask

    // Test 5: Branches
    task test_branches;
        begin
            $display("\n--- Test 5: Branches ---");
            rst = 1;
            clear_mem;
            `IMEM[0]  = 32'h00100093; // ADDI x1, x0, 1
            `IMEM[1]  = 32'h00100113; // ADDI x2, x0, 1
            `IMEM[2]  = 32'h00200193; // ADDI x3, x0, 2
            `IMEM[3]  = 32'h00208463; // BEQ  x1, x2, +8
            `IMEM[4]  = 32'h06300213; // ADDI x4, x0, 99 (skipped)
            `IMEM[5]  = 32'h02a00213; // ADDI x4, x0, 42
            `IMEM[6]  = 32'h00309463; // BNE  x1, x3, +8
            `IMEM[7]  = 32'h06300293; // ADDI x5, x0, 99 (skipped)
            `IMEM[8]  = 32'h00700293; // ADDI x5, x0, 7
            `IMEM[9]  = 32'hfff00313; // ADDI x6, x0, -1
            `IMEM[10] = 32'h00134463; // BLT  x6, x1, +8
            `IMEM[11] = 32'h06300393; // ADDI x7, x0, 99 (skipped)
            `IMEM[12] = 32'h03700393; // ADDI x7, x0, 55
            `IMEM[13] = 32'h00136463; // BLTU x6, x1, +8 (not taken)
            `IMEM[14] = 32'h00b00413; // ADDI x8, x0, 11
            release_reset;
            run_cycles(13);
            check_reg(4, 32'h0000002A, "BEQ taken");
            check_reg(5, 32'h00000007, "BNE taken");
            check_reg(7, 32'h00000037, "BLT signed");
            check_reg(8, 32'h0000000B, "BLTU not taken");
        end
    endtask

    // Test 6: JAL & JALR
    task test_jumps;
        begin
            $display("\n--- Test 6: JAL & JALR ---");
            rst = 1;
            clear_mem;
            `IMEM[0] = 32'h00c000ef; // JAL  x1, +12      PC=0x00 → 0x0C, x1=0x04
            `IMEM[1] = 32'h06300113; // ADDI x2, x0, 99   PC=0x04 (skipped by JAL)
            `IMEM[2] = 32'h06300113; // ADDI x2, x0, 99   PC=0x08 (skipped by JAL)
            `IMEM[3] = 32'h02a00113; // ADDI x2, x0, 42   PC=0x0C
            `IMEM[4] = 32'h000081e7; // JALR x3, x1, 0    PC=0x10 → x1+0=0x04, x3=0x14
            `IMEM[5] = 32'h00000013; // NOP               PC=0x14 (JALR link, never reached)
            release_reset;
            run_cycles(3);
            check_reg(1, 32'h00000004, "JAL link");
            check_reg(2, 32'h0000002A, "JAL skip");
            check_reg(3, 32'h00000014, "JALR link");
        end
    endtask

    // Test 7: LUI & AUIPC
    task test_upper_imm;
        begin
            $display("\n--- Test 7: LUI & AUIPC ---");
            rst = 1;
            clear_mem;
            `IMEM[0] = 32'habcde0b7; // LUI   x1, 0xABCDE
            `IMEM[1] = 32'h00001117; // AUIPC x2, 0x00001
            release_reset;
            run_cycles(3);
            check_reg(1, 32'hABCDE000, "LUI");
            check_reg(2, 32'h00001004, "AUIPC");
        end
    endtask

    // Test 8: x0 hardwired zero
    task test_x0;
        begin
            $display("\n--- Test 8: x0 hardwired zero ---");
            rst = 1;
            clear_mem;
            `IMEM[0] = 32'h06300013; // ADDI x0, x0, 99
            `IMEM[1] = 32'h00100093; // ADDI x1, x0, 1
            release_reset;
            run_cycles(3);
            check_reg(0, 32'h00000000, "x0 write ignored");
            check_reg(1, 32'h00000001, "x0 reads zero");
        end
    endtask

    // Test 9: BGE & BGEU
    task test_bge;
        begin
            $display("\n--- Test 9: BGE & BGEU ---");
            rst = 1;
            clear_mem;
            `IMEM[0] = 32'h00500093; // ADDI x1, x0, 5
            `IMEM[1] = 32'h00500113; // ADDI x2, x0, 5
            `IMEM[2] = 32'h00205463; // BGE  x1, x2, +8
            `IMEM[3] = 32'h06300193; // ADDI x3, x0, 99 (skipped)
            `IMEM[4] = 32'h00100193; // ADDI x3, x0, 1
            `IMEM[5] = 32'hfff00213; // ADDI x4, x0, -1
            `IMEM[6] = 32'h00526463; // BGEU x4, x1, +8
            `IMEM[7] = 32'h06300293; // ADDI x5, x0, 99 (skipped)
            `IMEM[8] = 32'h00200293; // ADDI x5, x0, 2
            release_reset;
            run_cycles(9);
            check_reg(3, 32'h00000001, "BGE equal taken");
            check_reg(5, 32'h00000002, "BGEU unsigned taken");
        end
    endtask

    // ── Main ──────────────────────────────────────────────────────
    initial begin
        $dumpfile("core_tb.vcd");
        $dumpvars(0, core_tb);
        clk = 0;
        rst = 1;

        test_arith;
        test_shifts;
        test_loads_stores;
        test_comparisons;
        test_branches;
        test_jumps;
        test_upper_imm;
        test_x0;
        test_bge;

        $display("\n========================================");
        if (failed == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", failed);
        $display("========================================\n");
        $finish;
    end

endmodule