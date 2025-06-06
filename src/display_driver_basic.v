// display_driver_basic.v (已修正复位逻辑)
module display_driver_basic(
    input clk,
    input reset_n, // 修正点 1: 端口名改为 reset_n, 表示低电平有效
    input [15:0] score_in,
    input [1:0] game_state_in,
    // input [7:0] custom_led_pattern_in, // 您之前的版本中已移除此输入，这里保持移除

    output [3:0] seg_an_out,     // 修正点 2: 您的原始代码输出是4位，这里保持4位
    output [7:0] seg_data_out,
    output [7:0] led_out
);

    // Binary to BCD conversion
    wire [15:0] bcd_score;
    reg [15:0] score_reg;
    // Insert register buffer to avoid glitches
    // 修正点 3: always 块的敏感列表和复位条件
    always @(posedge clk or negedge reset_n) begin // 对 reset_n 的下降沿敏感
        if (!reset_n) begin // 判断 !reset_n (当 reset_n 为0时复位)
            score_reg <= 16'b0; // 复位时给一个确定值
        end else begin
            score_reg <= score_in;
        end
    end
    bin2bcd score_converter(
        .bin(score_reg),
        .bcd(bcd_score)
    );

    // BCD score register
    reg [15:0] bcd_score_reg;
    // 修正点 4: always 块的敏感列表和复位条件
    always @(posedge clk or negedge reset_n) begin // 对 reset_n 的下降沿敏感
        if (!reset_n) begin // 判断 !reset_n
            bcd_score_reg <= 16'b0; // 复位时给一个确定值
        end else begin
            bcd_score_reg <= bcd_score;
        end
    end

    reg [1:0] reset_sync_stages = 2'b11; // 初始化为非复位状态
    wire synchronized_reset_active_high;

    always @(posedge clk) begin // 这个同步器本身不需要异步复位，它依赖 reset_n 的值
        reset_sync_stages <= {reset_sync_stages[0], reset_n};
    end
    assign synchronized_reset_active_high = ~reset_sync_stages[1]; // reset_sync_stages[1] 是同步后的 reset_n (低有效), 取反后是高有效

    DisplayNumber display_controller(
        .clk(clk),
        .rst(synchronized_reset_active_high), // 传递同步后的高有效复位
        .hexs(bcd_score_reg),
        .points(4'b0000),
        .LEs(4'b0000),
        .AN(seg_an_out),       // 确保 DisplayNumber 的 AN 端口是4位
        .SEGMENT(seg_data_out)
    );

    // LED status display
    reg [7:0] led_state;
    always @(*) begin
        case(game_state_in)
            2'b00: led_state = 8'b00000000;
            2'b01: led_state = 8'b11111111;
            2'b10: led_state = 8'b11000011;
            2'b11: led_state = 8'b00111100;
            default: led_state = 8'b00000001; // 与之前保持一致
        endcase
    end

    assign led_out = led_state; // 直接输出计算的 led_state
endmodule