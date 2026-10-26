`timescale 1ns/1ps

module poisson_stencil_engine_tb;
    localparam int N = 16;
    localparam int F = 8;
    localparam int ROWS = 8;
    localparam int COLS = 5;
    localparam int LANES = 4;
    localparam int DEPTH = ROWS*COLS/LANES;
    localparam int ADDRW = $clog2(DEPTH);
    localparam int XBITS = $clog2(ROWS);
    localparam int YBITS = $clog2(COLS);

    logic clk_ci = 1'b0;
    logic rst_ni = 1'b0;
    logic valid_i = 1'b0;
    logic [XBITS-1:0] I_i = '0;
    logic [YBITS-1:0] J_i = '0;
    logic ready_o, rd_en_o, rd_valid, valid_o, overflow_o;
    logic [ADDRW-1:0] rd_addr_o;
    logic [LANES*N-1:0] rd_data;
    logic signed [N-1:0] Ax_o;
    logic [XBITS-1:0] I_o;
    logic [YBITS-1:0] J_o;
    logic w_en_i = 1'b0;
    logic [ADDRW-1:0] w_addr_i = '0;
    logic [LANES*N-1:0] w_data_i = '0;
    int pattern = 0;

    always #5 clk_ci = ~clk_ci;

    ram #(.WIDTH(N), .DEPTH(DEPTH), .LANES(LANES)) memory (
        .clk_ci, .rst_ni,
        .r_en_i(rd_en_o), .r_addr_i(rd_addr_o),
        .r_valid_o(rd_valid), .r_data_o(rd_data),
        .w_en_i, .w_addr_i, .w_data_i
    );

    poisson_stencil_engine #(
        .N(N), .F(F), .ROWS(ROWS), .COLS(COLS), .LANES(LANES)
    ) dut (
        .clk_ci, .rst_ni, .valid_i, .I_i, .J_i,
        .rd_valid_i(rd_valid), .rd_data_i(rd_data),
        .ready_o, .rd_en_o, .rd_addr_o,
        .valid_o, .Ax_o, .I_o, .J_o, .overflow_o
    );

    function automatic int value_at(input int x, input int y);
        if (x < 0 || x >= ROWS || y < 0 || y >= COLS)
            return 0;
        if (pattern == 0)
            return x + ROWS*y + 1;
        if (pattern == 2)
            return (x == 3 && y == 2) ? 20000 : 0;
        return ((37*x + 53*y + 19*x*y + 11) % 101) - 50;
    endfunction

    task automatic check_point(input int x, input int y);
        int cycles;
        int expected;
        begin
            @(negedge clk_ci);
            if (!ready_o) $fatal(1, "engine not ready before (%0d,%0d)", x, y);
            I_i = XBITS'(x);
            J_i = YBITS'(y);
            valid_i = 1'b1;
            @(posedge clk_ci);
            #1;
            if (ready_o) $fatal(1, "engine stayed ready after accepting request");
            @(negedge clk_ci);
            // Offer another request while busy; it must not be accepted.
            I_i = XBITS'((x+1) % ROWS);
            J_i = YBITS'((y+1) % COLS);

            cycles = 0;
            while (!valid_o && cycles < 50) begin
                @(posedge clk_ci);
                #1;
                cycles++;
                if (ready_o && !valid_o)
                    $fatal(1, "engine accepted another request before result");
            end
            if (!valid_o) $fatal(1, "timeout at (%0d,%0d)", x, y);

            expected = 4*value_at(x,y) - value_at(x-1,y)
                     - value_at(x+1,y) - value_at(x,y-1) - value_at(x,y+1);
            if (Ax_o !== N'(expected) || I_o !== XBITS'(x)
                || J_o !== YBITS'(y)
                || overflow_o !== (pattern == 2 && x == 3 && y == 2))
                $fatal(1, "wrong result at (%0d,%0d): Ax=%0d expected=%0d tag=(%0d,%0d) overflow=%b",
                       x, y, Ax_o, expected, I_o, J_o, overflow_o);

            @(posedge clk_ci);
            #1;
            if (valid_o || !ready_o)
                $fatal(1, "result valid did not pulse or engine did not recover");
            @(negedge clk_ci);
            valid_i = 1'b0;
        end
    endtask

    initial begin
        repeat (2) @(negedge clk_ci);
        rst_ni = 1'b1;
        for (int p = 0; p < 3; p++) begin
            pattern = p;
            for (int word = 0; word < DEPTH; word++) begin
                @(negedge clk_ci);
                w_en_i = 1'b1;
                w_addr_i = ADDRW'(word);
                for (int lane = 0; lane < LANES; lane++) begin
                    int index;
                    index = word*LANES + lane;
                    w_data_i[lane*N +: N] = N'(value_at(index % ROWS, index / ROWS));
                end
            end
            @(negedge clk_ci);
            w_en_i = 1'b0;

            for (int y = 0; y < COLS; y++)
                for (int x = 0; x < ROWS; x++)
                    check_point(x, y);
        end

        $display("poisson_stencil_engine_tb PASS");
        $finish;
    end
endmodule
