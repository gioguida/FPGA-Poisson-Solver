`timescale 1ns/1ps

module fxp_axpy_tb;
    localparam int N = 32;
    localparam int CLK_PERIOD_NS = 10;
    localparam VECTOR_FILE = "../build/test_vectors/fxp_axpy_Q8_24.hex";

    logic clk_ci = 1'b0;
    logic rst_ni = 1'b0;
    logic valid_i = 1'b0;
    logic signed [N-1:0] x_i = '0;
    logic signed [N-1:0] z_i = '0;
    logic signed [N-1:0] gamma_i = '0;
    logic valid_o;
    logic signed [N-1:0] y_o;
    logic overflow_o;

    integer vector_valid_i;
    logic [N-1:0] x_raw;
    logic [N-1:0] z_raw;
    logic [N-1:0] gamma_raw;
    logic [N-1:0] expected_i;
    logic [N-1:0] expected_pending;
    logic pending_valid;

    integer vector_fd;
    integer scan_status;
    integer checks;
    integer failures;
    integer row;

    fxp_axpy #(.N(N), .F(24)) dut (.*);

    always #(CLK_PERIOD_NS / 2) clk_ci = ~clk_ci;

    // Check the result for the transaction accepted one cycle earlier. The
    // AXPY stream accepts one scalar per valid cycle; the file's rows are
    // scalar transactions, not packed vector lanes.
    task automatic check_previous_result;
        begin
            if (pending_valid) begin
                checks = checks + 1;
                if (!valid_o || y_o !== expected_pending) begin
                    failures = failures + 1;
                    $error("row %0d: expected y=%08h, got valid=%b y=%08h",
                           row, expected_pending, valid_o, y_o);
                end
            end else if (valid_o) begin
                failures = failures + 1;
                $error("unexpected valid output before a pending transaction");
            end
        end
    endtask

    initial begin
        pending_valid = 1'b0;
        expected_pending = '0;
        checks = 0;
        failures = 0;
        row = 0;

        repeat (2) @(posedge clk_ci);
        @(negedge clk_ci);
        rst_ni = 1'b1;

        vector_fd = $fopen(VECTOR_FILE, "r");
        if (vector_fd == 0)
            $fatal(1, "Cannot open scalar AXPY vector file: %s", VECTOR_FILE);

        while (!$feof(vector_fd)) begin
            scan_status = $fscanf(vector_fd, "%d %h %h %h %h\n",
                                  vector_valid_i, gamma_raw, x_raw, z_raw,
                                  expected_i);
            if (scan_status == 5) begin
                @(negedge clk_ci);
                valid_i = vector_valid_i[0];
                gamma_i = $signed(gamma_raw);
                x_i = $signed(x_raw);
                z_i = $signed(z_raw);

                @(posedge clk_ci);
                #1;
                check_previous_result();
                pending_valid = vector_valid_i[0];
                expected_pending = expected_i;
                row = row + 1;
            end else if (scan_status != -1) begin
                $fatal(1, "malformed AXPY vector row %0d (fields=%0d)",
                       row, scan_status);
            end
        end
        $fclose(vector_fd);

        // Drain the one-cycle pipeline so the last input is checked too.
        @(negedge clk_ci);
        valid_i = 1'b0;
        @(posedge clk_ci);
        #1;
        check_previous_result();
        pending_valid = 1'b0;

        if (failures != 0 || checks != row)
            $fatal(1, "fxp_axpy failed: %0d failures across %0d/%0d rows",
                   failures, checks, row);

        $display("fxp_axpy_tb PASS: %0d scalar stream transactions", checks);
        $finish;
    end
endmodule
