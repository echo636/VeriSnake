module PS2(
    input clk,               // 系统主时钟
    input rst_n,             // 低电平有效复位
    input ps2_clk,           // 来自PS/2接口的时钟
    input ps2_data,          // 来自PS/2接口的数据

    output reg [1:0] dir,
    output reg dir_vld,
    output reg sp_evt,
    output reg rst_evt
);

    // PS2时钟同步与下降沿检测
    reg c0, c1, c2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {c2, c1, c0} <= 3'b111; // 复位为高
        end else begin
            {c2, c1, c0} <= {c1, c0, ps2_clk};
        end
    end
    wire negedge_clk = c2 & ~c1; 

    // PS2数据接收逻辑
    reg [3:0] cnt;
    reg [7:0] data;
    reg ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 4'd0;
            ready <= 1'b0;
        end else begin
            ready <= 1'b0; // 默认每个周期清零，产生单周期脉冲
            if (negedge_clk) begin
                if (cnt == 4'd0 && ps2_data == 1'b0) begin // 检测到起始位
                    cnt <= cnt + 1;
                end else if (cnt > 0 && cnt < 9) begin // 接收8位数据
                    data[cnt-1] <= ps2_data;
                    cnt <= cnt + 1;
                end else if (cnt == 10) begin // 第10位是奇偶校验位(忽略)，第11位是停止位(高)
                    ready <= 1'b1; // 接收完成，产生一个脉冲
                    cnt <= 4'd0;
                end else if (cnt > 0) begin
                    cnt <= cnt + 1;
                end
            end
        end
    end

    // 扫描码处理逻辑
    reg [9:0] code;
    reg brk;
    reg ext;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            code <= 10'd0;
            brk <= 1'b0;
            ext <= 1'b0;
        end else if (ready) begin // 只有在新数据字节到达时才处理
            if (data == 8'hF0) begin
                brk <= 1'b1; // 下一个字节是断码
                ext <= 1'b0; // 清除扩展码标志
            end else if (data == 8'hE0) begin
                ext <= 1'b1; // 下一个字节是扩展码
                brk <= 1'b0; // 清除断码标志
            end else begin
                code <= {ext, brk, data};
                brk <= 1'b0; // 清除标志，为下一次做准备
                ext <= 1'b0;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dir <= 2'b00;
            dir_vld <= 1'b0;
            sp_evt <= 1'b0;
            rst_evt <= 1'b0;
            // enter <= 1'b0;
            // esc <= 1'b0;
        end else begin
            // 默认每个周期将脉冲信号清零
            dir_vld <= 1'b0;
            sp_evt <= 1'b0;
            rst_evt <= 1'b0;

            // 只有在新数据字节到达且不是断码时才处理
            if (ready && !brk) begin
                case ({ext, data})
                    // 方向键
                    9'h075, 9'h175: begin dir <= 2'b00; dir_vld <= 1'b1; end // Up
                    9'h072, 9'h172: begin dir <= 2'b01; dir_vld <= 1'b1; end // Down
                    9'h06B, 9'h16B: begin dir <= 2'b10; dir_vld <= 1'b1; end // Left
                    9'h074, 9'h174: begin dir <= 2'b11; dir_vld <= 1'b1; end // Right
                    
                    // 功能键
                    9'h029: sp_evt <= 1'b1; // Space for Start/Pause
                    9'h00D: rst_evt <= 1'b1;       // Tab for Game Reset (example)
                    
                    // 10'h05A: enter <= 1; // Enter
                    // 10'h076: esc <= 1;   // Escape

                    default: ; // 其他按键按下不产生任何事件
                endcase
            end
        end
    end
endmodule