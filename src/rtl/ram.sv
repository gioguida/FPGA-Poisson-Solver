/** RANDOM ACCESS MEMORY 
* Synchronous dual port Random Access Memory
* Each stored word holds LANES instances of WIDTH-bit data
* READ: a read request issued during clk cycle k with r_en_i=1
*   returns the data contained at adress r_addr_i on 
*   rising edge k+1 with r_valid_o=1
* WRITE: a write request with w_en_i=1 during clk cycle k
*   triggers a write of w_data_i at adress w_addr_i
*   on rising edge k+1
* SIMULTANEOUS WRITE AND READ: if during clk cycle k
*   both a valid read a valid write are requested at the
*   same memory adress, the read will return the value stored
*   before the write was requested, and the overwritten value
*   will be available from the next cycle onwards.
*   Reads and writes on different adresses are fully supported
*/
module ram #(
    parameter int WIDTH = 32,   // bits in each number
    parameter int DEPTH = 64,   // # words in array
    parameter int LANES = 4,    // numbers per word
    localparam WORDWIDTH = LANES * WIDTH,
    localparam ADDRW = $clog2(DEPTH)
) (
    input logic clk_ci,
    input logic rst_ni,  

    input logic r_en_i,
    input logic [ADDRW-1:0] r_addr_i,
    output logic r_valid_o,
    output logic [WORDWIDTH-1:0] r_data_o,

    input logic w_en_i,
    input logic [ADDRW-1:0] w_addr_i,
    input logic [WORDWIDTH-1:0] w_data_i
);
    logic [WORDWIDTH-1:0] mem [0:DEPTH-1];

    // sync read/write
    always_ff @(posedge clk_ci) begin
        if (!rst_ni) begin
            r_valid_o <= 1'b0;
            r_data_o <= '0;
        end else begin
            if (r_en_i) 
                r_data_o <= mem[r_addr_i];
            r_valid_o <= r_en_i;

            if (w_en_i) 
                mem[w_addr_i] <= w_data_i;                
        end
    end

endmodule
