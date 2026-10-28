/** POISSON STENCIL NEIGHBORHOOD FETCHER
* Fetches the center and four neighbors from a packed, row-major field.
* LANES must be a power of two and at least two; NX must be divisible by
* LANES so north/south neighbors occupy the same lane as the center.
* A request is accepted when valid_i and ready_o are high at a rising edge.
* Each memory read is a one-cycle rd_en_o pulse; rd_valid_i identifies its
* response. done_o pulses with the five outputs, while valid_o remains high
* until the next request is accepted.
*/
module stencil_neighborhood_fetch #(
    parameter int N = 32,
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

    input logic valid_i, 
    input logic [XBITS-1:0] I_i, 
    input logic [YBITS-1:0] J_i, 
    input logic rd_valid_i, 
    input logic signed [LANES*N-1:0] rd_data_i,

    output logic ready_o, 
    output logic rd_en_o, 
    output logic [ADDRW-1:0] rd_addr_o,
    output logic valid_o,
    output logic signed [N-1:0] center_o,
    output logic signed [N-1:0] north_o,
    output logic signed [N-1:0] south_o,
    output logic signed [N-1:0] west_o,
    output logic signed [N-1:0] east_o,
    output logic done_o
);
    localparam logic [LANE_BITS-1:0] LAST_LANE = LANE_BITS'(LANES-1);

    typedef enum logic [1:0] { 
        IDLE, RQST, RECV, DONE
    } state_t;

    typedef enum logic [2:0] {
        CENTER, NORTH, SOUTH, WEST, EAST
    } point_t;

    state_t state;
    point_t point, point_rd;
    logic bndN, bndS, bndW, bndE;

    logic [GRID_BITS-1:0] idx;
    logic [ADDRW-1:0] mem_addr_q;
    logic [LANE_BITS-1:0] mem_idx_q;
    logic [XBITS-1:0] I_q;
    logic [YBITS-1:0] J_q;
    logic signed [N-1:0] center_q, north_q, south_q, west_q, east_q;

    always_ff @(posedge clk_ci, negedge rst_ni) begin
        if (!rst_ni) begin
            ready_o <= 1'b1;
            rd_en_o <= 1'b0;
            rd_addr_o <= '0;
            valid_o <= 1'b0;
            done_o <= 1'b0;
            center_o <= 0;
            north_o <= 0;
            south_o <= 0;
            west_o <= 0;
            east_o <= 0;
            
            state <= IDLE;
            point <= CENTER;
            point_rd <= CENTER;

            I_q <= 0;
            J_q <= 0;
            center_q <= 0;
            north_q <= 0;
            south_q <= 0;
            west_q <= 0;
            east_q <= 0;

        end else begin
            done_o <= 1'b0;
            rd_en_o <= 1'b0;

            case (state)
                IDLE: begin
                    if (valid_i && ready_o) begin
                        I_q <= I_i;
                        J_q <= J_i;

                        ready_o <= 1'b0;
                        valid_o <= 1'b0;
                        state <= RQST;
                        point <= CENTER;
                    end
                end
                RQST: begin
                    rd_en_o <= 1'b1;
                    state <= RECV;
                    point_rd <= point;
                    
                    case (point)
                        CENTER: rd_addr_o <= mem_addr_q;
                        NORTH: rd_addr_o <= mem_addr_q - ADDRW'(NX/LANES);
                        SOUTH: rd_addr_o <= mem_addr_q + ADDRW'(NX/LANES);
                        EAST: rd_addr_o <= mem_addr_q + 1;
                        WEST: rd_addr_o <= mem_addr_q - 1;
                    endcase
                end
                RECV: begin
                    if (rd_valid_i) begin

                        if (bndN) north_q <= 0;
                        if (bndS) south_q <= 0;
                        if (bndW) west_q <= 0;
                        if (bndE) east_q <= 0;

                        case (point_rd)
                            CENTER: begin
                                case (mem_idx_q)
                                    0:  begin
                                        center_q <= rd_data_i[mem_idx_q*N +: N];
                                        east_q <= rd_data_i[(int'(mem_idx_q)+1)*N +: N];
                                        point <= (!bndW) ? WEST : ((!bndN) ? NORTH : SOUTH);
                                    end
                                    LAST_LANE: begin
                                        center_q <= rd_data_i[mem_idx_q*N +: N];
                                        west_q <= rd_data_i[(int'(mem_idx_q)-1)*N +: N];
                                        point <= (!bndE) ? EAST : ((!bndN) ? NORTH : SOUTH);
                                    end
                                    default: begin
                                        center_q <= rd_data_i[mem_idx_q*N +: N];
                                        east_q <= rd_data_i[(int'(mem_idx_q)+1)*N +: N];
                                        west_q <= rd_data_i[(int'(mem_idx_q)-1)*N +: N];
                                        point <= (!bndN) ? NORTH : SOUTH;
                                    end
                                endcase
                                state <= RQST;
                            end
                            NORTH: begin
                                north_q <= rd_data_i[mem_idx_q*N +: N];
                                if (!bndS) begin
                                    point <= SOUTH;
                                    state <= RQST;
                                end else begin 
                                    point <= CENTER;
                                    state <= DONE;
                                end
                            end
                            SOUTH: begin
                                south_q <= rd_data_i[mem_idx_q*N +: N];
                                point <= CENTER;
                                state <= DONE;
                            end
                            WEST: begin
                                west_q <= rd_data_i[(LANES-1)*N +: N];
                                point <= (!bndN) ? NORTH : SOUTH;
                                state <= RQST;
                            end
                            EAST: begin
                                east_q <= rd_data_i[0 +: N];
                                point <= (!bndN) ? NORTH : SOUTH;
                                state <= RQST;
                            end
                        endcase
                    end
                end
                DONE: begin
                    state <= IDLE;
                    done_o <= 1'b1;
                    valid_o <= 1'b1;
                    ready_o <= 1'b1;

                    center_o <= center_q;
                    north_o <= north_q;
                    south_o <= south_q;
                    west_o <= west_q;
                    east_o <= east_q;
                end
            endcase
        end
    end

    always_comb begin
        idx = GRID_BITS'(I_q) + GRID_BITS'(NX) * GRID_BITS'(J_q);
        mem_addr_q = ADDRW'(idx >> LANE_BITS);
        mem_idx_q = LANE_BITS'(idx);

        bndN = (J_q == 0);
        bndS = (J_q == YBITS'(NY-1));
        bndW = (I_q == 0);
        bndE = (I_q == XBITS'(NX-1));
    end

endmodule
