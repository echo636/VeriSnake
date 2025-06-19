// 声音控制器 (已修正时序问题)
module sound_controller #(
    parameter M = 2,
    parameter CLK_FREQ = 100_000_000 // 确保这里是您的100MHz系统时钟
)(
    input wire clk,
    input wire rst_n, // 假设已修正为低电平有效
    input wire [M-1:0] evt,
    input wire trig,
    output reg buzz
);

    // 事件编码定义
    localparam NONE = 2'b00;
    localparam EAT  = 2'b01;
    localparam OVER = 2'b10;
    localparam START= 2'b11;

    // 音效参数定义
    localparam F_EAT  = 2000; // Hz
    localparam F_OVER = 500;  // Hz
    localparam F_START= 1000; // Hz

    // 音效持续时间定义 (单位：时钟周期数)
    localparam D_EAT  = CLK_FREQ / 20; // 50ms
    localparam D_OVER = CLK_FREQ / 2;  // 500ms
    localparam D_START= CLK_FREQ / 10; // 100ms

    // 状态机定义
    localparam IDLE = 1'b0;
    localparam PLAY = 1'b1;
    reg state;

    // 内部寄存器
    reg [31:0] tone; // 存储当前音效的半周期值
    reg [31:0] play_cnt;            // 音效剩余播放时钟计数
    reg [31:0] pwm_cnt;             // 方波半周期计数器

    // 主状态机与PWM输出 (将所有逻辑合并到一个时序块中)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            play_cnt <= 0;
            pwm_cnt <= 0;
            buzz <= 1'b0;
            tone <= 0;
        end else begin
            case (state)
                IDLE: begin
                    buzz <= 1'b0; // 在空闲时保持蜂鸣器关闭
                    // 当收到有效的触发信号时...
                    if (trig && evt != NONE) begin
                        state <= PLAY; // 进入播放状态
                        pwm_cnt <= 0;
                        
                        // --- 在这里计算并装载本次音效的参数 ---
                        case (evt)
                            EAT: begin
                                play_cnt <= D_EAT;
                                tone <= CLK_FREQ / (F_EAT * 2);
                            end
                            OVER: begin
                                play_cnt <= D_OVER;
                                tone <= CLK_FREQ / (F_OVER * 2);
                            end
                            START: begin
                                play_cnt <= D_START;
                                tone <= CLK_FREQ / (F_START * 2);
                            end
                            default: begin
                                play_cnt <= 0;
                                tone <= 0;
                            end
                        endcase
                    end
                end

                PLAY: begin
                    // 检查播放时间是否结束
                    if (play_cnt == 0) begin
                        state <= IDLE;
                        buzz <= 1'b0;
                    end else begin
                        play_cnt <= play_cnt - 1; // 播放时间递减
                        
                        // 根据存储好的 tone 产生PWM方波
                        if (tone > 0) begin
                            if (pwm_cnt < tone - 1) begin
                                pwm_cnt <= pwm_cnt + 1;
                            end else begin
                                pwm_cnt    <= 0;
                                buzz <= ~buzz; // 翻转蜂鸣器电平
                            end
                        end else begin
                            buzz <= 1'b0; // 如果周期为0，则静音
                        end
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule