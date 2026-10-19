/** FIXED POINT AXPY MODULE
* computes y := x + gamma*z, where x and z are vectors of V elements of signed fixed-point numbers,
*   each with N total bits and F fractional bits, and gamma is a signed fixed-point scalar.
*   K is number if chunks in which the vectors are divided for time multiplexed computation.
* LATENCY: K+1 clock cycles, after valid_i=1 at rising edge
*   input accepted at rising edge n with valid_i=1 produces 
*   corresponding output with valid_o=1 at clock edge n+K+1.
* RESET: Asynchronous, active-low reset (on falling edge)
* VALIDITY: results (y_o, overflow_o) only meaningful when valid_o=1,
*   when valid_o=0 outputs are unspecified
* ARITHMETIC: y[i] = wrap_N(x[i] + wrap_N((gamma * z[i]) >>> F))
*   uses moduled fxp_add and fxp_mul to perform element-wise operations.
*/
module fxp_axpy #(
    parameter int V = 256,  // vector size
    parameter int K = 8,    // number of chunks
    parameter int N = 32,   // total bits per element
    parameter int F = 24    // fractional bits
) (
    input logic clk_ci,
    input logic rst_ni,

    input logic valid_i,
    input logic signed [V*N-1:0] x_i, z_i,
    input logic signed [N-1:0] gamma_i,

    output logic valid_o,
    output logic signed [V*N-1:0] y_o,
    output logic overflow_o
);

    localparam int LANES = V / K;       // number of fxp elements processed in parallel
    localparam int SLICE = N * LANES;   // number of bits processed in parallel
    localparam int CW = $clog2(K + 1);  // n of bits to represent counter step

    // Controller
    logic busy_q;                   // whether any transaction is active
    logic [CW-1:0] step_q;          // next chunk to send into multiplier

    // Saved input operands
    logic signed [V*N-1:0] x_q, z_q;
    logic signed [N-1:0] gamma_q;

    // Shared arithmetic datapath
    logic signed [SLICE-1:0] mul_i;
    logic signed [SLICE-1:0] mul_o;

    logic signed [SLICE-1:0] add_x_i;
    logic signed [SLICE-1:0] add_o;

    // Valid signals: one common control per stage
    logic mul_valid_i;
    logic add_valid_i;

    logic [LANES-1:0] mul_valid_o;
    logic [LANES-1:0] add_valid_o;

    // Pipeline metadata
    logic [CW-1:0] mul_chunk_q;     // index of chunk entering multiplier
    logic [CW-1:0] add_chunk_q;     // index of chunk entering adder

    // Overflow
    logic [LANES-1:0] prod_overflow;
    logic [LANES-1:0] sum_overflow;
    logic overflow_q;

    // datapath scheduling
    always_comb begin : g_axpy_next_state
        mul_i = '0;
        add_x_i = '0;

        mul_valid_i = busy_q && (step_q < K);

        // Multiplication results from the previous edge
        add_valid_i = mul_valid_o[0];

        if (mul_valid_i)
            mul_i = z_q[step_q*SLICE +: SLICE];

        if (add_valid_i)
            add_x_i = x_q[mul_chunk_q*SLICE +: SLICE];
    end

    // controller and output registers
    always_ff @(posedge clk_ci, negedge rst_ni) begin : axpy_reg
        if (!rst_ni) begin
            busy_q <= 1'b0;
            step_q <= '0;

            x_q <= '0;
            z_q <= '0;
            gamma_q <= '0;

            mul_chunk_q <= '0;
            add_chunk_q <= '0;

            y_o <= '0;
            valid_o <= 1'b0;
            overflow_q <= 1'b0;

        end else begin
            valid_o <= 1'b0;

            if (!busy_q) begin
                if (valid_i) begin
                    // Start a new transaction
                    x_q <= x_i;
                    z_q <= z_i;
                    gamma_q <= gamma_i;

                    y_o <= '0;
                    overflow_q <= 1'b0;

                    step_q <= '0;
                    busy_q <= 1'b1;

                end

            end else begin
                // Accumulate overflows
                overflow_q <= overflow_q
                    | (mul_valid_o[0] && (|prod_overflow))
                    | (add_valid_o[0] && (|sum_overflow));

                // Advance the multiplication schedule
                if (step_q < K)
                    step_q <= step_q + 1'b1;

                // Track which chunk is being multiplied
                if (mul_valid_i)
                    mul_chunk_q <= step_q;

                // Track which chunk is entering the adder
                if (add_valid_i) 
                    add_chunk_q <= mul_chunk_q;

                // Save completed addition results
                if (add_valid_o[0]) begin
                    y_o[add_chunk_q*SLICE +: SLICE] <= add_o;

                    if (add_chunk_q == K-1) begin
                        valid_o <= 1'b1;
                        busy_q <= 1'b0;
                    end
                end
            end
        end
    end

    assign overflow_o = overflow_q;

    // arithmetic lanes
    generate
        for (genvar i = 0; i < LANES; i++) begin : gen_axpy
            localparam int LOW = N*i;
            localparam int HIGH = N*(i+1)-1;
            fxp_mul #(.N(N), .F(F)) u_mul (
                .clk_ci,
                .rst_ni,
                .valid_i(mul_valid_i),
                .a_i(gamma_q),
                .b_i(mul_i[HIGH:LOW]),
                .valid_o(mul_valid_o[i]),
                .prod_o(mul_o[HIGH:LOW]),
                .overflow_o(prod_overflow[i])
            );

            fxp_add #(.N(N), .F(F)) u_add (
                .clk_ci,
                .rst_ni,
                .valid_i(add_valid_i),
                .a_i(add_x_i[HIGH:LOW]),
                .b_i(mul_o[HIGH:LOW]),
                .valid_o(add_valid_o[i]),
                .sum_o(add_o[HIGH:LOW]),
                .overflow_o(sum_overflow[i])
            );

        end
    endgenerate

endmodule
