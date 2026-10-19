`timescale 1ns/1ps

module fxp_axpy_tb;
    localparam int N = 32;
    localparam int F = 24;
    localparam int NUM_CASES = 8;

    logic clk_ci = 1'b0;
    logic rst_ni = 1'b0;
    logic valid_i = 1'b0;
    logic signed [N-1:0] x_i = '0;
    logic signed [N-1:0] z_i = '0;
    logic signed [N-1:0] gamma_i = '0;

    logic valid_o;
    logic signed [N-1:0] y_o;
    logic overflow_o;

    logic signed [N-1:0] x_cases [NUM_CASES];
    logic signed [N-1:0] z_cases [NUM_CASES];
    logic signed [N-1:0] gamma_cases [NUM_CASES];
    logic case_valid [NUM_CASES];

    integer checks;

    fxp_axpy #(.N(N), .F(F)) dut (
        .clk_ci,
        .rst_ni,
        .valid_i,
        .x_i,
        .z_i,
        .gamma_i,
        .valid_o,
        .y_o,
        .overflow_o
    );

    always #5 clk_ci = ~clk_ci;

    function automatic logic signed [N-1:0] expected_result(
        input logic signed [N-1:0] x,
        input logic signed [N-1:0] z,
        input logic signed [N-1:0] gamma
    );
        logic signed [2*N-1:0] product;
        logic signed [2*N-1:0] scaled_product;
        begin
            product = gamma * z;
            scaled_product = product >>> F;
            expected_result = x + scaled_product[N-1:0];
        end
    endfunction

    function automatic logic expected_overflow(
        input logic signed [N-1:0] x,
        input logic signed [N-1:0] z,
        input logic signed [N-1:0] gamma
    );
        logic signed [2*N-1:0] product;
        logic signed [2*N-1:0] scaled_product;
        logic signed [N-1:0] wrapped_product;
        logic signed [2*N-1:0] sum;
        begin
            product = gamma * z;
            scaled_product = product >>> F;
            wrapped_product = scaled_product[N-1:0];
            sum = {{N{ x[N-1]}}, x}
                + {{N{wrapped_product[N-1]}}, wrapped_product};
            expected_overflow =
                (scaled_product > 64'sh0000_0000_7fff_ffff)
                || (scaled_product < -64'sh0000_0000_8000_0000)
                || (sum > 64'sh0000_0000_7fff_ffff)
                || (sum < -64'sh0000_0000_8000_0000);
        end
    endfunction

    initial begin
        x_cases[0] = 32'sh0100_0000;
        z_cases[0] = 32'sh0200_0000;
        gamma_cases[0] = 32'sh0080_0000;
        case_valid[0] = 1'b1;

        x_cases[1] = -32'sh0180_0000;
        z_cases[1] = 32'sh0100_0000;
        gamma_cases[1] = -32'sh0040_0000;
        case_valid[1] = 1'b1;

        x_cases[2] = 32'sh0000_0000;
        z_cases[2] = 32'sh0000_0001;
        gamma_cases[2] = 32'sh0100_0000;
        case_valid[2] = 1'b0;

        x_cases[3] = 32'sh0000_0003;
        z_cases[3] = -32'sh0000_0001;
        gamma_cases[3] = 32'sh0100_0000;
        case_valid[3] = 1'b1;

        x_cases[4] = 32'sh7fff_ff00;
        z_cases[4] = 32'sh0000_0100;
        gamma_cases[4] = 32'sh0100_0000;
        case_valid[4] = 1'b1;

        x_cases[5] = 32'sh8000_0100;
        z_cases[5] = 32'sh0000_0100;
        gamma_cases[5] = 32'sh0100_0000;
        case_valid[5] = 1'b1;

        x_cases[6] = -32'sh0100_0000;
        z_cases[6] = 32'sh0180_0000;
        gamma_cases[6] = 32'sh0040_0000;
        case_valid[6] = 1'b0;

        x_cases[7] = 32'sh0000_0000;
        z_cases[7] = 32'sh0100_0000;
        gamma_cases[7] = 32'sh0180_0000;
        case_valid[7] = 1'b1;

        repeat (2) @(posedge clk_ci);
        rst_ni = 1'b1;

        checks = 0;
        for (int i = 0; i < NUM_CASES; i++) begin
            @(negedge clk_ci);
            valid_i = case_valid[i];
            x_i = x_cases[i];
            z_i = z_cases[i];
            gamma_i = gamma_cases[i];

            @(posedge clk_ci);
            #1;
            if (valid_o) begin
                if (i == 0 ||
                    y_o !== expected_result(
                        x_cases[i-1], z_cases[i-1], gamma_cases[i-1])
                    || overflow_o !== expected_overflow(
                        x_cases[i-1], z_cases[i-1], gamma_cases[i-1])) begin
                    $fatal(1, "unexpected result at cycle %0d: got %h overflow=%b",
                           i, y_o, overflow_o);
                end
                checks = checks + 1;
            end
        end

        @(negedge clk_ci);
        valid_i = 1'b0;
        @(posedge clk_ci);
        #1;
        if (valid_o) begin
            if (y_o !== expected_result(
                    x_cases[NUM_CASES-1], z_cases[NUM_CASES-1],
                    gamma_cases[NUM_CASES-1])
                || overflow_o !== expected_overflow(
                    x_cases[NUM_CASES-1], z_cases[NUM_CASES-1],
                    gamma_cases[NUM_CASES-1])) begin
                $fatal(1, "unexpected final result: got %h overflow=%b",
                       y_o, overflow_o);
            end
            checks = checks + 1;
        end

        if (checks != 6)
            $fatal(1, "expected 6 valid outputs, got %0d", checks);

        $display("fxp_axpy_tb PASS: %0d streaming results checked", checks);
        $finish;
    end
endmodule
