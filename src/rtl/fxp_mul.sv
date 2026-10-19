/** FIXED POINT PRODUCT MODULE
* multiplies two signed fixed-point numbers a and b, each with N total bits and F fractional bits.
* Product is computed with wider format (2N, 2F) and then shifted right, rounding occurs towards -inf.
* overflow is detected if the result exceeds the representable range,
* in this case the lower N bits of the result are returned, no saturation.
* valid_o is valid_i delayed by one rising edge.
* LATENCY: 1 clock cycle, after valid_i=1 at rising edge
* RESET: Asynchronous, active-low reset (on falling edge)
* VALIDITY: results (prod_o, overflow_o) only meaningful when valid_o=1
*   when valid_o=0 outputs are unspecified
*/
module fxp_mul #(
    parameter int N = 32,   // total bits
    parameter int F = 24    // fractional bits
) (
    input logic clk_ci,
    input logic rst_ni,

    input logic valid_i,
    input logic signed [N-1:0] a_i, b_i,

    output logic valid_o,
    output logic signed [N-1:0] prod_o,
    output logic overflow_o
);
    // signed N-bit extrema to check overflow 
    localparam logic signed [N-1:0] MAX = {1'b0, (N-1){1'b1}};
    localparam logic signed [N-1:0] MIN = {1'b1, (N-1){1'b0}};

    // wide internal representations
    logic signed [2*N-1:0] a_wide, b_wide;
    logic signed [2*N-1:0] raw_prod, scaled_prod;

    always_comb begin: g_mul_next_state
        a_wide = {{N{a_i[N-1]}}, a_i};
        b_wide = {{N{b_i[N-1]}}, b_i};
        raw_prod = a_wide * b_wide;
        scaled_prod = raw_prod >>> F;
    end

    // execute at clock signal
    always_ff @(posedge clk_ci, negedge rst_ni) begin : mul_reg
        if (!rst_ni) begin  // reset active low
            prod_o <= '0;
            overflow_o <= 1'b0;
            valid_o <= 1'b0;
        end else begin
            // check overflow
            if ((scaled_prod > MAX) || (scaled_prod < MIN))
                overflow_o  <= 1'b1;
            else overflow_o <= 1'b0;

            prod_o <= scaled_prod[N-1:0];
            valid_o <= valid_i;
        end 
    end
endmodule
