/** POISSON STENCIL ENGINE
* Accepts one in-range (I_i, J_i) request when valid_i && ready_o.
* Reads the neighborhood through the external memory interface, then emits
* one Ax_o result with its coordinates and overflow flag when valid_o is high.
* Only one request is outstanding. Fetch time depends on the neighborhood;
* the stencil pipeline takes four cycles after accepting done_fetch.
* Output data and coordinates are meaningful only while valid_o is high.
*/
module poisson_stencil_engine #(
    parameter int N = 32,
    parameter int F = 24,
    parameter int ROWS = 32,
    parameter int COLS = 32,
    parameter int LANES = 4,

    localparam int XBITS = (ROWS > 1) ? $clog2(ROWS) : 1,
    localparam int YBITS = (COLS > 1) ? $clog2(COLS) : 1,
    localparam int GRID_BITS = (ROWS*COLS > 1) ? $clog2(ROWS*COLS) : 1,
    localparam int LANE_BITS = (LANES > 1) ? $clog2(LANES) : 1,
    localparam int DEPTH = (ROWS*COLS + LANES - 1) / LANES,
    localparam int ADDRW = (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
    input logic clk_ci, 
    input logic rst_ni, 

    input logic valid_i, 
    input logic [XBITS-1:0] I_i, 
    input logic [YBITS-1:0] J_i, 
    input logic rd_valid_i, 
    input logic signed [LANES*N-1:0] rd_data_i,

    output logic ready_o, 
    output logic rd_en_o, 
    output logic [ADDRW-1:0] rd_addr_o,
    output logic valid_o,
    output logic signed [N-1:0] Ax_o,
    output logic [XBITS-1:0] I_o, 
    output logic [YBITS-1:0] J_o,
    output logic overflow_o
);
    logic [XBITS-1:0] I_q;
    logic [YBITS-1:0] J_q;
    logic busy_q;
    logic ready_fetch;
    logic done_fetch;
    logic valid_stencil;
    logic signed [N-1:0] x_center, x_north, x_south, x_west, x_east;

    assign ready_o = ready_fetch && !busy_q;
    assign valid_o = valid_stencil;
    assign I_o = I_q;
    assign J_o = J_q;

    always_ff @(posedge clk_ci, negedge rst_ni) begin
        if (!rst_ni) begin
            busy_q <= 1'b0;
            I_q <= '0;
            J_q <= '0;
        end else begin
            if (valid_i && ready_o) begin
                busy_q <= 1'b1;
                I_q <= I_i;
                J_q <= J_i;
            end else if (valid_stencil) begin
                busy_q <= 1'b0;
            end
        end
    end

    stencil_neighborhood_fetch #(
        .N(N), .ROWS(ROWS), .COLS(COLS), .LANES(LANES)) poisson_engine_fetch (
        .clk_ci, 
        .rst_ni, 
        .valid_i(valid_i && ready_o),
        .I_i(I_i), .J_i(J_i), 
        .rd_valid_i(rd_valid_i), 
        .rd_data_i(rd_data_i),
        .ready_o(ready_fetch), 
        .rd_en_o(rd_en_o), 
        .rd_addr_o(rd_addr_o),
        .valid_o(),
        .center_o(x_center),
        .north_o(x_north),
        .south_o(x_south),
        .west_o(x_west),
        .east_o(x_east),
        .done_o(done_fetch)
    );

    poisson_stencil #(.N(N), .F(F)) poisson_engine_stencil (
        .clk_ci,
        .rst_ni,

        .valid_i(done_fetch),
        .x_center_i(x_center),
        .x_north_i(x_north),
        .x_south_i(x_south),
        .x_west_i(x_west),
        .x_east_i(x_east),

        .valid_o(valid_stencil),
        .Ax_o(Ax_o),
        .overflow_o(overflow_o)
    );

endmodule
