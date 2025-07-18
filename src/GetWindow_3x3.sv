module GetWindow_3x3 #(
    parameter int DATA_WIDTH = 8,
    parameter int WINDOW_SIZE = 3
) (
    input logic                       clk,
    input logic                       rst_n,
    input logic [DATA_WIDTH-1:0]      data_in [0:WINDOW_SIZE-1],
    output logic [DATA_WIDTH-1:0]     w11,
    output logic [DATA_WIDTH-1:0]     w12,
    output logic [DATA_WIDTH-1:0]     w13,
    output logic [DATA_WIDTH-1:0]     w21,
    output logic [DATA_WIDTH-1:0]     w22,
    output logic [DATA_WIDTH-1:0]     w23,
    output logic [DATA_WIDTH-1:0]     w31,
    output logic [DATA_WIDTH-1:0]     w32,
    output logic [DATA_WIDTH-1:0]     w33
);

    logic [DATA_WIDTH-1:0] data_in_r [0:WINDOW_SIZE-1][0:WINDOW_SIZE-1];
    always_ff @(posedge clk ) begin
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            for (int j = 0; j < WINDOW_SIZE-1; j++) begin
                data_in_r[i][j] <= data_in_r[i][j+1];
            end
            data_in_r[i][WINDOW_SIZE-1] <= data_in[i];
        end
    end

    assign w11 = data_in_r[0][0];
    assign w12 = data_in_r[0][1];
    assign w13 = data_in_r[0][2];
    assign w21 = data_in_r[1][0];
    assign w22 = data_in_r[1][1];
    assign w23 = data_in_r[1][2];
    assign w31 = data_in_r[2][0];
    assign w32 = data_in_r[2][1];
    assign w33 = data_in_r[2][2];

endmodule