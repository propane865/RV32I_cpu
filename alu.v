// Full Adder (a + b + cin)
module f_add(input a, input b, input cin, output sum, output cout);
    assign sum = a ^ b ^ cin;
    assign cout = (a & b) | (b & cin) | (a & cin) | (a & b & cin);
endmodule

// 32-bit RCA with overflow detection (a + b + cin)
module rca32(input [31:0] a, input [31:0] b, input cin, output [31:0] sum, output cout, output overflow);
    wire [32:0] carrys;
    assign carrys[0] = cin;

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : add32
            f_add add(a[i], b[i], carrys[i], sum[i], carrys[i + 1]);
        end
    endgenerate

    assign cout = carrys[32];
    assign overflow = carrys[32] ^ carrys[31];
endmodule

// Half Adder (a + b)
module h_add(input a, input b, output sum, output cout);
    assign sum = a ^ b;
    assign cout = a & b;
endmodule

// Incrementer (increments a by 1'b1)
module incrementer(input [31:0] a, input b, output [31:0] sum, output cout);
    wire [32:0] carrys;
    assign carrys[0] = b;

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : incrementer
            h_add h(a[i], carrys[i], sum[i], carrys[i + 1]);
        end
    endgenerate

    assign cout = carrys[32];
endmodule

// Complementer (computes two's complement of a)
module complementer(input [31:0] a, input enable, output [31:0] cmp);
    reg [31:0] invert;
    wire cout;

    always @(*) begin
        case (enable)
            1'b0: invert = a;
            1'b1: invert = ~a;
        endcase
    end

    incrementer inc(invert, enable, cmp, cout);
endmodule

// 32-bit shifter (shift a leftwards by b bits without rotation, enable dir to shift rightwards)
module shifter(input [31:0] a, input [31:0] b, input arith, input dir, output reg [31:0] shift);
    always @(*) begin
        shift = a[31:0];
        if (~dir) begin
            if (b[0]) begin
                shift = {shift[30:0], 1'b0};
            end
            if (b[1]) begin
                shift = {shift[29:0], 2'b0};
            end
            if (b[2]) begin
                shift = {shift[27:0], 4'b0};
            end
            if (b[3]) begin
                shift = {shift[23:0], 8'b0};
            end
            if (b[4]) begin
                shift = {shift[15:0], 16'b0};
            end
        end
        else if (~arith) begin
            if (b[0]) begin
                shift = {1'b0, shift[31:1]};
            end
            if (b[1]) begin
                shift = {2'b0, shift[31:2]};
            end
            if (b[2]) begin
                shift = {4'b0, shift[31:4]};
            end
            if (b[3]) begin
                shift = {8'b0, shift[31:8]};
            end
            if (b[4]) begin
                shift = {16'b0, shift[31:16]};
            end
        end
        else begin
            if (b[0]) begin
                shift = {{1{a[31]}}, shift[31:1]};
            end
            if (b[1]) begin
                shift = {{2{a[31]}}, shift[31:2]};
            end
            if (b[2]) begin
                shift = {{4{a[31]}}, shift[31:4]};
            end
            if (b[3]) begin
                shift = {{8{a[31]}}, shift[31:8]};
            end
            if (b[4]) begin
                shift = {{16{a[31]}}, shift[31:16]};
            end
        end
    end
endmodule

module comparator(input a, b, gin, lin, ein, output g, l, e);
    assign g = (a & ~b) | ((a ~^ b) & gin);
    assign l = (~a & b) | ((a ~^ b) & lin);
    assign e = (a ~^ b) & ein;
endmodule

// Compare 32-bit values a and b
module comp32(input [31:0] a, b, output gr, le, eq);
    wire [32:0] g, l, e;
    
    assign g[0] = 1'b0;
    assign l[0] = 1'b0;
    assign e[0] = 1'b1;

    genvar i;
    generate
        for (i = 32; i > 0; i = i - 1) begin : comp32
            comparator comp(a[i - 1], b[i - 1], g[i], l[i], e[i], g[i - 1], l[i - 1], e[i - 1]);
        end
    endgenerate

    assign gr = g[32];
    assign le = l[32];
    assign eq = e[32];
endmodule

module alu(input [31:0] a, b, input cin, input pass, input invert, input [2:0] op, output reg [31:0] out, output cout, output overflow);
    wire [31:0] a_cmp, a_shift, a_b_add, a_xor_b, a_or_b, a_and_b;
    wire arith_shift;
    wire gr, le, eq;

    reg [31:0] logic_out;

    complementer cmp(a, invert, a_cmp);

    shifter sh(a, b[4:0], op[0], invert, a_shift);
    rca32 add(a_cmp, b, cin, a_b_add, cout, overflow);
    comp32 comp(a, b, gr, le, eq);

    assign a_xor_b = a ^ b;
    assign a_or_b = a | b;
    assign a_and_b = a & b;

    always @(*) begin
        case (op)
            3'b000: logic_out <= a_and_b; // AND
            3'b001: logic_out <= a_or_b; // OR
            3'b010: logic_out <= a_xor_b; // XOR
            3'b011: logic_out <= a_b_add; // ADD/SUB
            3'b100: logic_out <= a_shift; // LOGICAL SHIFT
            3'b101: logic_out <= a_shift; // ARITHMETIC SHIFT
            3'b110: logic_out <= {31'b0, invert ? gr : le}; // LESS/GREATER
            3'b111: logic_out <= {31'b0, eq ^ invert}; // EQUAL/UNEQUAL
            default: logic_out <= 32'h0;
        endcase

        case (pass)
            1'b0: out <= logic_out;
            1'b1: out <= a_cmp;
        endcase
    end
endmodule