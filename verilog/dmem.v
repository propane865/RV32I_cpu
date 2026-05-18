// Instruction Memory (4 kB) Behavioral Model

/*
Clock:          | clk
----------------------------
Write Enable:   | w_ena
----------------------------
Signed Read:   | is_signed
----------------------------
Data Width:     | width
----------------------------
Address:        | addr
----------------------------
Write Data:     | w_data
----------------------------
Readout Data:   | r_data
*/

module dmem(input clk, w_ena, is_signed, input [1:0] width, input [31:0] addr, w_data, output reg [31:0] r_data);
    // 4096 memory cells, 1 byte (8 bits) each
    reg [7:0] mem [0:4095];

    // On every clock cycle, write to address if write is enabled
    always @(posedge clk) begin
        if (w_ena) begin
            case (width)
                // Store a byte
                2'b00: begin
                    mem[addr[11:0]] <= w_data[7:0];
                end
                // Store a halfword
                2'b01: begin
                    mem[addr[11:0]] <= w_data[7:0];
                    mem[addr[11:0] + 1] <= w_data[15:8];
                end
                // Store a word
                2'b10: begin
                    mem[addr[11:0]] <= w_data[7:0];
                    mem[addr[11:0] + 1] <= w_data[15:8];
                    mem[addr[11:0] + 2] <= w_data[23:16];
                    mem[addr[11:0] + 3] <= w_data[31:24];
                end
            endcase
        end
    end

    // Readout the memory at the specified address
    always @(*) begin
        case (width)
            // Load a byte
            2'b00: begin
                r_data = is_signed ? {{24{mem[addr][7]}}, mem[addr]} : {24'b0, mem[addr]};
            end
            // Load a halfword
            2'b01: begin
                r_data = is_signed ? {{16{mem[addr + 1][7]}}, mem[addr + 1], mem[addr]} : {16'b0, mem[addr + 1], mem[addr]};
            end
            // Load a word
            2'b10: begin
                r_data = {mem[addr + 3], mem[addr + 2], mem[addr + 1], mem[addr]};
            end

            // Output zero if an invalid width is given
            default: r_data = 32'b0;
        endcase
    end

    // Initialize the memory to zero (for simulation purposes)
    integer i;
    initial begin
        for (i = 0; i < 4096; i = i + 1) begin
            mem[i] = 8'b0;
        end
    end
endmodule