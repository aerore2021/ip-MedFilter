module CompareRow #(
    parameter int DATA_WIDTH = 8,
    parameter int WINDOW_SIZE = 3
) (
    input   clk,
    input   rst_n,
    input   [DATA_WIDTH-1:0] w1,
    input   [DATA_WIDTH-1:0] w2,
    input   [DATA_WIDTH-1:0] w3,
    output reg  [DATA_WIDTH-1:0] min,
    output reg [DATA_WIDTH-1:0] med,
    output reg [DATA_WIDTH-1:0] max
);

logic   [DATA_WIDTH-1:0] min_0, max_0, min_1, max_1, min_0_r;
logic   [DATA_WIDTH-1:0] w3_r;
always_ff @(posedge clk) begin
    min_0 <= (w1 > w2) ? w2 : w1;
    max_0 <= (w1 > w2) ? w1 : w2;
    w3_r <= w3;

    min_0_r <= min_0;
    min_1 <= (max_0 > w3_r) ? w3_r : max_0;
    max_1 <= (max_0 > w3_r) ? max_0 : w3_r;

    min <= (min_0_r > min_1) ? min_1 : min_0_r;
    med <= (min_0_r > min_1) ? min_0_r : min_1;
    max <= max_1;
end

endmodule