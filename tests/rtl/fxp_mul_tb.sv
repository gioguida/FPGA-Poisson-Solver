`timescale 1ns/1ps

module test_fxp_mul;
    // 100 MHz test clock.  
    localparam int CLK_PERIOD_NS = 10;

    // Run the simulator from the repository root so this relative path finds
    // the C++-generated vector file.
    localparam string VECTOR_FILE = "../build/test_vectors/fxp_mul_Q8.hex";

    // DUT clock, control, input, and result signals.
    logic clk_ci = 1'b0;
    logic rst_ni;
    logic en_i;
    logic signed [31:0] a_i;
    logic signed [31:0] b_i;
    logic signed [31:0] prod_o;
    logic overflow_o;

    // A vector-file row has: valid_i a_raw b_raw expected_y_raw.
    // valid_i is testbench metadata: fxp_mul has en_i but no valid output.
    logic valid_i;
    logic [31:0] a_raw;
    logic [31:0] b_raw;
    logic [31:0] expected_i;
    
    integer vector_fd;
    integer scan_status;
    integer checks;
    integer failures;

    // Q8.24 instance under test.
    fxp_mul #(.N(32), .F(24)) dut (
        .clk_ci(clk_ci),
        .en_i(en_i),
        .rst_ni(rst_ni),
        .a_i(a_i),
        .b_i(b_i),
        .prod_o(prod_o),
        .overflow_o(overflow_o)
    );

    // Free-running clock used by both the driver and DUT.
    always #(CLK_PERIOD_NS / 2) clk_ci = ~clk_ci;

    // Advance one DUT clock and check the result captured from the inputs
    // driven before this edge.  #1 waits for DUT non-blocking assignments
    // to update before prod_o is examined.
    task automatic tick_and_check;
        begin
            @(posedge clk_ci);
            #1;

            if (valid_i) begin
                ++checks;
                if (prod_o !== expected_i) begin
                    ++failures;
                    $error("vector %0d: a=%08h b=%08h expected=%08h got=%08h",
                           checks, a_raw, b_raw, expected_i, prod_o);
                end
            end
        end
    endtask

    initial begin
        // Put the testbench and DUT inputs into known states.  The DUT takes
        // its reset branch while rst_ni is low, then starts processing after
        // rst_ni is set high.
        rst_ni = 1'b0;
        en_i = 1'b0;
        a_i = '0;
        b_i = '0;
        valid_i = 1'b0;
        expected_i = '0;
        checks = 0;
        failures = 0;

        @(posedge clk_ci);
        #1 rst_ni = 1'b1;

        // The vectors use hexadecimal raw two's-complement bit patterns.
        // Assigning a_raw/b_raw to signed DUT signals preserves those bits.
        vector_fd = $fopen(VECTOR_FILE, "r");
        if (vector_fd == 0) begin
            $fatal(1, "Cannot open vector file: %s", VECTOR_FILE);
        end

        while (!$feof(vector_fd)) begin
            scan_status = $fscanf(vector_fd, "%d %h %h %h\n",
                                  valid_i, a_raw, b_raw, expected_i);
            if (scan_status == 4) begin
                // Drive at the falling edge so inputs are stable before the
                // next rising edge, when fxp_mul samples them.
                @(negedge clk_ci);
                en_i = valid_i;
                a_i = $signed(a_raw);
                b_i = $signed(b_raw);
                tick_and_check();
            end
        end
        $fclose(vector_fd);

        // A nonzero failure count makes the simulator return a failing test.
        // overflow_o is intentionally not checked: the vector format contains
        // expected product bits only, not a per-vector overflow expectation.
        if (failures != 0) begin
            $fatal(1, "fxp_mul failed %0d of %0d checks", failures, checks);
        end

        $display("fxp_mul passed %0d vector checks", checks);
        $finish;
    end
endmodule
