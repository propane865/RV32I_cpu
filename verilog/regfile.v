// Registers

/*
Clock:                          | clk
-------------------------------------------
Write Enable:                   | w_ena
-------------------------------------------
Source Register 1 Address:      | rs1
-------------------------------------------
Source Register 1 Address:      | rs2
-------------------------------------------
Destination Register Address:   | rd
-------------------------------------------
Write Data:                     | w_data
-------------------------------------------
Register 1 Readout:             | r_data1
-------------------------------------------
Register 2 Readout:             | r_data2
*/

module regfile(input clk, w_ena, input [4:0] rs1, rs2, rd, input [31:0] w_data, output [31:0] r_data1, r_data2);
    // 32 General-Purpose Registers, 32-bit (Register x0 is the zero register)
    reg [31:0] regs [1:31];

    // If the register being read is x0, return zero, else return value of the register
    assign r_data1 = (rs1 == 5'b0) ? 32'b0 : regs[rs1];
    assign r_data2 = (rs2 == 5'b0) ? 32'b0 : regs[rs2];

    // Write to the register address at the next clock (unless the destination register is x0)
    always @(posedge clk) begin
        if (w_ena && rd != 5'b0) begin
            regs[rd] <= w_data;
        end
    end
endmodule