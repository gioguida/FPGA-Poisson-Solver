module fxp_dot_tb;
    localparam int V = 256;
    localparam int N = 32;
    localparam int WIDE = 2*N + $clog2(V);

    logic clk_ci = 1'b0;
    logic rst_ni = 1'b0;
    logic valid_i = 1'b0;
    logic signed [V*N-1:0] x_i = '0;
    logic signed [V*N-1:0] y_i = '0;
    logic valid_o;
    logic signed [WIDE-1:0] a_o;
    logic overflow_o;

    always #5 clk_ci = ~clk_ci;

    fxp_dot dut (.*);

    task automatic run_case(input int mode);
        logic signed [127:0] expected;
        logic signed [127:0] lhs, rhs;
        int cycle;
        begin
            @(negedge clk_ci);
            for (int i = 0; i < V; i++) begin
                case (mode)
                    0: begin
                        x_i[i*N +: N] = '0;
                        y_i[i*N +: N] = '0;
                    end
                    1: begin
                        x_i[i*N +: N] = (i % 7 - 3) * 32'sh0100_0000;
                        y_i[i*N +: N] = (i % 5 - 2) * 32'sh0080_0000;
                    end
                    2: begin
                        x_i[i*N +: N] = (i % 2) ? 32'sh8000_0000 : 32'sh7fff_ffff;
                        y_i[i*N +: N] = (i % 3) ? 32'sh7fff_ffff : 32'sh8000_0000;
                    end
                    default: begin
                        x_i[i*N +: N] = $urandom;
                        y_i[i*N +: N] = $urandom;
                    end
                endcase
            end

            expected = '0;
            for (int i = 0; i < V; i++) begin
                lhs = $signed(x_i[i*N +: N]);
                rhs = $signed(y_i[i*N +: N]);
                expected = expected + lhs * rhs;
            end

            valid_i = 1'b1;
            @(posedge clk_ci);
            #1;
            if (valid_o) $fatal(1, "unexpected valid on acceptance");
            @(negedge clk_ci);
            valid_i = 1'b0;

            for (cycle = 1; cycle <= V+2; cycle++) begin
                @(posedge clk_ci);
                #1;
                if (cycle == V+2) begin
                    if (!valid_o || a_o !== expected[WIDE-1:0] || overflow_o)
                        $fatal(1, "case %0d: got valid=%b sum=%h overflow=%b, expected %h",
                               mode, valid_o, a_o, overflow_o, expected[WIDE-1:0]);
                end else if (valid_o) begin
                    $fatal(1, "case %0d: result arrived at cycle %0d", mode, cycle);
                end
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clk_ci);
        @(negedge clk_ci);
        rst_ni = 1'b1;

        run_case(0);
        run_case(1);
        run_case(2);
        for (int i = 0; i < 8; i++) run_case(3);

        $display("fxp_dot_tb PASS");
        $finish;
    end
endmodule
