`timescale 1ns/1ps

module stencil_neighborhood_fetch_tb #(
    parameter int LANES = 4
);
    localparam int N = 8;
    localparam int NX = 16;
    localparam int NY = 5;
    localparam int DEPTH = NX*NY/LANES;
    localparam int ADDRW = $clog2(DEPTH);
    localparam int XBITS = $clog2(NX);
    localparam int YBITS = $clog2(NY);

    logic clk_ci = 1'b0;
    logic rst_ni = 1'b0;
    logic valid_i = 1'b0;
    logic [XBITS-1:0] I_i = '0;
    logic [YBITS-1:0] J_i = '0;
    logic ready_o, rd_en_o, rd_valid, valid_o, done_o;
    logic [ADDRW-1:0] rd_addr_o;
    logic [LANES*N-1:0] rd_data;
    logic signed [N-1:0] center_o, north_o, south_o, west_o, east_o;
    logic w_en_i = 1'b0;
    logic [ADDRW-1:0] w_addr_i = '0;
    logic [LANES*N-1:0] w_data_i = '0;

    always #5 clk_ci = ~clk_ci;

    ram #(.WIDTH(N), .DEPTH(DEPTH), .LANES(LANES)) memory (
        .clk_ci, .rst_ni,
        .r_en_i(rd_en_o), .r_addr_i(rd_addr_o),
        .r_valid_o(rd_valid), .r_data_o(rd_data),
        .w_en_i, .w_addr_i, .w_data_i
    );

    stencil_neighborhood_fetch #(
        .N(N), .NX(NX), .NY(NY), .LANES(LANES)
    ) dut (
        .clk_ci, .rst_ni, .valid_i, .I_i, .J_i,
        .rd_valid_i(rd_valid), .rd_data_i(rd_data),
        .ready_o, .rd_en_o, .rd_addr_o, .valid_o,
        .center_o, .north_o, .south_o, .west_o, .east_o, .done_o
    );

    task automatic check_point(input int x, input int y);
        int cycles;
        begin
            @(negedge clk_ci);
            if (!ready_o) $fatal(1, "fetcher not ready before (%0d,%0d)", x, y);
            I_i = XBITS'(x);
            J_i = YBITS'(y);
            valid_i = 1'b1;
            @(negedge clk_ci);
            valid_i = 1'b0;

            cycles = 0;
            while (!done_o && cycles < 30) begin
                @(posedge clk_ci);
                #1;
                cycles++;
            end
            if (!done_o || !valid_o) $fatal(1, "timeout at (%0d,%0d)", x, y);
            if (center_o !== N'(x + NX*y + 1) ||
                north_o  !== N'((y == 0)      ? 0 : x + NX*(y-1) + 1) ||
                south_o  !== N'((y == NY-1) ? 0 : x + NX*(y+1) + 1) ||
                west_o   !== N'((x == 0)      ? 0 : x-1 + NX*y + 1) ||
                east_o   !== N'((x == NX-1) ? 0 : x+1 + NX*y + 1))
                $fatal(1, "wrong neighborhood at (%0d,%0d): C=%0d N=%0d S=%0d W=%0d E=%0d",
                       x, y, center_o, north_o, south_o, west_o, east_o);
        end
    endtask

    initial begin
        repeat (2) @(negedge clk_ci);
        rst_ni = 1'b1;
        for (int word = 0; word < DEPTH; word++) begin
            @(negedge clk_ci);
            w_en_i = 1'b1;
            w_addr_i = ADDRW'(word);
            for (int lane = 0; lane < LANES; lane++)
                w_data_i[lane*N +: N] = N'(word*LANES + lane + 1);
        end
        @(negedge clk_ci);
        w_en_i = 1'b0;

        for (int y = 0; y < NY; y++)
            for (int x = 0; x < NX; x++)
                check_point(x, y);

        $display("stencil_neighborhood_fetch_tb PASS: LANES=%0d", LANES);
        $finish;
    end
endmodule
