/** POISSON STENCIL PASS
* walks (i,j), sends each request to poisson_stencil_engine, and waits for its result.
* Writes each result to a separate Ap memory and pulse done after the final write. 
*/
module poisson_stencil_pass #(
    parameter int N = 32,
    parameter int F = 24,
    parameter int NX = 32,
    parameter int NY = 32,
    parameter int LANES = 4,

    localparam int XBITS = (NX > 1) ? $clog2(NX) : 1,
    localparam int YBITS = (NY > 1) ? $clog2(NY) : 1,
    localparam int GRID_BITS = (NX*NY > 1) ? $clog2(NX*NY) : 1,
    localparam int LANE_BITS = (LANES > 1) ? $clog2(LANES) : 1,
    localparam int DEPTH = (NX*NY + LANES - 1) / LANES,
    localparam int ADDRW = (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
    input logic clk_ci, 
    input logic rst_ni, 

    input logic start_i, 
    input logic rd_valid_i, 
    input logic signed [LANES*N-1:0] rd_data_i,

    output logic ready_o, 
    output logic rd_en_o, 
    output logic [ADDRW-1:0] rd_addr_o, 
    output logic wr_en_o,
    output logic [ADDRW-1:0] wr_addr_o,
    output logic signed [LANES*N-1:0] wr_data_o,  
    output logic overflow_o,
    output logic busy_o,
    output logic done_o
);
    typedef enum logic [2:0] {
        IDLE, BUSY, WRITE, DONE
    } state_t;

    state_t state;
    logic [XBITS-1:0] I_q, I_d, I_engine;
    logic [YBITS-1:0] J_q, J_d, J_engine;
    logic [GRID_BITS-1:0] idx;
    logic [ADDRW-1:0] mem_addr_q;
    logic [ADDRW-1:0] wr_addr_q;
    logic [LANE_BITS-1:0] mem_idx_q;
    logic signed [LANES*N-1:0] wr_data_q;
    logic overflow_q; 

    logic engine_i_valid;
    logic engine_ready;
    logic engine_o_valid;
    logic engine_overflow;
    logic signed [N-1:0] engine_o_data;

    logic last;

    always_ff @(posedge clk_ci, negedge rst_ni) begin
        if (!rst_ni) begin
            ready_o <= 1'b1;
            wr_en_o <= 1'b0;
            busy_o <= 1'b0;
            done_o <= 1'b0;
            wr_addr_o <= 0;
            wr_data_o <= 0;
            overflow_o <= 1'b0;

            I_q <= 0;
            J_q <= 0;
            wr_data_q <= 0;
            wr_addr_q <= 0;
            overflow_q <= 1'b0;

            engine_i_valid <= 1'b0; 
            state <= IDLE;

        end else begin

            done_o <= 1'b0;
            engine_i_valid <= 1'b0;
            wr_en_o <= 1'b0;

            case (state)
                IDLE: begin
                    if(start_i && ready_o) begin
                        ready_o <= 1'b0;
                        busy_o <= 1'b1;
                        I_q <= 0;
                        J_q <= 0;

                        wr_data_q <= 0;
                        engine_i_valid <= 1'b1;
                        overflow_q <= 1'b0;

                        state <= BUSY;
                    end
                end
                BUSY: begin
                    if (engine_o_valid) begin
                        wr_data_q[mem_idx_q*N +: N] <= engine_o_data;
                        I_q <= I_d; 
                        J_q <= J_d;
                        overflow_q <= overflow_q || engine_overflow; 
                        if (!last) engine_i_valid <= 1'b1;

                        if (mem_idx_q == LANES-1) begin
                            wr_addr_q <= mem_addr_q;
                            state <= WRITE;
                        end 
                    end
                end
                WRITE: begin
                    wr_en_o <= 1'b1;
                    wr_addr_o <= wr_addr_q;
                    wr_data_o <= wr_data_q;
                    state <= (wr_addr_q == DEPTH-1) ? DONE : BUSY;
                end
                DONE: begin
                    state <= IDLE;
                    ready_o <= engine_ready;
                    overflow_o <= overflow_q;
                    busy_o <= 1'b0;
                    done_o <= 1'b1;
                end
            endcase

        end
    end

    always_comb begin
        I_d = (I_q < NX-1) ? (I_q + 1) : 0;
        J_d = (I_q < NX-1) ? J_q : 
                ((J_q < NY-1) ? (J_q+1) : 0); 

        idx = GRID_BITS'(I_q) + GRID_BITS'(NX) * GRID_BITS'(J_q);
        mem_addr_q = ADDRW'(idx >> LANE_BITS);
        mem_idx_q = LANE_BITS'(idx);

        last = (mem_idx_q == LANES-1) && (mem_addr_q == DEPTH-1);  
    end

    poisson_stencil_engine #(
        .N(N), .F(F), .NX(NX), .NY(NY), .LANES(LANES)
    ) dut (
        .clk_ci, 
        .rst_ni, 
        .valid_i    (engine_i_valid), 
        .I_i        (I_q), 
        .J_i        (J_q),
        .rd_valid_i (rd_valid_i), 
        .rd_data_i  (rd_data_i),
        .ready_o    (engine_ready), 
        .rd_en_o    (rd_en_o), 
        .rd_addr_o  (rd_addr_o),
        .valid_o    (engine_o_valid), 
        .Ax_o       (engine_o_data), 
        .I_o        (I_engine), 
        .J_o        (J_engine), 
        .overflow_o (engine_overflow)
    );

endmodule