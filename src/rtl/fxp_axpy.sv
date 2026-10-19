/** FIXED POINT AXPY MODULE
* computes y := x + gamma*z, where x and z are signed fixed-point numbers,
*   each with N total bits and F fractional bits, and gamma is a signed fixed-point scalar.
* STREAMING: accepts one element whenever valid_i is high and may accept
*   consecutive elements on successive cycles.
* LATENCY: one clock cycle from input acceptance to output valid.
*   An input accepted at rising edge k produces y_o with valid_o=1 after
*   rising edge k+1.
* RESET: Asynchronous, active-low reset (on falling edge)
* VALIDITY: results (y_o, overflow_o) only meaningful when valid_o=1,
*   when valid_o=0 outputs are unspecified
* ARITHMETIC: y = wrap_N(x + wrap_N((gamma * z) >>> F))
*   uses the fxp_add and fxp_mul modules to process each stream element.
*/
module fxp_axpy #(
    parameter int N = 32,   // total bits
    parameter int F = 24    // fractional bits
) (
    input logic clk_ci,
    input logic rst_ni,

    input logic valid_i,
    input logic signed [N-1:0] x_i, z_i,
    input logic signed [N-1:0] gamma_i,

    output logic valid_o,
    output logic signed [N-1:0] y_o,
    output logic overflow_o
);
    logic signed [N-1:0] gamma_z, x_q;

    logic valid_i_add, valid_o_add;
    logic valid_o_prod;

    logic prod_overflow, sum_overflow;
    logic prod_overflow_q;

    always_ff @(posedge clk_ci, negedge rst_ni) begin
        if (!rst_ni) begin
            x_q <= '0;
            prod_overflow_q <= 1'b0;
        end else begin
            // delay x by one clock cycle to make it paired with prod output
            x_q <= x_i;
            prod_overflow_q <= prod_overflow;
        end
    end

    assign valid_i_add = valid_o_prod;
    assign valid_o = valid_o_add;
    assign overflow_o = prod_overflow_q || sum_overflow;

    fxp_mul #(.N(N), .F(F)) axpy_mul (
        .clk_ci,
        .rst_ni,
        .valid_i(valid_i),
        .a_i(gamma_i),
        .b_i(z_i),
        .valid_o(valid_o_prod),
        .prod_o(gamma_z),
        .overflow_o(prod_overflow)
    );

    fxp_add #(.N(N), .F(F)) axpy_sum (
        .clk_ci,
        .rst_ni,
        .valid_i(valid_i_add),
        .a_i(x_q),
        .b_i(gamma_z),
        .valid_o(valid_o_add),
        .sum_o(y_o),
        .overflow_o(sum_overflow)
    );
endmodule