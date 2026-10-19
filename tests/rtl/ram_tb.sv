`timescale 1ns/1ps

module ram_tb;
    localparam int WIDTH = 8;
    localparam int DEPTH = 4;
    localparam int LANES = 4;
    localparam int WORDWIDTH = WIDTH * LANES;
    localparam int ADDRW = $clog2(DEPTH);

    logic clk_ci = 1'b0;
    logic we_i = 1'b0;
    logic [ADDRW-1:0] w_addr_i = '0;
    logic [WORDWIDTH-1:0] w_data_i = '0;
    logic [ADDRW-1:0] r_addr_i = '0;
    logic [WORDWIDTH-1:0] r_data_o;

    ram #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH),
        .LANES(LANES)
    ) dut (
        .clk_ci,
        .we_i,
        .w_addr_i,
        .w_data_i,
        .r_addr_i,
        .r_data_o
    );

    always #5 clk_ci = ~clk_ci;

    task automatic write_word(
        input logic [ADDRW-1:0] address,
        input logic [WORDWIDTH-1:0] data
    );
        begin
            @(negedge clk_ci);
            we_i = 1'b1;
            w_addr_i = address;
            w_data_i = data;
            @(posedge clk_ci);
            #1;
            we_i = 1'b0;
        end
    endtask

    task automatic read_word(
        input logic [ADDRW-1:0] address,
        input logic [WORDWIDTH-1:0] expected
    );
        begin
            @(negedge clk_ci);
            r_addr_i = address;
            @(posedge clk_ci);
            #1;
            if (r_data_o !== expected)
                $fatal(1, "address %0d: expected %h, got %h",
                       address, expected, r_data_o);
        end
    endtask

    initial begin
        write_word(2'd0, 32'h11_22_33_44);
        write_word(2'd1, 32'ha5_5a_c3_3c);

        read_word(2'd0, 32'h11_22_33_44);
        read_word(2'd1, 32'ha5_5a_c3_3c);

        // A disabled write must not modify the selected word.
        @(negedge clk_ci);
        we_i = 1'b0;
        w_addr_i = 2'd0;
        w_data_i = 32'hde_ad_be_ef;
        @(posedge clk_ci);
        #1;
        read_word(2'd0, 32'h11_22_33_44);

        $display("ram_tb PASS");
        $finish;
    end
endmodule
