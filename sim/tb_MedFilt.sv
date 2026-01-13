`timescale 1ns / 1ps

module tb_MedFilt();

    // 参数定义
    parameter DATA_WIDTH = 8;
    parameter WINDOW_SIZE = 3;
    parameter FRAME_WIDTH = 20;
    parameter FRAME_HEIGHT = 20;
    parameter CLK_PERIOD = 10;  // 10ns = 100MHz
    
    // 信号定义
    logic clk;
    logic rst_n;

    // Slave AXI Stream signals
    logic                      s_axis_tvalid;
    logic                      s_axis_tready;
    logic [DATA_WIDTH-1:0]     s_axis_tdata;
    logic                      s_axis_tlast;
    logic                      s_axis_tuser;

    // Master AXI Stream signals
    logic                      m_axis_tvalid;
    logic                      m_axis_tready;
    logic [DATA_WIDTH-1:0]     m_axis_tdata;
    logic                      m_axis_tlast;
    logic                      m_axis_tuser;

    // 时钟生成
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // 复位生成
    initial begin
        rst_n = 0;
        #(CLK_PERIOD*2);
        rst_n = 1;
    end
    
    // 实例化待测试模块
    MedFilt_3x3 #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAME_WIDTH(FRAME_WIDTH),
        .FRAME_HEIGHT(FRAME_HEIGHT)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tuser(s_axis_tuser),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tuser(m_axis_tuser)
    );

    // 帧缓存与期望输出
    logic [DATA_WIDTH-1:0] frame      [0:FRAME_HEIGHT-1][0:FRAME_WIDTH-1];
    logic [DATA_WIDTH-1:0] golden     [0:FRAME_HEIGHT-1][0:FRAME_WIDTH-1];

    // 计数与统计
    int out_row;
    int out_col;
    int mismatch_cnt;

    function automatic int clamp_int(int val, int lo, int hi);
        if (val < lo) return lo;
        else if (val > hi) return hi;
        else return val;
    endfunction

    function automatic logic [DATA_WIDTH-1:0] calc_median_at(int r, int c);
        logic [DATA_WIDTH-1:0] window[0:8];
        logic [DATA_WIDTH-1:0] tmp;
        int idx = 0;
        // 收集窗口数据
        for (int dr = -1; dr <= 1; dr++) begin
            for (int dc = -1; dc <= 1; dc++) begin
                int rr = clamp_int(r + dr, 0, FRAME_HEIGHT - 1);
                int cc = clamp_int(c + dc, 0, FRAME_WIDTH - 1);
                window[idx] = frame[rr][cc];
                idx++;
            end
        end
        // 冒泡排序找中值
        for (int i = 0; i < 9; i++) begin
            for (int j = i + 1; j < 9; j++) begin
                if (window[j] < window[i]) begin
                    tmp = window[i];
                    window[i] = window[j];
                    window[j] = tmp;
                end
            end
        end
        return window[4];
    endfunction

    task automatic build_random_frame();
        for (int row = 0; row < FRAME_HEIGHT; row++) begin
            for (int col = 0; col < FRAME_WIDTH; col++) begin
                frame[row][col] = $urandom_range((1 << DATA_WIDTH) - 1, 0);
            end
        end
    endtask

    task automatic build_golden_frame();
        for (int row = 0; row < FRAME_HEIGHT; row++) begin
            for (int col = 0; col < FRAME_WIDTH; col++) begin
                golden[row][col] = calc_median_at(row, col);
            end
        end
    endtask
    
    // 测试激励
    initial begin
        $dumpfile("tb_MedFilt.vcd");
        $dumpvars(0, tb_MedFilt);
        
        // 初始化信号
        s_axis_tdata  = 0;
        s_axis_tvalid = 0;
        s_axis_tlast = 0;
        s_axis_tuser = 0;
        m_axis_tready = 1;
        out_row = 0;
        out_col = 0;
        mismatch_cnt = 0;
        build_random_frame();
        build_golden_frame();
        
        // 等待复位完成
        wait(rst_n);
        #(CLK_PERIOD*10);
        
        // 开始测试
        $display("Starting MedFilt_3x3 test...");
        
        // 发送一帧测试数据
        send_frame();
        
        // 等待处理完成
        #(CLK_PERIOD*1000);
        
        $display("Test completed! mismatches=%0d", mismatch_cnt);
        $finish;
    end
    
    // 发送一帧数据的任务
    task send_frame();
        integer row, col;
        for (row = 0; row < FRAME_HEIGHT; row++) begin
            for (col = 0; col < FRAME_WIDTH; col++) begin
                // 发送数据
                @(posedge clk);
                s_axis_tdata = frame[row][col];
                s_axis_tvalid = 1;
                s_axis_tlast = (col == FRAME_WIDTH - 1);
                s_axis_tuser = (row == 0 && col == 0);
                
                // 等待握手
                while (!s_axis_tready) @(posedge clk);
            end
        end
        
        // 结束传输
        @(posedge clk);
        s_axis_tvalid = 0;
        s_axis_tlast = 0;
        s_axis_tuser = 0;
    endtask
    
    // 监控输出
    always @(posedge clk) begin
        if (!rst_n) begin
            out_row <= 0;
            out_col <= 0;
            mismatch_cnt <= 0;
        end else if (m_axis_tvalid && m_axis_tready) begin
            if (m_axis_tdata !== golden[out_row][out_col]) begin
                mismatch_cnt <= mismatch_cnt + 1;
                $display("Mismatch at (%0d,%0d): got %0d expect %0d @ %0t", out_row, out_col, m_axis_tdata, golden[out_row][out_col], $time);
            end
            if (out_col == FRAME_WIDTH - 1) begin
                out_col <= 0;
                if (out_row == FRAME_HEIGHT - 1) begin
                    out_row <= 0;
                end else begin
                    out_row <= out_row + 1;
                end
            end else begin
                out_col <= out_col + 1;
            end
        end
    end
    
endmodule