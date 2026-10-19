/** POISSON STENCIL OPERATOR
* Computes one component of the finite-difference Laplacian:
*   (Ax)[i,j] := 4x[i,j] - x[i-1,j] - x[i+1,j] - x[i,j-1] - x[i,j+1]
* INTERFACE: A transaction is accepted on every rising edge for which valid_i is high.
*   Inputs may be presented on consecutive cycles; there is no busy state or
*   backpressure interface. valid_o identifies the corresponding output.
* PIPELINE: The datapath contains two parallel first-stage adders, one neighbor-sum
*   adder, and one subtraction. The pipeline has a fixed latency of four
*   clock cycles from input acceptance to valid_o and an initiation interval
*   of one cycle.
* BOUNDARIES: For homogeneous Dirichlet boundaries, the caller supplies zero for
*   neighbors outside the grid.
* ARITHMETIC: Results wrap to N bits. overflow_o reports overflow in any operation
*   associated with the output transaction.
*/
module poisson_stencil #(
    parameter int N = 32,
    parameter int F = 24
) (
    input logic clk_ci,
    input logic rst_ni,

    input logic valid_i,
    input logic signed [N-1:0] x_center_i,
    input logic signed [N-1:0] x_north_i,
    input logic signed [N-1:0] x_south_i,
    input logic signed [N-1:0] x_west_i,
    input logic signed [N-1:0] x_east_i,

    output logic valid_o,
    output logic signed [N-1:0] Ax_o,
    output logic overflow_o
);
    // signed N-bit extrema, extended for the center-times-four check
    localparam logic signed [N+1:0] MAX = {{3{1'b0}}, {(N-1){1'b1}}};
    localparam logic signed [N+1:0] MIN = {{3{1'b1}}, {(N-1){1'b0}}};

    logic signed [N-1:0] center_s0_q, center_s1_q, center_s2_q, center_s3_q;

    logic signed [N+1:0] center_times_4_wide;
    logic signed [N-1:0] sum_ns, sum_we, sum_neighbours;
    logic signed [N-1:0] a_1, b_1, a_2, b_2, a_3, b_3;
    logic signed [N-1:0] minuend, subtrahend;
    logic signed [N-1:0] difference;

    logic valid_i_add_ns, valid_i_add_we, valid_i_add_final;
    logic valid_o_add_ns, valid_o_add_we, valid_o_add_final;
    logic valid_i_sub, valid_o_sub;

    logic [2:0] sum_overflow;
    logic sub_overflow;
    logic scale_overflow;
    logic overflow_s0_q, overflow_s1_q, overflow_s2_q, overflow_s3_q;

    always_comb begin
        center_times_4_wide =
            $signed({{2{x_center_i[N-1]}}, x_center_i}) <<< 2;

        valid_i_add_ns = valid_i;
        valid_i_add_we = valid_i;

        valid_i_add_final = valid_o_add_ns && valid_o_add_we;
        valid_i_sub = valid_o_add_final;

        a_1 = x_north_i;
        b_1 = x_south_i;
        a_2 = x_west_i;
        b_2 = x_east_i;
        a_3 = sum_ns;
        b_3 = sum_we;

        minuend = center_s3_q;
        subtrahend = sum_neighbours;
    end

    always_ff @(posedge clk_ci, negedge rst_ni) begin
        if (!rst_ni) begin
            valid_o <= 1'b0;

            center_s0_q <= '0;
            center_s1_q <= '0;
            center_s2_q <= '0;
            center_s3_q <= '0;

            overflow_s0_q <= 1'b0;
            overflow_s1_q <= 1'b0;
            overflow_s2_q <= 1'b0;
            overflow_s3_q <= 1'b0;
            scale_overflow <= 1'b0;

            Ax_o <= '0;
            overflow_o <= 1'b0;
        end else begin
            valid_o <= valid_o_sub;

            if (valid_i) begin
                scale_overflow <= (center_times_4_wide > MAX)
                                || (center_times_4_wide < MIN);
                center_s0_q <= center_times_4_wide[N-1:0];
            end

            center_s1_q <= center_s0_q;
            center_s2_q <= center_s1_q;
            center_s3_q <= center_s2_q;

            if (valid_o_sub) begin
                Ax_o <= difference;
                overflow_o <= overflow_s3_q || sub_overflow;
            end

            overflow_s0_q <= (valid_o_add_ns && valid_o_add_we)
                      && (scale_overflow
                          || sum_overflow[0]
                          || sum_overflow[1]);

            overflow_s1_q <= overflow_s0_q;

            overflow_s2_q <= overflow_s1_q
                      || (valid_o_add_final && sum_overflow[2]);
            overflow_s3_q <= overflow_s2_q;
        end
    end

    fxp_add #(.N(N), .F(F)) stencil_sum_ns (
        .clk_ci,
        .rst_ni,
        .valid_i(valid_i_add_ns),
        .a_i(a_1),
        .b_i(b_1),
        .valid_o(valid_o_add_ns),
        .sum_o(sum_ns),
        .overflow_o(sum_overflow[0])
    );

    fxp_add #(.N(N), .F(F)) stencil_sum_we (
        .clk_ci,
        .rst_ni,
        .valid_i(valid_i_add_we),
        .a_i(a_2),
        .b_i(b_2),
        .valid_o(valid_o_add_we),
        .sum_o(sum_we),
        .overflow_o(sum_overflow[1])
    );

    fxp_add #(.N(N), .F(F)) stencil_sum_final (
        .clk_ci,
        .rst_ni,
        .valid_i(valid_i_add_final),
        .a_i(a_3),
        .b_i(b_3),
        .valid_o(valid_o_add_final),
        .sum_o(sum_neighbours),
        .overflow_o(sum_overflow[2])
    );

    fxp_sub #(.N(N), .F(F)) stencil_sub (
        .clk_ci,
        .rst_ni,
        .valid_i(valid_i_sub),
        .a_i(minuend),
        .b_i(subtrahend),
        .valid_o(valid_o_sub),
        .diff_o(difference),
        .overflow_o(sub_overflow)
    );
endmodule   