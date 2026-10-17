`timescale 1ns/1ps

module test_fxp_axpy;
    localparam int CLK_PERIOD_NS = 10;
    localparam int V = 8;
    localparam int K = 2;
    localparam int N = 32;
    localparam int F = 24;

    // Run the simulator from the repository root so this path resolves to
    // the vector file written by gen_fxp_axpy_vectors.cpp.
    localparam string VECTOR_FILE = "../build/test_vectors/fxp_axpy_Q8_24.hex";

    logic clk_ci = 1'b0;
    logic rst_ni;
    logic valid_i;
    logic signed [V*N-1:0] x_i;
    logic signed [V*N-1:0] z_i;
    logic signed [N-1:0] gamma_i;
    logic valid_o;
    logic signed [V*N-1:0] y_o;
    logic overflow_o;

    // A vector row is: valid_i gamma_raw x_packed z_packed expected_y_packed.
    logic [31:0] gamma_raw;
    logic [V*N-1:0] x_raw;
    logic [V*N-1:0] z_raw;
    logic [V*N-1:0] expected_y;

    integer vector_fd;
    integer scan_status;
    integer checks;
    integer failures;

    fxp_axpy #(.V(V), .K(K), .N(N), .F(F)) dut (
        .clk_ci(clk_ci),
        .rst_ni(rst_ni),
        .valid_i(valid_i),
        .x_i(x_i),
        .z_i(z_i),
        .gamma_i(gamma_i),
        .valid_o(valid_o),
        .y_o(y_o),
        .overflow_o(overflow_o)
    );

    always #(CLK_PERIOD_NS / 2) clk_ci = ~clk_ci;

    task automatic wait_for_result;
        begin
            do begin
                @(posedge clk_ci);
                #1;
            end while (!valid_o);
        end
    endtask

    initial begin
        rst_ni = 1'b0;
        valid_i = 1'b0;
        x_i = '0;
        z_i = '0;
        gamma_i = '0;
        checks = 0;
        failures = 0;

        @(posedge clk_ci);
        #1 rst_ni = 1'b1;

        vector_fd = $fopen(VECTOR_FILE, "r");
        if (vector_fd == 0) begin
            $fatal(1, "Cannot open vector file: %s", VECTOR_FILE);
        end

        while (!$feof(vector_fd)) begin
            scan_status = $fscanf(vector_fd, "%d %h %h %h %h\n",
                                  valid_i, gamma_raw, x_raw, z_raw,
                                  expected_y);
            if (scan_status == 5) begin
                @(negedge clk_ci);
                gamma_i = $signed(gamma_raw);
                x_i = $signed(x_raw);
                z_i = $signed(z_raw);
                valid_i = 1'b1;

                // fxp_axpy accepts one transaction only while idle.  Drive
                // each case separately and compare at its valid_o edge.
                @(negedge clk_ci);
                valid_i = 1'b0;
                wait_for_result();

                ++checks;
                if (y_o !== expected_y) begin
                    ++failures;
                    $error("vector %0d: gamma=%08h x=%h z=%h expected=%h got=%h",
                           checks, gamma_raw, x_raw, z_raw, expected_y, y_o);
                end
            end
        end
        $fclose(vector_fd);

        if (failures != 0) begin
            $fatal(1, "fxp_axpy failed %0d of %0d checks", failures, checks);
        end

        $display("fxp_axpy passed %0d vector checks", checks);
        $finish;
    end
endmodule
