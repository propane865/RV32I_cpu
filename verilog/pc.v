// Program Counter

/*
Clock:                      | clk
-----------------------------------------
Reset:                      | rst
-----------------------------------------
Program Counter Source:     | pc_src
-----------------------------------------
Program Counter Target:     | pc_target
-----------------------------------------
Program Counter Output:     | pc_out
-----------------------------------------
Program Counter Plus 4:     | pc_plus4
*/

module pc(input clk, rst, pc_src, input [31:0] pc_target, output [31:0] pc_out, pc_plus4);
    // Store the value of the program Counter
    reg [31:0] pc_reg;

    // Output bothh the program counter's value, and it's value plus 4
    assign pc_out = pc_reg;
    assign pc_plus4 = pc_reg + 32'h4;

    // Update program counter at every clock cycle
    always @(posedge clk) begin
        // If reset signal is enabled, then set to zero
        if (rst) begin
            pc_reg <= 32'b0;
        end
        // Else, set program counter to target value, or its current value plus 4 (depending on pc_src)
        else begin
            pc_reg <= pc_src ? pc_target : pc_reg + 32'h4;
        end
    end
endmodule