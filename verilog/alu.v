// ALU

/*
Input A:                    | a
--------------------------------------
Input B:                    | b
--------------------------------------
Carry In:                   | cin
--------------------------------------
Enable Passthrough:         | pass
--------------------------------------
Enable Invert Operation:    | invert
--------------------------------------
Enable Signed Comparison:   | sgn
--------------------------------------
Operation Type:             | op
--------------------------------------
Output:                     | out
--------------------------------------
Carry Out:                  | cout
*/

module alu(input [31:0] a, b, input cin, input pass, input invert, input sgn, input [2:0] op, output reg [31:0] out, output cout);
    wire [31:0] a_cmp, b_cmp, a_shift, a_b_add, a_xor_b, a_or_b, a_and_b;
    wire gr, le, eq;

    reg [31:0] logic_out;

    // Invert inputs if the invert input is enabled
    assign a_cmp = invert ? ~a : a;
    assign b_cmp = invert ? ~b : b;

    // Instantiate shifter, RCA, and comparator
    shifter sh(a, b[4:0], op[0], invert, a_shift);
    cla32 add(a, b_cmp, cin, a_b_add, cout);
    comp32 comp(a, b, ~sgn, gr, le, eq);

    // Compute logical operations
    assign a_xor_b = a ^ b;
    assign a_or_b = a | b;
    assign a_and_b = a & b;

    always @(*) begin
        // Choose the output depending on the selected ALU operation
        case (op)
            3'b000: logic_out = a_and_b;                        // AND
            3'b001: logic_out = a_or_b;                         // OR
            3'b010: logic_out = a_xor_b;                        // XOR
            3'b011: logic_out = a_b_add;                        // ADD/SUB
            3'b100: logic_out = a_shift;                        // LOGICAL SHIFT
            3'b101: logic_out = a_shift;                        // ARITHMETIC SHIFT
            3'b110: logic_out = {31'b0, invert ? gr : le};      // LESS/GREATER
            3'b111: logic_out = {31'b0, eq ^ invert};           // EQUAL/UNEQUAL
            default: logic_out = 32'h0;
        endcase

        // Passthrough input A (potentially inverted) if the pass input is enabled
        case (pass)
            1'b0: out = logic_out;
            1'b1: out = a_cmp;
        endcase
    end
endmodule

// Full Adder with Propagate and Generate (a + b + cin = sum, p, g)
module f_add(input a, b, cin, output sum, p, g);
    // Propagate carry if (a) and (b) differ
    assign p = a ^ b;

    // Generate carry if both (a) and (b) are active 
    assign g = a & b;

    // Generate sum if propagate bit and carry-in differ
    assign sum = p ^ cin;
endmodule

// 4-bit Carry Lookahead Adder Unit
module cla4(input [3:0] a, b, input cin, output [3:0] sum, output gp, gg);
    wire [4:0] c;
    wire [3:0] p, g;

    // Initialize the LSB of carry to the carry-in signal
    assign c[0] = cin;

    // Generate 4 full adders for each input bit, each with its own carry-in, sum, generate, and propagate signals
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : cl32
            f_add fadd(a[i], b[i], c[i], sum[i], p[i], g[i]);
        end
    endgenerate

    // Generate respective carrys based on below carry-lookahead logic
    assign c[1] = g[0] | (p[0] & c[0]);
    assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c[0]);
    assign c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & c[0]);
    assign c[4] = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]) | (p[3] & p[2] & p[1] & p[0] & c[0]);

    // Calculate propagate and generate signals for this lookahead unit, so that it can be chained with other lookahead units
    assign gp = p[3] & p[2] & p[1] & p[0];
    assign gg = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]);
endmodule

// 32-bit CLA (a + b + cin = sum, cout)
module cla32(input [31:0] a, b, input cin, output [31:0] sum, output cout);
    // Chain 8 lookahead units (4 bits each) for a 32-bit adder
    wire [8:0] gc;
    wire [7:0] gp, gg;

    // Generate 8 lookahead units, each with its own group carry-in, sum, group carry-out, group propagate, and group generate signals
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : cla4s
            cla4 g(a[4*i + 3 : 4 * i], b[4*i + 3 : 4*i], gc[i], sum[4*i + 3 : 4 * i], gp[i], gg[i]);
        end
    endgenerate

    // Initialize the LSB of the group carry to the carry-in signal
    assign gc[0] = cin;

    // Construct Level 2 CLA structure using the group propagate and generate signals for each 4-bit CLA unit
    assign gc[1] = gg[0] | (gp[0] & gc[0]);
    assign gc[2] = gg[1] | (gp[1] & gg[0]) | (gp[1] & gp[0] & gc[0]);
    assign gc[3] = gg[2] | (gp[2] & gg[1]) | (gp[2] & gp[1] & gg[0]) | (gp[2] & gp[1] & gp[0] & gc[0]);
    assign gc[4] = gg[3] | (gp[3] & gg[2]) | (gp[3] & gp[2] & gg[1]) | (gp[3] & gp[2] & gp[1] & gg[0]) | (gp[3] & gp[2] & gp[1] & gp[0] & gc[0]);
    assign gc[5] = gg[4] | (gp[4] & gg[3]) | (gp[4] & gp[3] & gg[2]) | (gp[4] & gp[3] & gp[2] & gg[1]) | (gp[4] & gp[3] & gp[2] & gp[1] & gg[0]) | (gp[4] & gp[3] & gp[2] & gp[1] & gp[0] & gc[0]);
    assign gc[6] = gg[5] | (gp[5] & gg[4]) | (gp[5] & gp[4] & gg[3]) | (gp[5] & gp[4] & gp[3] & gg[2]) | (gp[5] & gp[4] & gp[3] & gp[2] & gg[1]) | (gp[5] & gp[4] & gp[3] & gp[2] & gp[1] & gg[0]) | (gp[5] & gp[4] & gp[3] & gp[2] & gp[1] & gp[0] & gc[0]);
    assign gc[7] = gg[6] | (gp[6] & gg[5]) | (gp[6] & gp[5] & gg[4]) | (gp[6] & gp[5] & gp[4] & gg[3]) | (gp[6] & gp[5] & gp[4] & gp[3] & gg[2]) | (gp[6] & gp[5] & gp[4] & gp[3] & gp[2] & gg[1]) | (gp[6] & gp[5] & gp[4] & gp[3] & gp[2] & gp[1] & gg[0]) | (gp[6] & gp[5] & gp[4] & gp[3] & gp[2] & gp[1] & gp[0] & gc[0]);
    assign gc[8] = gg[7] | (gp[7] & gg[6]) | (gp[7] & gp[6] & gg[5]) | (gp[7] & gp[6] & gp[5] & gg[4]) | (gp[7] & gp[6] & gp[5] & gp[4] & gg[3]) | (gp[7] & gp[6] & gp[5] & gp[4] & gp[3] & gg[2]) | (gp[7] & gp[6] & gp[5] & gp[4] & gp[3] & gp[2] & gg[1]) | (gp[7] & gp[6] & gp[5] & gp[4] & gp[3] & gp[2] & gp[1] & gg[0]) | (gp[7] & gp[6] & gp[5] & gp[4] & gp[3] & gp[2] & gp[1] & gp[0] & gc[0]);

    // Carry-out is assigned to MSB of group carrys
    assign cout = gc[8];
endmodule

// 32-bit shifter (shift a leftwards by b bits without rotation, enable dir to shift rightwards)
module shifter(input [31:0] a, input [4:0] b, input arith, input dir, output reg [31:0] shift);
    // Store intermediate shifts
    reg [31:0] shift1, shift2, shift3, shift4;

    always @(*) begin
        // Initialize the output to be the same as the input
        shift = a[31:0];

        // Start shifting from the LSB of (b), and store each intermediate shift
        // For each additional bit of (b), shift the corresponding intermediate by the significance of the bit

        // Left Shift
        if (~dir) begin
            shift1 = b[0] ? {shift[30:0], 1'b0} : shift;
            shift2 = b[1] ? {shift1[29:0], 2'b0} : shift1;
            shift3 = b[2] ? {shift2[27:0], 4'b0} : shift2;
            shift4 = b[3] ? {shift3[23:0], 8'b0} : shift3;
            shift = b[4] ? {shift4[15:0], 16'b0} : shift4;
        end

        // Right Logical Shift
        else if (~arith) begin
            shift1 =  b[0] ? {1'b0, shift[31:1]} : shift;
            shift2 =  b[1] ? {2'b0, shift1[31:2]} : shift1;
            shift3 =  b[2] ? {4'b0, shift2[31:4]} : shift2;
            shift4 =  b[3] ? {8'b0, shift3[31:8]} : shift3;
            shift =  b[4] ? {16'b0, shift4[31:16]} : shift4;
        end

        // Right Arithmetic Shift
        else begin
            shift1 = b[0] ? {{1{a[31]}}, shift[31:1]} : shift;
            shift2 = b[1] ? {{2{a[31]}}, shift1[31:2]} : shift1;
            shift3 = b[2] ? {{4{a[31]}}, shift2[31:4]} : shift2;
            shift4 = b[3] ? {{8{a[31]}}, shift3[31:8]} : shift3;
            shift = b[4] ? {{16{a[31]}}, shift4[31:16]} : shift4;
        end
    end
endmodule

// Compare two 1-bit values a and b
module bit_cmp(input a, b, output g, l, e);
    // For the comparator to output (a > b), (a) must be active, and (b) must not be active
    assign g = (a & ~b);

    // Similar logic as above applies to the output for (a < b)
    assign l = (~a & b);

    // Only output (a == b) if they have equal value
    assign e = (a ~^ b);
endmodule

// Merge two comparison results, higher bit takes priority over lower bit comparison
module cmp_merge(input g_hi, l_hi, e_hi, g_lo, l_lo, e_lo, output g, l, e);
    // Output greater-than if the higher order comparator outputs (a > b)
    // Also output greater-than if the higher order comparator outputs (a == b), but the lower order comparator outputs (a > b)
    assign g = g_hi | (e_hi & g_lo);

    // Similar logic as above applies to the less-than output
    assign l = l_hi | (e_hi & l_lo);

    // Only enable equal output if both higher order and lower order comparator output (a == b)
    assign e = e_hi & e_lo;
endmodule

// Compare 32-bit unsigned values a and b
module comp32_u(input [31:0] a, b, output gr, le, eq);
    // Level 0: Per bit results
    wire [31:0] g0, l0, e0;

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : L0
            bit_cmp bc(a[i], b[i], g0[i], l0[i], e0[i]);
        end
    endgenerate

    // Level 1: Merge two bitwise comparisons as pairwise comparisons
    wire [15:0] g1, l1, e1;

    generate
        for (i = 0; i < 16; i = i + 1) begin : L1
            cmp_merge m(g0[2*i + 1], l0[2*i + 1], e0[2*i + 1], g0[2*i], l0[2*i], e0[2*i], g1[i], l1[i], e1[i]);
        end
    endgenerate

    // Level 2: Merge comparisons from previous Level
    wire [7:0] g2, l2, e2;

    generate
        for (i = 0; i < 8; i = i + 1) begin : L2
            cmp_merge m(g1[2*i + 1], l1[2*i + 1], e1[2*i + 1], g1[2*i], l1[2*i], e1[2*i], g2[i], l2[i], e2[i]);
        end
    endgenerate

    // Level 3: Merge comparisons from previous Level
    wire [3:0] g3, l3, e3;

    generate
        for (i = 0; i < 4; i = i + 1) begin : L3
            cmp_merge m(g2[2*i + 1], l2[2*i + 1], e2[2*i + 1], g2[2*i], l2[2*i], e2[2*i], g3[i], l3[i], e3[i]);
        end
    endgenerate

    // Level 4: Merge comparisons from previous Level
    wire [1:0] g4, l4, e4;

    generate
        for (i = 0; i < 2; i = i + 1) begin : L4
            cmp_merge m(g3[2*i + 1], l3[2*i + 1], e3[2*i + 1], g3[2*i], l3[2*i], e3[2*i], g4[i], l4[i], e4[i]);
        end
    endgenerate

    // Level 5: Final merge to output result of 32-bit comparison
    cmp_merge f_merge(g4[1], l4[1], e4[1], g4[0], l4[0], e4[0], gr, le, eq);
endmodule

// Compare 32-bit signed values a and b
module comp32(input [31:0] a, b, input u, output reg gr, le, eq);
    // Initialize an unsigned comparator
    wire gr_u, le_u, eq_u;
    comp32_u comp(a, b, gr_u, le_u, eq_u);

    // Choose between output depending on whether the unsigned (u) input is enabled
    always @(*) begin
        // If the comparator is operating in signed mode, and the sign bits are different, then output the comparison between the sign bits
        if (!u && (a[31] ^ b[31])) begin
            // Output (a > b) if (b) is signed negative, and (a) is signed positive
            gr = b[31];

            // Output (a < b) if (a) is signed negative, and (b) is signed positive
            le = a[31];
            eq = 1'b0;
        end
        // If the comparator is operating in unsigned mode, or if the sign bits are equal, output the unsigned comparison between (a) and (b)
        else begin
            gr = gr_u;
            le = le_u;
            eq = eq_u;
        end
    end
endmodule