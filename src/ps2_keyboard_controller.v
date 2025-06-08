// PS2.v (已修正复位和输出逻辑)
module PS2(
    input clk,               // 系统主时钟 (例如 100MHz)
    input reset_n,           // <--- 修正1: 低电平有效复位
    input ps2_clk_in,        // 来自PS/2接口的时钟
    input ps2_data_in,       // 来自PS/2接口的数据

    // 输出与 input_handler 的输出端口保持一致
    output reg [1:0] direction_out,
    output reg direction_valid_out,
    output reg start_pause_event_out,
    output reg reset_event_out
    // output reg enter, // 如果需要，可以保留这些
    // output reg esc   // 如果需要，可以保留这些
);

    // PS2时钟同步与下降沿检测
    reg ps2_clk_sync0, ps2_clk_sync1, ps2_clk_sync2;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            {ps2_clk_sync2, ps2_clk_sync1, ps2_clk_sync0} <= 3'b111; // 复位为高
        end else begin
            {ps2_clk_sync2, ps2_clk_sync1, ps2_clk_sync0} <= {ps2_clk_sync1, ps2_clk_sync0, ps2_clk_in};
        end
    end
    wire negedge_ps2_clk = ps2_clk_sync2 & ~ps2_clk_sync1; // 使用同步后的信号进行边沿检测，更可靠

    // PS2数据接收逻辑
    reg [3:0] bit_count;
    reg [7:0] data_byte;
    reg data_ready_pulse;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            bit_count <= 4'd0;
            data_ready_pulse <= 1'b0;
        end else begin
            data_ready_pulse <= 1'b0; // 默认每个周期清零，产生单周期脉冲
            if (negedge_ps2_clk) begin
                if (bit_count == 4'd0 && ps2_data_in == 1'b0) begin // 检测到起始位
                    bit_count <= bit_count + 1;
                end else if (bit_count > 0 && bit_count < 9) begin // 接收8位数据
                    data_byte[bit_count-1] <= ps2_data_in;
                    bit_count <= bit_count + 1;
                end else if (bit_count == 10) begin // 第10位是奇偶校验位(忽略)，第11位是停止位(高)
                    data_ready_pulse <= 1'b1; // 接收完成，产生一个脉冲
                    bit_count <= 4'd0;
                end else if (bit_count > 0) begin
                    bit_count <= bit_count + 1;
                end
            end
        end
    end

    // 扫描码处理逻辑
    reg [9:0] scan_code;
    reg is_break_code;
    reg is_extended_code;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            scan_code <= 10'd0;
            is_break_code <= 1'b0;
            is_extended_code <= 1'b0;
        end else if (data_ready_pulse) begin // 只有在新数据字节到达时才处理
            if (data_byte == 8'hF0) begin
                is_break_code <= 1'b1; // 下一个字节是断码
                is_extended_code <= 1'b0; // 清除扩展码标志
            end else if (data_byte == 8'hE0) begin
                is_extended_code <= 1'b1; // 下一个字节是扩展码
                is_break_code <= 1'b0; // 清除断码标志
            end else begin
                scan_code <= {is_extended_code, is_break_code, data_byte};
                is_break_code <= 1'b0; // 清除标志，为下一次做准备
                is_extended_code <= 1'b0;
            end
        end
    end
    
    // --- 修正2: 将按键事件解码和输出脉冲生成放在一个时序块中 ---
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            direction_out <= 2'b00;
            direction_valid_out <= 1'b0;
            start_pause_event_out <= 1'b0;
            reset_event_out <= 1'b0;
            // enter <= 1'b0;
            // esc <= 1'b0;
        end else begin
            // 默认每个周期将脉冲信号清零
            direction_valid_out <= 1'b0;
            start_pause_event_out <= 1'b0;
            reset_event_out <= 1'b0;

            // 只有在新数据字节到达且不是断码时才处理
            if (data_ready_pulse && !is_break_code) begin
                case ({is_extended_code, data_byte})
                    // 方向键 (支持小键盘和独立方向键)
                    9'h075, 9'h175: begin direction_out <= 2'b00; direction_valid_out <= 1'b1; end // Up
                    9'h072, 9'h172: begin direction_out <= 2'b01; direction_valid_out <= 1'b1; end // Down
                    9'h06B, 9'h16B: begin direction_out <= 2'b10; direction_valid_out <= 1'b1; end // Left
                    9'h074, 9'h174: begin direction_out <= 2'b11; direction_valid_out <= 1'b1; end // Right
                    
                    // 功能键
                    9'h029: start_pause_event_out <= 1'b1; // Space for Start/Pause
                    9'h00D: reset_event_out <= 1'b1;       // Tab for Game Reset (example)
                    
                    // 您的原始代码中的其他按键映射
                    // 10'h05A: enter <= 1; // Enter
                    // 10'h076: esc <= 1;   // Escape

                    default: ; // 其他按键按下不产生任何事件
                endcase
            end
            // 注意：当按键松开时 (收到断码)，我们这里不做任何操作。
            // direction_out 会保持上一次的值，而事件脉冲已经自动清零。
        end
    end

endmodule