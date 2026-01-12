`timescale 1ns/1ns

module core_tb;
    reg [31:0] a, b;
    reg cin, invert, pass;
    reg [2:0] op;

    alu t (
        .a(a),
        .b(b),
        .cin(cin),
        .invert(invert),
        .pass(pass),
        .op(op)
    );

    initial begin
        a = 32'hFFFFFFFF;
        b = 32'h2;
        cin = 1'b1;
        invert = 1'b0;
        pass = 1'b0;
        op = 3'b011; #10;

        a = 32'h2;
        b = 32'h1;
        cin = 1'b0;
        invert = 1'b1;
        pass = 1'b0;
        op = 3'b011; #10;

        a = 32'hFFFFFFFF;
        b = 32'h2;
        cin = 1'b0;
        invert = 1'b1;
        pass = 1'b1; #10;

        a = 32'hFFFFFFFF;
        b = 32'h2;
        cin = 1'b0;
        invert = 1'b0;
        pass = 1'b0;
        op = 3'b100; #10;

        a = 32'hFFFFFFFF;
        b = 32'h2;
        cin = 1'b0;
        invert = 1'b1;
        pass = 1'b0;
        op = 3'b100; #10;

        a = 32'hFFFFFFFF;
        b = 32'h2;
        cin = 1'b0;
        invert = 1'b1;
        pass = 1'b0;
        op = 3'b101; #10;

        a = 32'hFFFFFFF0;
        b = 32'hF0;
        cin = 1'b0;
        invert = 1'b0;
        pass = 1'b0;
        op = 3'b000; #10;

        a = 32'hFFFFFFF0;
        b = 32'h2;
        cin = 1'b0;
        invert = 1'b0;
        pass = 1'b0;
        op = 3'b001; #10;

        a = 32'hFFFFF000;
        b = 32'h000FFFFF;
        cin = 1'b0;
        invert = 1'b0;
        pass = 1'b0;
        op = 3'b010; #10;
        $finish;
    end

    initial begin
        $dumpfile("test_waves.vcd");
        $dumpvars(0, core_tb);
    end

endmodule
