// y := x + gamma*z
module fxp_axpy #(
    parameter int V = 256,  // vector size
    parameter int N = 32, 
    parameter int F = 24
) (
    input logic clk_ci,
    input logic en_i,
    input logic rst_ni,
    input logic signed [V*N-1:0] x_i, z_i, 
    input logic signed [N-1:0] gamma_i,
    output logic signed [V*N-1:0] y_o,
    output logic overflow_o
);  
    logic signed [V*N-1:0] gamma_z, x_d;
    logic [V-1:0] prod_overflow, sum_overflow;
    logic signed [V*N-1:0] x_d;     // delayed input for the final sum
    logic en_d;                     // delayed enable for final sum

    always_ff @(posedge clk_ci, negedge rst_ni) begin
        if (!rst_ni) begin
            x_d <= '0;
            en_d <= 1'b0;
        end else begin 
            en_d <= en_i;
            if (en_i) 
                x_d <= x_i;
        end
    end

    generate
        genvar i;
        for (i=0; i < V; i++) begin : gen_axpy
            localparam int high_idx = N*(i+1)-1;
            localparam int low_idx = N*i;
            fxp_mul #(.N, .F) mul (
                .clk_ci, 
                .en_i, 
                .rst_ni, 
                .a_i(gamma_i),
                .b_i(z_i[high_idx:low_idx]),
                .prod_o(gamma_z[high_idx:low_idx]),
                .overflow_o(prod_overflow[i])
            );

            fxp_add #(.N, .F) sum (
                .clk_ci, 
                .en_i(en_d), 
                .rst_ni, 
                .a_i(x_d[high_idx:low_idx]),
                .b_i(gamma_z[high_idx:low_idx]),
                .sum_o(y_o[high_idx:low_idx]),
                .overflow_o(sum_overflow[i])
            );
        end
    endgenerate
    assign overflow_o = (|prod_overflow) || (|sum_overflow);
endmodule