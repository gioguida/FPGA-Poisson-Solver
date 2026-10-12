module fxp_mul #(
    parameter N = 32, F = 24
) (
    input logic clk_i,
    input logic en_i,
    input logic signed [N-1:0] a_i, b_i,
    output logic signed [N-1:0] prod_o,
    output logic overflow_o
);
    // signed N-bit extrema to check overflow 
    int signed localparam  MAX = 2**(N-1) - 1;
    int signed localparam  MIN = - 2**(N-1);

    // wide internal representations
    logic signed [2*N-1:0] a_wide, b_wide;
    logic signed [2*N-1:0] raw_prod, scaled_prod;

    assign a_wide = {{N{a_i[N-1]}}, a_i};
    assign b_wide = {{N{b_i[N-1]}}, b_i};

    // execute at clock signal
    always_ff @(posedge clk_i) begin
        raw_prod <= a_wide * b_wide;
        scaled_prod <= raw_prod >>> F;

        if(en_i) begin 
            // check overflow 
            if(scaled_prod > MAX || scaled_prod < MIN)
                overflow_o <= 1'b1;
            else
                overflow_o <= 1'b0;
            // fit back into N bits
            prod_o <= scaled_prod[N-1:0];
        end
    end
endmodule