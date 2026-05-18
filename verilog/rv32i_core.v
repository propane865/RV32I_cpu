// Instantiate core with datapath

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

module rv32i_core(input clk, rst, output [31:0] pc_out, dmem_addr, dmem_wdata, dmem_rdata, output [1:0] dmem_width, output dmem_w_ena);
    datapath DP(
        .clk    (clk),
        .rst    (rst),
        .pc_out (pc_out),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_w_ena(dmem_w_ena),
        .dmem_width(dmem_width)
    );
endmodule