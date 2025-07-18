`timescale 1ns / 1ps

module MedFilt_3x3 #(
    parameter int DATA_WIDTH = 8,
    parameter int FRAME_WIDTH = 640,
    parameter int FRAME_HEIGHT = 512
) (
    input logic                       clk,
    input logic                       rst_n,
    AxiStreamIf.Slave s_axis,
    AxiStreamIf.Master m_axis
);
    localparam int WINDOW_SIZE = 3;
    localparam int LINEBUF_DEPTH = FRAME_WIDTH;
    localparam int WIDTH_WIDTH = $clog2(FRAME_WIDTH);
    localparam int HEIGHT_WIDTH = $clog2(FRAME_HEIGHT);

    localparam int LATENCY_LINEBUF = (WINDOW_SIZE - 1) * LINEBUF_DEPTH;
    localparam int LATENCY_GET_WINDOW = WINDOW_SIZE - 1;
    localparam int LATENCY_PADDING_STAGE_1 = 1;
    localparam int LATENCY_PADDING_STAGE_2 = 1;
    localparam int LATENCY_TO_PADDING_STAGE_1 = LATENCY_LINEBUF + LATENCY_GET_WINDOW;
    localparam int LATENCY_TO_PADDING_STAGE_2 = LATENCY_TO_PADDING_STAGE_1 + LATENCY_PADDING_STAGE_1;
    localparam int LATENCY_COMPARE_ROW = 3;
    localparam int LATENCT_COMPARE_STAGE_1 = LATENCY_COMPARE_ROW;
    localparam int LATENCT_COMPARE_STAGE_2 = LATENCY_COMPARE_ROW;
    localparam int LATENCT_COMPARE_STAGE_3 = 2;
    localparam int LATENCY_COMPARE = LATENCT_COMPARE_STAGE_1 + LATENCT_COMPARE_STAGE_2 + LATENCT_COMPARE_STAGE_3;
    localparam int LATENCY_TOTAL = LATENCY_TO_PADDING_STAGE_2 + LATENCY_COMPARE;
    // -------------------------- sync  ------------------------- //
    logic [WIDTH_WIDTH-1:0] in_hcnt;
    logic [HEIGHT_WIDTH-1:0] in_vcnt;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            in_hcnt <= 0;
            in_vcnt <= 0;
        end else begin
            if (s_axis.tvalid && s_axis.tready) begin
                if (in_hcnt == FRAME_WIDTH - 1) begin
                    in_hcnt <= 0;
                    if (in_vcnt == FRAME_HEIGHT - 1) begin
                        in_vcnt <= 0;
                    end else begin
                        in_vcnt <= in_vcnt + 1;
                    end
                end else begin
                    in_hcnt <= in_hcnt + 1;
                end
            end
        end
    end
    
    logic is_first_column_r, is_last_column_r, is_second_column_r, is_second_last_column_r;
    logic is_first_row_r2, is_last_row_r2, is_second_row_r2, is_second_last_row_r2;
    logic is_normal_column_r, is_normal_row_r2;
    logic is_normal_column_r_0, is_normal_column_r_1;
    logic is_normal_row_r2_0, is_normal_row_r2_1;

    logic [WIDTH_WIDTH-1:0] in_hcnt_r;
    logic [HEIGHT_WIDTH-1:0] in_vcnt_r2;

    LineBuf #(
        .DATA_WIDTH(WIDTH_WIDTH),
        .LATENCY(LATENCY_TO_PADDING_STAGE_1)
    ) linebuf_in_hcnt_r_inst (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(s_axis.tvalid),
        .data_in(in_hcnt),
        .data_out(in_hcnt_r)
    );
    
    LineBuf #(
        .DATA_WIDTH(HEIGHT_WIDTH),
        .LATENCY(LATENCY_TO_PADDING_STAGE_2)
    ) linebuf_in_vcnt_r_inst (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(s_axis.tvalid),
        .data_in(in_vcnt),
        .data_out(in_vcnt_r2)
    );

    assign is_first_column_r = (in_hcnt_r == 0);
    assign is_last_column_r = (in_hcnt_r == FRAME_WIDTH - 1);
    assign is_second_column_r = (in_hcnt_r == 1);
    assign is_second_last_column_r = (in_hcnt_r == FRAME_WIDTH - 2);
    assign is_first_row_r2 = (in_vcnt_r2 == 0);
    assign is_last_row_r2 = (in_vcnt_r2 == FRAME_HEIGHT - 1);
    assign is_second_row_r2 = (in_vcnt_r2 == 1);
    assign is_second_last_row_r2 = (in_vcnt_r2 == FRAME_HEIGHT - 2);
    assign is_normal_column_r_0 = !is_first_column_r && !is_last_column_r;
    assign is_normal_column_r_1 = !is_second_column_r && !is_second_last_column_r;
    assign is_normal_column_r = is_normal_column_r_0 && is_normal_column_r_1;
    assign is_normal_row_r2_0 = !is_first_row_r2 && !is_last_row_r2;
    assign is_normal_row_r2_1 = !is_second_row_r2 && !is_second_last_row_r2;
    assign is_normal_row_r2 = is_normal_row_r2_0 && is_normal_row_r2_1;

    localparam int LATENCY_DELAY_CNT = LATENCY_TOTAL;
    localparam int LATENCY_DELAY_CNT_WIDTH = $log2(LATENCY_DELAY_CNT);
    
    logic   [LATENCY_DELAY_CNT_WIDTH-1:0] delay_cnt;
    logic   delayed;
    logic   s_fire, m_fire;

    assign s_fire = s_axis.tvalid && s_axis.tready;
    assign m_fire = m_axis_tvalid && m_axis_tready;
    assign delayed = (delay_cnt >= LATENCY_DELAY_CNT - 1);
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            delay_cnt <= 'd0;
        end
        else begin
            if (s_fire) begin
                if (delay_cnt < LATENCY_TOTAL) begin
                    delay_cnt <= delay_cnt + 'd1;
                end
            end
        end
    end

    
    logic [WIDTH_WIDTH-1:0] out_hcnt;
    logic [HEIGHT_WIDTH-1:0] out_vcnt;
    always_ff @(posedge clk) begin : output_counter
        if (!rst_n) begin
            out_hcnt <= 'd0;
            out_vcnt <= 'd0;
        end
        else if (m_fire) begin
            if (out_hcnt < FRAME_WIDTH - 1) begin
                out_hcnt <= out_hcnt + 'd1;
            end
            else begin
                out_hcnt <= 'd0;
                if (out_vcnt < FRAME_HEIGHT - 1) begin
                    out_vcnt <= out_vcnt + 'd1;
                end
                else begin
                    out_vcnt <= 'd0;
                end
            end
        end
    end

    assign m_axis_tvalid = delayed && s_fire;
    assign m_axis_tlast = m_fire && (out_hcnt == FRAME_WIDTH - 1);
    assign m_axis_tuser = m_fire && (out_hcnt == 0) && (out_vcnt == 0);
    assign s_axis_tready = m_axis_tready;

    // -------------------------- sync end ------------------------- //

    logic [DATA_WIDTH-1:0] linebuf_r [0:WINDOW_SIZE-1];
    assign linebuf_r[0] = s_axis.tdata; 
    generate
        for (genvar i = 0; i < WINDOW_SIZE - 1; i++) begin : gen_linebufs
            LineBuf #(
                .DATA_WIDTH(DATA_WIDTH),
                .LATENCY(LINEBUF_DEPTH)
            ) linebuf_inst (
                .clk(clk),
                .rst_n(rst_n),
                .in_valid(s_axis.tvalid),
                .data_in(linebuf_r[i]),
                .data_out(linebuf_r[i + 1])
            );
        end
    endgenerate
    logic [DATA_WIDTH-1:0] GetWindow_in [0:WINDOW_SIZE-1];
    assign GetWindow_in[0] = linebuf_r[0];
    assign GetWindow_in[1] = linebuf_r[1];
    assign GetWindow_in[2] = linebuf_r[2];


    logic [DATA_WIDTH-1:0] w11_p0, w12_p0, w13_p0, w21_p0, w22_p0, w23_p0, w31_p0, w32_p0, w33_p0;

    GetWindow_3x3 #(
        .DATA_WIDTH(DATA_WIDTH),
        .WINDOW_SIZE(WINDOW_SIZE)
    ) get_window_inst (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(GetWindow_in),
        .w11(w11_p0),
        .w12(w12_p0),
        .w13(w13_p0),
        .w21(w21_p0),
        .w22(w22_p0),
        .w23(w23_p0),
        .w31(w31_p0),
        .w32(w32_p0),
        .w33(w33_p0)
    );

    // padding stage 1
    logic [DATA_WIDTH-1:0] w11_p1, w12_p1, w13_p1, w21_p1, w22_p1, w23_p1, w31_p1, w32_p1, w33_p1;
    always_ff @(posedge clk) begin
        if (is_first_column_r) begin
            w11_p1 <= w13_p0;
            w12_p1 <= w13_p0;
            w13_p1 <= w13_p0;
            w21_p1 <= w23_p0;
            w22_p1 <= w23_p0;
            w23_p1 <= w23_p0;
            w31_p1 <= w33_p0;
            w32_p1 <= w33_p0;
            w33_p1 <= w33_p0;
        end 
        if (is_last_column_r) begin
            w11_p1 <= w11_p0;
            w12_p1 <= w11_p0;
            w13_p1 <= w11_p0;
            w21_p1 <= w21_p0;
            w22_p1 <= w21_p0;
            w23_p1 <= w21_p0;
            w31_p1 <= w31_p0;
            w32_p1 <= w31_p0;
            w33_p1 <= w31_p0;
        end 
        if (is_second_column_r) begin
            w11_p1 <= w12_p0;
            w12_p1 <= w12_p0;
            w13_p1 <= w13_p0;
            w21_p1 <= w22_p0;
            w22_p1 <= w22_p0;
            w23_p1 <= w23_p0;
            w31_p1 <= w32_p0;
            w32_p1 <= w32_p0;
            w33_p1 <= w33_p0;
        end
        if (is_second_last_column_r) begin
            w11_p1 <= w11_p0;
            w12_p1 <= w12_p0;
            w13_p1 <= w12_p0;
            w21_p1 <= w21_p0;
            w22_p1 <= w22_p0;
            w23_p1 <= w22_p0;
            w31_p1 <= w31_p0;
            w32_p1 <= w32_p0;
            w33_p1 <= w32_p0;
        end
        if (!is_first_column_r && !is_last_column_r && !is_second_column_r && !is_second_last_column_r) begin
            w11_p1 <= w11_p0;
            w12_p1 <= w12_p0;
            w13_p1 <= w13_p0;
            w21_p1 <= w21_p0;
            w22_p1 <= w22_p0;
            w23_p1 <= w23_p0;
            w31_p1 <= w31_p0;
            w32_p1 <= w32_p0;
            w33_p1 <= w33_p0;
        end
    end

    // padding stage 2
    logic [DATA_WIDTH-1:0] w11, w12, w13, w21, w22, w23, w31, w32, w33;
    always_ff @(posedge clk) begin
        if (is_first_row_r2) begin
            w11 <= w31_p1;
            w12 <= w32_p1;
            w13 <= w33_p1;
            w21 <= w31_p1;
            w22 <= w32_p1;
            w23 <= w33_p1;
            w31 <= w31_p1;
            w32 <= w32_p1;
            w33 <= w33_p1;
        end
        if (is_last_row_r2) begin
            w11 <= w11_p1;
            w12 <= w12_p1;
            w13 <= w13_p1;
            w21 <= w11_p1;
            w22 <= w12_p1;
            w23 <= w13_p1;
            w31 <= w11_p1;
            w32 <= w12_p1;
            w33 <= w13_p1;
        end
        if (is_second_row_r2) begin
            w11 <= w21_p1;
            w12 <= w22_p1;
            w13 <= w23_p1;
            w21 <= w21_p1;
            w22 <= w22_p1;
            w23 <= w23_p1;
            w31 <= w31_p1;
            w32 <= w32_p1;
            w33 <= w33_p1;
        end
        if (is_second_last_row_r2) begin
            w11 <= w11_p1;
            w12 <= w12_p1;
            w13 <= w13_p1;
            w21 <= w21_p1;
            w22 <= w22_p1;
            w23 <= w23_p1;
            w31 <= w21_p1;
            w32 <= w22_p1;
            w33 <= w23_p1;
        end
        if (!is_first_row_r2 && !is_last_row_r2 && !is_second_row_r2 && !is_second_last_row_r2) begin
            w11 <= w11_p1;
            w12 <= w12_p1;
            w13 <= w13_p1;
            w21 <= w21_p1;
            w22 <= w22_p1;
            w23 <= w23_p1;
            w31 <= w31_p1;
            w32 <= w32_p1;
            w33 <= w33_p1;
        end
    end
    
    // ------------------------------ compare ------------------------------------ //
    
    // stage 1
    logic   [DATA_WIDTH-1:0] Med1, Med2, Med3, Min1, Min2, Min3, Max1, Max2, Max3;
    
    CompareRow #(
        .DATA_WIDTH  	(DATA_WIDTH  ),
        .WINDOW_SIZE 	(WINDOW_SIZE  ))
    u_CompareRow_1(
        .clk   	(clk    ),
        .rst_n 	(rst_n  ),
        .w1    	(w11     ),
        .w2    	(w12     ),
        .w3    	(w13     ),
        .min   	(Min1    ),
        .med   	(Med1    ),
        .max   	(Max1    )
    );
    CompareRow #(
        .DATA_WIDTH  	(DATA_WIDTH  ),
        .WINDOW_SIZE 	(WINDOW_SIZE  ))
    u_CompareRow_2(
        .clk   	(clk    ),
        .rst_n 	(rst_n  ),
        .w1    	(w21     ),
        .w2    	(w22     ),
        .w3    	(w23     ),
        .min   	(Min2    ),
        .med   	(Med2    ),
        .max   	(Max2    )
    );
    CompareRow #(
        .DATA_WIDTH  	(DATA_WIDTH  ),
        .WINDOW_SIZE 	(WINDOW_SIZE  ))
    u_CompareRow_3(
        .clk   	(clk    ),
        .rst_n 	(rst_n  ),
        .w1    	(w31     ),
        .w2    	(w32     ),
        .w3    	(w33     ),
        .min   	(Min3    ),
        .med   	(Med3    ),
        .max   	(Max3    )
    );

    // stage 2
    logic   [DATA_WIDTH-1:0] Medmed, Maxmin, Minmax;
    
    logic   [DATA_WIDTH-1:0] Maxmin_0, Minmax_0;
    logic   [DATA_WIDTH-1:0] max_maxmin, min_maxmin;
    always_ff @(posedge clk) begin
        Maxmin_0 <= (Max1 > Max2) ? Max2 : Max1;
        Minmax_0 <= (Min1 > Min2) ? Min1 : Min2;

        Maxmin <= (Maxmin_0 > Max3) ? Max3 : Maxmin_0;
        Minmax <= (Minmax_0 > Min3) ? Minmax_0 : Min3;

        max_maxmin <= (Maxmin > Minmax) ? Maxmin : Minmax;
        min_maxmin <= (Maxmin > Minmax) ? Minmax : Maxmin;
    end

    CompareRow #(
        .DATA_WIDTH  	(DATA_WIDTH  ),
        .WINDOW_SIZE 	(WINDOW_SIZE  ))
    u_CompareRow_3(
        .clk   	(clk    ),
        .rst_n 	(rst_n  ),
        .w1    	(Med1     ),
        .w2    	(Med2     ),
        .w3    	(Med3     ),
        .min   	(    ),
        .med   	(Medmed    ),
        .max   	(    )
    );

    // stage 3
    logic   [DATA_WIDTH-1:0] min_maxmin_r, min_max_Medmed;
    logic   [DATA_WIDTH-1:0] med_value;
    always_ff @(posedge clk) begin
        min_maxmin_r <= min_maxmin;
        min_max_Medmed <= (max_maxmin > Medmed) ? Medmed : max_maxmin;

        med_value <= (min_max_Medmed > min_maxmin_r) ? min_max_Medmed : min_maxmin_r;
    end

    assign  m_axis.tdata = med_value;

endmodule

