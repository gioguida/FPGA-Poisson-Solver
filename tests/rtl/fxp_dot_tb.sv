`timescale 1ns/1ps

module fxp_dot_tb;
    localparam int V = 256;
    localparam int N = 32;
    localparam int WIDE = 2*N + $clog2(V);
    localparam VECTOR_FILE = "../build/test_vectors/fxp_dot_Q8_24.hex";

    logic clk_ci = 1'b0;
    logic rst_ni = 1'b0;
    logic valid_i = 1'b0;
    logic signed [V*N-1:0] x_i = '0;
    logic signed [V*N-1:0] y_i = '0;
    logic valid_o;
    logic signed [WIDE-1:0] a_o;
    logic overflow_o;

    logic signed [WIDE-1:0] expected_i;
    integer vector_valid_i;
    integer expected_overflow_i;
    integer vector_fd;
    integer scan_status;
    integer checks;
    integer cycle;

    always #5 clk_ci = ~clk_ci;

    fxp_dot #(.V(V), .N(N), .F(24)) dut (.*);

    initial begin
        repeat (2) @(posedge clk_ci);
        @(negedge clk_ci);
        rst_ni = 1'b1;

        vector_fd = $fopen(VECTOR_FILE, "r");
        if (vector_fd == 0)
            $fatal(1, "Cannot open dot-product vectors: %s", VECTOR_FILE);

        checks = 0;
        while (!$feof(vector_fd)) begin
            scan_status = $fscanf(vector_fd, "%d %h %h %h %d\n",
                                  vector_valid_i, x_i, y_i, expected_i,
                                  expected_overflow_i);
            if (scan_status == 5) begin
                if (vector_valid_i != 1)
                    $fatal(1, "unsupported valid_i value in vector %0d", checks);

                @(negedge clk_ci);
                valid_i = 1'b1;
                @(posedge clk_ci);
                #1;
                if (valid_o)
                    $fatal(1, "unexpected valid_o on vector acceptance");

                @(negedge clk_ci);
                valid_i = 1'b0;

                // fxp_dot has a deterministic V+2 cycle transaction latency.
                for (cycle = 1; cycle <= V+2; cycle = cycle + 1) begin
                    @(posedge clk_ci);
                    #1;
                    if (cycle < V+2 && valid_o)
                        $fatal(1, "vector %0d returned early at cycle %0d",
                               checks, cycle);
                    if (cycle == V+2) begin
                        if (!valid_o || a_o !== expected_i ||
                            overflow_o !== expected_overflow_i[0])
                            $fatal(1,
                                "vector %0d: valid=%b sum=%h overflow=%b, expected sum=%h overflow=%b",
                                checks, valid_o, a_o, overflow_o, expected_i,
                                expected_overflow_i[0]);
                    end
                end
                checks = checks + 1;
            end else if (scan_status != -1) begin
                $fatal(1, "malformed dot-product vector row %0d (fields=%0d)",
                       checks, scan_status);
            end
        end

        $fclose(vector_fd);
        if (checks == 0)
            $fatal(1, "no dot-product vectors were read");

        $display("fxp_dot_tb PASS: %0d vector checks", checks);
        $finish;
    end
endmodule
