/** FIXED POINT DOT PRODUCT MODULE
* computes a := <x, y> = sum_{i=0}^{V-1} x[i] * y[i].
* The inputs are vectors of V signed fixed-point values, each with N total
* bits and F fractional bits.
* ARITHMETIC:
* - Each input is sign-extended to WIDE bits before multiplication.
* - Products retain 2F fractional bits and are accumulated without rescaling.
* - WIDE = 2*N + clog2(V).
* - The accumulator uses one additional guard bit for overflow detection.
* - On accumulator overflow, the result is saturated to the signed WIDE-bit
*   maximum or minimum and overflow_o is asserted.
* - No rounding is performed.
* INTERFACE:
* - A transaction is accepted when valid_i=1 while the module is idle.
* - Inputs are captured at the accepting rising clock edge.
* - valid_i must remain low until valid_o is asserted; inputs presented while
*   the module is busy are ignored.
* LATENCY: V+2 clock cycles, after valid_i=1 at the accepting rising edge.
* RESET: Asynchronous, active-low reset (on falling edge).
* VALIDITY: a_o and overflow_o are meaningful only when valid_o=1.
* OVERFLOW: Saturates to the corresponding bound for the active transaction; 
*   asserted when the accumulated result exceeds the signed WIDE-bit range. 
*   The accumulator saturates.
*/
module fxp_dot #(
    parameter int V = 256,  // vector size
    parameter int N = 32,   // total bits per element
    parameter int F = 24,   // fractional bits
    localparam WIDE = 2*N + $clog2(V)
) (
    input logic clk_ci,
    input logic rst_ni,

    input logic valid_i,
    input logic signed [V*N-1:0] x_i, y_i,

    output logic valid_o,
    output logic signed [WIDE-1:0] a_o,
    output logic overflow_o
);
    localparam int XWIDE = WIDE + 1; // One guard bit for accumulation overflow

    // Overflow bounds
    localparam logic signed [WIDE-1:0] MAX = {1'b0, {(WIDE-1){1'b1}}};
    localparam logic signed [WIDE-1:0] MIN = {1'b1, {(WIDE-1){1'b0}}};
    localparam logic signed [XWIDE-1:0] MAX_EXT = {MAX[WIDE-1], MAX};
    localparam logic signed [XWIDE-1:0] MIN_EXT = {MIN[WIDE-1], MIN};

    localparam int CW = $clog2(V + 1);  // number of bits to represent counter step
    localparam logic [CW-1:0] V_COUNT = CW'(V);
    localparam logic [CW-1:0] LAST_PAIR = CW'(V-1);

    // Controller
    logic busy_q;                   // whether any transaction is active
    logic [CW-1:0] step_q;          // next chunk to send into adder

    // Saved input operands
    logic signed [V*N-1:0] x_q, y_q;

    // Shared arithmetic datapath
    logic signed [N-1:0] x, y;
    logic signed [WIDE-1:0] mul_x_i, mul_y_i;
    logic signed [WIDE-1:0] raw_prod;

    // Wider product output and accumulator to check overflow
    logic signed [WIDE-1:0] mul_o;
    logic signed [XWIDE-1:0] raw_sum;
    logic signed [WIDE-1:0] accumulator;

    // Valid signals: one common control per stage
    logic mul_valid_i, mul_valid_o;
    logic add_valid_i, add_valid_o;

    // Pipeline metadata
    logic [CW-1:0] mul_pair_q;     // index of pair entering multiplier
    logic [CW-1:0] add_pair_q;     // index of product entering accumulator

    // Overflow
    logic overflow_q;

    // datapath scheduling
    always_comb begin : g_dot_next_state
        x = '0;
        y = '0;
        mul_x_i = '0;
        mul_y_i = '0;

        raw_sum = {{(XWIDE-WIDE){accumulator[WIDE-1]}}, accumulator}
                + {{(XWIDE-WIDE){mul_o[WIDE-1]}}, mul_o};
        raw_prod = '0;

        mul_valid_i = busy_q && (step_q < V_COUNT);
        add_valid_i = mul_valid_o;

        if (mul_valid_i) begin
            // extract factors
            x = x_q[step_q*N +:N];
            y = y_q[step_q*N +:N];
            // Widen the format of the factors
            mul_x_i = {{(WIDE-N){x[N-1]}}, x};
            mul_y_i = {{(WIDE-N){y[N-1]}}, y};
            raw_prod = mul_x_i * mul_y_i;
        end

    end

    // Multiplication register
    always_ff @(posedge clk_ci, negedge rst_ni) begin : dot_mul_reg
        if(!rst_ni) begin
            mul_o <= '0;
            mul_valid_o <= '0;
        end else begin
            mul_o <= raw_prod;
            mul_valid_o <= mul_valid_i;
        end
    end

    // Addition register
    always_ff @(posedge clk_ci, negedge rst_ni) begin : dot_add_reg
        if(!rst_ni) begin
            accumulator <= '0;
            overflow_q <= 1'b0;
            add_valid_o <= 1'b0;
        end else begin
            if (!busy_q && valid_i) begin
                accumulator <= '0;
                overflow_q <= 1'b0;
            end else if (add_valid_i) begin
                if (raw_sum > MAX_EXT) begin
                    overflow_q <= 1'b1;
                    accumulator <= MAX;
                end else if (raw_sum < MIN_EXT) begin
                    overflow_q <= 1'b1;
                    accumulator <= MIN;
                end else begin
                    accumulator <= raw_sum[WIDE-1:0];
                end
            end
            add_valid_o <= add_valid_i;
        end
    end

    // Controller and output registers
    always_ff @(posedge clk_ci, negedge rst_ni) begin : dot_reg
        if (!rst_ni) begin
            busy_q <= 1'b0;
            step_q <= '0;

            x_q <= '0;
            y_q <= '0;

            mul_pair_q <= '0;
            add_pair_q <= '0;

            a_o <= '0;
            valid_o <= 1'b0;

        end else begin
            valid_o <= 1'b0;

            if (!busy_q) begin
                if (valid_i) begin
                    // Start a new transaction
                    x_q <= x_i;
                    y_q <= y_i;

                    a_o <= '0;
                    step_q <= '0;
                    busy_q <= 1'b1;
                end
            end else begin
                // Advance the multiplication schedule
                if (step_q < V_COUNT)
                    step_q <= step_q + 1'b1;

                // Track which pair is being multiplied
                if (mul_valid_i)
                    mul_pair_q <= step_q;

                // Track which pair is entering the adder
                if (add_valid_i) 
                    add_pair_q <= mul_pair_q;

                // Output results
                if (add_valid_o && add_pair_q == LAST_PAIR) begin
                    valid_o <= 1'b1;
                    busy_q <= 1'b0;

                    if (raw_sum > MAX_EXT) begin
                        overflow_q <= 1'b1;
                        a_o <= MAX;
                    end else if (raw_sum < MIN_EXT) begin
                        overflow_q <= 1'b1;
                        a_o <= MIN;
                    end else begin
                        a_o <= raw_sum[WIDE-1:0];
                    end
                end
            end
        end
    end

    assign overflow_o = overflow_q;

endmodule
