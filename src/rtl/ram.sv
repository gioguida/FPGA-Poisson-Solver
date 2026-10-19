/** RANDOM ACCESS MEMORY 
* Synchronous dual port Random Access Memory
* Each stored word holds LANES instances of WIDTH-bit data
*/
module ram #(
    parameter int WIDTH = 32,   // bits in each number
    parameter int DEPTH = 64,   // # words in array
    parameter int LANES = 4,    // numbers per word
    localparam WORDWIDTH = LANES * WIDTH,
    localparam ADDRW = $clog2(DEPTH)
) (
    input logic clk_ci,

    input logic we_i,
    input logic [ADDRW-1:0] w_addr_i,
    input logic [WORDWIDTH-1:0] w_data_i,

    input logic [ADDRW-1:0] r_addr_i,
    output logic [WORDWIDTH-1:0] r_data_o
);
    logic [WORDWIDTH-1:0] mem [0:DEPTH-1];

    // sync read/write
    always_ff @(posedge clk_ci) begin
        if  (we_i)
            mem[w_addr_i] <= w_data_i;

        r_data_o <= mem[r_addr_i];
    end

endmodule