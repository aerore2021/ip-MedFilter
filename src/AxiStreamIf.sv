/*
* AxiStreamIf.sv
* Author: Aero2021
* Version: 2.0    
*/

`timescale 1ns / 1ps

interface AxiStreamIf #(
    parameter int DATA_WIDTH = 8,
    parameter int USER_WIDTH = 1,
    parameter int DEST_WIDTH = 1,
    parameter int ID_WIDTH = 1
);
    // AXI Stream 信号
    logic                       tvalid;
    logic                       tready;
    logic [DATA_WIDTH-1:0]      tdata;
    logic                       tlast;
    logic [USER_WIDTH-1:0]      tuser;
    logic [(DATA_WIDTH/8)-1:0]  tkeep;   // 字节使能信号
    logic [(DATA_WIDTH/8)-1:0]  tstrb;   // 字节选通信号
    logic [DEST_WIDTH-1:0]      tdest;   // 目标路由信号
    logic [ID_WIDTH-1:0]        tid;     // 传输ID

    // Master 端口 (驱动数据)
    modport Master (
        output tvalid, tdata, tlast, tuser, tkeep, tstrb, tdest, tid,
        input  tready
    );

    // Slave 端口 (接收数据)
    modport Slave (
        input  tvalid, tdata, tlast, tuser, tkeep, tstrb, tdest, tid,
        output tready
    );
    
    // 监控端口 (用于测试)
    modport Monitor (
        input tvalid, tready, tdata, tlast, tuser, tkeep, tstrb, tdest, tid
    );
    
    // 检查握手是否完成
    function automatic logic handshake_done();
        return (tvalid && tready);
    endfunction
    
    // 检查是否为帧的最后一个数据
    function automatic logic is_frame_end();
        return (tvalid && tready && tlast);
    endfunction
    
    // 检查是否为帧的第一个数据
    function automatic logic is_frame_start();
        return (tvalid && tready && tuser);
    endfunction
    
    // 计算有效字节数 (基于 tkeep 信号)
    function automatic int count_valid_bytes();
        int count = 0;
        for (int i = 0; i < (DATA_WIDTH/8); i++) begin
            if (tkeep[i]) count++;
        end
        return count;
    endfunction
    
    // 验证信号有效性
    function automatic logic is_valid_transaction();
        // 检查 tvalid 时，所有相关信号都应该是有效的
        if (tvalid) begin
            // tkeep 不能全为0
            if (tkeep == '0) return 1'b0;
            // tstrb 应该是 tkeep 的子集
            if ((tstrb & tkeep) != tstrb) return 1'b0;
        end
        return 1'b1;
    endfunction
    
    // 任务：等待握手完成
    task wait_for_handshake();
        wait(handshake_done());
    endtask
    
    // 任务：等待帧结束
    task wait_for_frame_end();
        wait(is_frame_end());
    endtask
    
    // 断言：检查协议遵循情况
    `ifdef SIMULATION
        // tvalid 一旦置高，在 tready 为低时不能变低
        property p_tvalid_stable;
            @(posedge clk) disable iff (!rst_n)
            (tvalid && !tready) |=> tvalid;
        endproperty
        
        // tdata, tlast, tuser 在 tvalid 为高时必须保持稳定
        property p_tdata_stable;
            @(posedge clk) disable iff (!rst_n)
            (tvalid && !tready) |=> $stable(tdata);
        endproperty
        
        property p_tlast_stable;
            @(posedge clk) disable iff (!rst_n)
            (tvalid && !tready) |=> $stable(tlast);
        endproperty
        
        property p_tuser_stable;
            @(posedge clk) disable iff (!rst_n)
            (tvalid && !tready) |=> $stable(tuser);
        endproperty
        
        // 如果启用断言检查
        `ifdef ENABLE_SVA
            assert property (p_tvalid_stable) else $error("tvalid 信号不稳定");
            assert property (p_tdata_stable) else $error("tdata 信号不稳定");
            assert property (p_tlast_stable) else $error("tlast 信号不稳定");
            assert property (p_tuser_stable) else $error("tuser 信号不稳定");
        `endif
    `endif
    
endinterface