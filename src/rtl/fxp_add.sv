module fxp_add #(
    parameter int N = 32, 
    parameter int F = 24
) (
    input logic clk_ci,
    input logic en_i,
    input logic rst_ni,
    input logic signed [N-1:0] a_i, b_i,
    output logic signed [N-1:0] sum_o,
    output logic overflow_o
);
    // signed N-bit extrema to check overflow 
    localparam int signed MAX = 2**(N-1) - 1;
    localparam int signed MIN = -2**(N-1);

    // wide internal representations
    logic signed [2*N-1:0] a_wide, b_wide;
    logic signed [2*N-1:0] raw_sum;

    always_comb begin
        a_wide = {{N{a_i[N-1]}}, a_i};
        b_wide = {{N{b_i[N-1]}}, b_i};
        raw_sum = a_wide + b_wide;
    end

    // execute at clock signal
    always_ff @(posedge clk_ci, negedge rst_ni) begin : ff_add
        if (rst_ni) begin
            if(en_i) begin 
                // check overflow 
                if(raw_sum > MAX || raw_sum < MIN)
                    overflow_o <= 1'b1;
                else
                    overflow_o <= 1'b0;
                // fit back into N bits
                sum_o <= raw_sum[N-1:0];
            end
        end else begin
            sum_o <= '0;
            overflow_o <= 1'b0;
        end 
    end
endmodule