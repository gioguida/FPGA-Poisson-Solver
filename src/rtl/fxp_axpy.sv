/** Fixed-point AXPY module
* computes y := x + gamma*z, where x and z are vectors of V elements of signed fixed-point numbers,
* each with N total bits and F fractional bits, and gamma is a signed fixed-point scalar.
* an input accepted at rising edge k produces y_o with valid_o=1 after rising edge k+1.
* LATENCY: 2 clock cycles, after valid_i=1 at rising edge
* RESET: Asynchronous, active-low reset (on falling edge)
* VALIDITY: results (y_o, overflow_o) only meaningful when valid_o=1,
*   when valid_o=0 outputs are unspecified
* ARITHMETIC: y[i] = wrap_N(x[i] + wrap_N((gamma * z[i]) >>> F))
*   uses moduled fxp_add and fxp_mul to perform element-wise operations.
*/
module fxp_axpy #(
    parameter int V = 256,  // vector size
    parameter int N = 32,   // total bits
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
    logic signed [V*N-1:0] gamma_z, x_d;
    logic valid_i_add;
    logic [V-1:0] valid_o_add, valid_o_prod;
    logic [V-1:0] prod_overflow, sum_overflow;
    logic prod_overflow_d;

    always_ff @(posedge clk_ci, negedge rst_ni) begin
        if (!rst_ni) begin  // reset active low
            x_d <= '0;
            prod_overflow_d <= 1'b0;
        end else begin 
            // delay x by one clock cycle to make it paired with prod output
            x_d <= x_i;
            prod_overflow_d <= |prod_overflow;
        end
    end

    assign valid_i_add = valid_o_prod[0];
    assign valid_o = valid_o_add[0];
    assign overflow_o = prod_overflow_d || (|sum_overflow);

    generate
        genvar i;
        for (i=0; i < V; i++) begin : gen_axpy

            localparam int high_idx = N*(i+1)-1;
            localparam int low_idx = N*i;

            fxp_mul #(.N, .F) axpy_mul (
                .clk_ci, 
                .rst_ni, 
                .valid_i(valid_i),
                .a_i(gamma_i),
                .b_i(z_i[high_idx:low_idx]),
                .valid_o(valid_o_prod[i]),
                .prod_o(gamma_z[high_idx:low_idx]),
                .overflow_o(prod_overflow[i])
            );

            fxp_add #(.N, .F) axpy_sum (
                .clk_ci, 
                .rst_ni, 
                .valid_i(valid_i_add),
                .a_i(x_d[high_idx:low_idx]),
                .b_i(gamma_z[high_idx:low_idx]),
                .valid_o(valid_o_add[i]),
                .sum_o(y_o[high_idx:low_idx]),
                .overflow_o(sum_overflow[i])
            );
        end
    endgenerate
endmodule
