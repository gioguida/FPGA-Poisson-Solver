`timescale 1ns/1ps

module poisson_stencil_engine_tb #(
    parameter int LANES = 4
);
    localparam int N = 16;
    localparam int F = 8;
    localparam int NX = 8;
    localparam int NY = 5;
    localparam int CELL_COUNT = NX*NY;
    localparam int DEPTH = NX*NY/LANES;
    localparam int ADDRW = $clog2(DEPTH);
    localparam int XBITS = $clog2(NX);
    localparam int YBITS = $clog2(NY);

    logic clk_ci = 1'b0;
    logic rst_ni = 1'b0;
    logic valid_i = 1'b0;
    logic [XBITS-1:0] I_i = '0;
    logic [YBITS-1:0] J_i = '0;
    logic ready_o, rd_en_o, ram_rd_valid, engine_rd_valid, valid_o, overflow_o;
    logic [ADDRW-1:0] rd_addr_o;
    logic [LANES*N-1:0] ram_rd_data, engine_rd_data;
    logic delayed_valid_q = 1'b0;
    logic delayed_pending_q = 1'b0;
    logic [LANES*N-1:0] delayed_data_q = '0;
    int unsigned delay_left_q = 0;
    int unsigned delayed_response_count = 0;
    logic delay_mode = 1'b0;
    int unsigned extra_delay = 3;
    logic signed [N-1:0] Ax_o;
    logic [XBITS-1:0] I_o;
    logic [YBITS-1:0] J_o;
    logic w_en_i = 1'b0;
    logic [ADDRW-1:0] w_addr_i = '0;
    logic [LANES*N-1:0] w_data_i = '0;
    logic signed [N-1:0] input_raw [0:CELL_COUNT-1];
    logic signed [N-1:0] expected_raw [0:CELL_COUNT-1];
    logic expected_overflow [0:CELL_COUNT-1];
    string vector_file;
    integer vector_fd;
    integer scan_status;
    integer vector_rows, vector_cols, vector_bits, vector_frac, vector_cases;
    integer overflow_scan;

    always #5 clk_ci = ~clk_ci;

    ram #(.WIDTH(N), .DEPTH(DEPTH), .LANES(LANES)) memory (
        .clk_ci, .rst_ni,
        .r_en_i(rd_en_o), .r_addr_i(rd_addr_o),
        .r_valid_o(ram_rd_valid), .r_data_o(ram_rd_data),
        .w_en_i, .w_addr_i, .w_data_i
    );

    poisson_stencil_engine #(
        .N(N), .F(F), .NX(NX), .NY(NY), .LANES(LANES)
    ) dut (
        .clk_ci, .rst_ni, .valid_i, .I_i, .J_i,
        .rd_valid_i(engine_rd_valid), .rd_data_i(engine_rd_data),
        .ready_o, .rd_en_o, .rd_addr_o,
        .valid_o, .Ax_o, .I_o, .J_o, .overflow_o
    );

    // The fetcher has one read outstanding, so one captured response suffices.
    // The data must travel with its valid pulse through the delay.
    assign engine_rd_valid = delay_mode ? delayed_valid_q : ram_rd_valid;
    assign engine_rd_data = delay_mode ? delayed_data_q : ram_rd_data;

    always @(posedge clk_ci or negedge rst_ni) begin
        if (!rst_ni) begin
            delayed_valid_q <= 1'b0;
            delayed_pending_q <= 1'b0;
            delayed_data_q <= '0;
            delay_left_q <= 0;
            delayed_response_count <= 0;
        end else begin
            delayed_valid_q <= 1'b0;
            if (delay_mode && ram_rd_valid) begin
                if (delayed_pending_q)
                    $fatal(1, "memory returned a second response while one is pending");
                delayed_data_q <= ram_rd_data;
                delay_left_q <= extra_delay;
                delayed_pending_q <= 1'b1;
            end else if (delayed_pending_q) begin
                if (delay_left_q == 0) begin
                    delayed_valid_q <= 1'b1;
                    delayed_pending_q <= 1'b0;
                    delayed_response_count <= delayed_response_count + 1;
                end else begin
                    delay_left_q <= delay_left_q - 1;
                end
            end
        end
    end

    // A result before the captured memory response is released is invalid.
    always @(posedge clk_ci) begin
        #1;
        if (rst_ni && delay_mode && delayed_pending_q && valid_o)
            $fatal(1, "stencil result arrived before delayed memory response");
    end

    task automatic check_point(input int x, input int y);
        int cycles;
        int index;
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
            I_i = XBITS'((x+1) % NX);
            J_i = YBITS'((y+1) % NY);

            cycles = 0;
            while (!valid_o && cycles < 100) begin
                @(posedge clk_ci);
                #1;
                cycles++;
                if (ready_o && !valid_o)
                    $fatal(1, "engine accepted another request before result");
            end
            if (!valid_o) $fatal(1, "timeout at (%0d,%0d)", x, y);

            index = x + NX*y;
            if (Ax_o !== expected_raw[index] || I_o !== XBITS'(x)
                || J_o !== YBITS'(y)
                || overflow_o !== expected_overflow[index])
                $fatal(1, "wrong result at (%0d,%0d): Ax=%0d expected=%0d tag=(%0d,%0d) overflow=%b expected_overflow=%b",
                       x, y, Ax_o, expected_raw[index], I_o, J_o,
                       overflow_o, expected_overflow[index]);

            @(posedge clk_ci);
            #1;
            if (valid_o || !ready_o)
                $fatal(1, "result valid did not pulse or engine did not recover");
            @(negedge clk_ci);
            valid_i = 1'b0;
        end
    endtask

    task automatic start_request(input int x, input int y);
        @(negedge clk_ci);
        if (!ready_o) $fatal(1, "engine not ready for reset scenario");
        I_i = XBITS'(x);
        J_i = YBITS'(y);
        valid_i = 1'b1;
        @(posedge clk_ci);
        #1;
        if (ready_o) $fatal(1, "request was not accepted");
        @(negedge clk_ci);
        valid_i = 1'b0;
    endtask

    task automatic reset_and_check_quiet;
        @(negedge clk_ci);
        rst_ni = 1'b0;
        valid_i = 1'b0;
        repeat (2) begin
            @(posedge clk_ci);
            #1;
            if (valid_o || delayed_pending_q || delayed_valid_q)
                $fatal(1, "reset did not clear an in-flight response");
        end
        @(negedge clk_ci);
        rst_ni = 1'b1;
        repeat (40) begin
            @(posedge clk_ci);
            #1;
            if (valid_o || !ready_o || delayed_pending_q || delayed_valid_q)
                $fatal(1, "aborted request produced activity after reset");
        end
    endtask

    initial begin
        vector_file = "../build/test_vectors/fxp_stencil_Q8_8.hex";
        if ($value$plusargs("STENCIL_VECTORS=%s", vector_file)) begin end
        vector_fd = $fopen(vector_file, "r");
        if (vector_fd == 0)
            $fatal(1, "cannot open stencil vectors: %s", vector_file);
        scan_status = $fscanf(vector_fd, "%d %d %d %d %d\n",
                              vector_rows, vector_cols, vector_bits,
                              vector_frac, vector_cases);
        if (scan_status != 5 || vector_rows != NX || vector_cols != NY
            || vector_bits != N || vector_frac != F || vector_cases < 3)
            $fatal(1, "stencil vector metadata does not match testbench");

        repeat (2) @(negedge clk_ci);
        rst_ni = 1'b1;
        for (int p = 0; p < vector_cases; p++) begin
            for (int index = 0; index < CELL_COUNT; index++) begin
                scan_status = $fscanf(vector_fd, "%h %h %d\n",
                                      input_raw[index], expected_raw[index],
                                      overflow_scan);
                if (scan_status != 3 || (overflow_scan != 0 && overflow_scan != 1))
                    $fatal(1, "invalid stencil vector at case %0d cell %0d", p, index);
                expected_overflow[index] = 1'(overflow_scan);
            end
            for (int word = 0; word < DEPTH; word++) begin
                @(negedge clk_ci);
                w_en_i = 1'b1;
                w_addr_i = ADDRW'(word);
                for (int lane = 0; lane < LANES; lane++) begin
                    int index;
                    index = word*LANES + lane;
                    w_data_i[lane*N +: N] = input_raw[index];
                end
            end
            @(negedge clk_ci);
            w_en_i = 1'b0;

            // Exercise every position with extra memory latency on one field.
            delay_mode = (p == 2);

            for (int y = 0; y < NY; y++)
                for (int x = 0; x < NX; x++)
                    check_point(x, y);
            if (p == 2 && delayed_response_count == 0)
                $fatal(1, "delayed-memory scenario never returned a response");
        end
        $fclose(vector_fd);

        // Cancel a request while its first RAM response is held by the adapter.
        @(negedge clk_ci);
        delay_mode = 1'b1;
        extra_delay = 5;
        start_request(3, 2);
        begin
            int cycles;
            cycles = 0;
            while (!delayed_pending_q && cycles < 20) begin
                @(posedge clk_ci);
                #1;
                cycles++;
            end
            if (!delayed_pending_q || delayed_valid_q || valid_o)
                $fatal(1, "did not reach a pending delayed memory response");
        end
        reset_and_check_quiet();
        check_point(5, 4);

        // Cancel a second request after fetch completes and arithmetic starts.
        @(negedge clk_ci);
        delay_mode = 1'b0;
        start_request(3, 2);
        begin
            int cycles;
            cycles = 0;
            while (!dut.done_fetch && cycles < 40) begin
                @(posedge clk_ci);
                #1;
                cycles++;
            end
            if (!dut.done_fetch) $fatal(1, "fetch did not finish before reset");
        end
        @(posedge clk_ci);
        #1;
        if (valid_o) $fatal(1, "arithmetic result arrived before reset");
        reset_and_check_quiet();
        check_point(1, 3);

        $display("poisson_stencil_engine_tb PASS: LANES=%0d", LANES);
        $finish;
    end
endmodule
