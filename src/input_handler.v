// --- input_handler.v (已修正复位逻辑) ---
module input_handler(
    input clk,
    input reset_n, // 修正点 1: 端口名改为 reset_n
    input btn_up_raw,
    input btn_down_raw,
    input btn_left_raw,
    input btn_right_raw,
    input sw_start_pause_raw,
    input sw_reset_raw,

    output reg [1:0] direction_out,
    output direction_valid_out,
    output start_pause_event_out,
    output reset_event_out
);

    // Debounced signals
    wire btn_up_deb, btn_down_deb, btn_left_deb, btn_right_deb;
    wire sw_start_pause_deb, sw_reset_deb;
    // Debounced signal delay registers (for edge detection)
    reg btn_up_deb_dly, btn_down_deb_dly, btn_left_deb_dly, btn_right_deb_dly;
    reg sw_start_pause_deb_dly, sw_reset_deb_dly;

    //Internal signal for generating the direction_valid pulse
    reg direction_valid_pulse_internal;

    // Debounce
    // 假设 pbdebounce 模块没有复位输入，或者其复位也是低电平有效
    // 如果 pbdebounce 有复位输入且是低有效，应连接 reset_n
    pbdebounce deb_up ( .clk(clk), /* .reset_n(reset_n), */ .button(btn_up_raw), .pbreg(btn_up_deb) );
    pbdebounce deb_down ( .clk(clk), /* .reset_n(reset_n), */ .button(btn_down_raw), .pbreg(btn_down_deb) );
    pbdebounce deb_left ( .clk(clk), /* .reset_n(reset_n), */ .button(btn_left_raw), .pbreg(btn_left_deb) );
    pbdebounce deb_right ( .clk(clk), /* .reset_n(reset_n), */ .button(btn_right_raw), .pbreg(btn_right_deb) );
    pbdebounce deb_start_pause ( .clk(clk), /* .reset_n(reset_n), */ .button(sw_start_pause_raw), .pbreg(sw_start_pause_deb) );
    pbdebounce deb_reset ( .clk(clk), /* .reset_n(reset_n), */ .button(sw_reset_raw), .pbreg(sw_reset_deb) );

    // Edge detection
    // 修正点 2: 修改 always 块的敏感列表和判断条件
    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin // 判断 !reset_n
            btn_up_deb_dly <= 1'b0;
            btn_down_deb_dly <= 1'b0;
            btn_left_deb_dly <= 1'b0;
            btn_right_deb_dly <= 1'b0;
            sw_start_pause_deb_dly <= 1'b0;
            sw_reset_deb_dly <= 1'b0;
        end else begin
            btn_up_deb_dly <= btn_up_deb;
            btn_down_deb_dly <= btn_down_deb;
            btn_left_deb_dly <= btn_left_deb;
            btn_right_deb_dly <= btn_right_deb;
            sw_start_pause_deb_dly <= sw_start_pause_deb;
            sw_reset_deb_dly <= sw_reset_deb;
        end
    end

    // Rising edge detection (这部分逻辑不变)
    wire btn_up_rise = btn_up_deb && !btn_up_deb_dly;
    wire btn_down_rise = btn_down_deb && !btn_down_deb_dly;
    wire btn_left_rise = btn_left_deb && !btn_left_deb_dly;
    wire btn_right_rise = btn_right_deb && !btn_right_deb_dly;
    wire start_pause_rise = sw_start_pause_deb && !sw_start_pause_deb_dly;
    wire reset_rise = sw_reset_deb && !sw_reset_deb_dly;

    // 修正点 3: 修改第二个 always 块的敏感列表和复位逻辑
    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin // 判断 !reset_n
            direction_out <= 2'b00; // 默认方向或初始方向
            direction_valid_pulse_internal <= 1'b0;
        end else begin
            direction_valid_pulse_internal <= 1'b0; // Default: no new valid direction event this cycle
            if (btn_up_rise && !(btn_down_deb || btn_left_deb || btn_right_deb)) begin
                direction_out <= 2'b00; // up
                direction_valid_pulse_internal <= 1'b1;
            end
            else if (btn_down_rise && !(btn_up_deb || btn_left_deb || btn_right_deb)) begin
                direction_out <= 2'b01; // down
                direction_valid_pulse_internal <= 1'b1;
            end
            else if (btn_left_rise && !(btn_up_deb || btn_down_deb || btn_right_deb)) begin
                direction_out <= 2'b10; // left
                direction_valid_pulse_internal <= 1'b1;
            end
            else if (btn_right_rise && !(btn_up_deb || btn_down_deb || btn_left_deb)) begin
                direction_out <= 2'b11; // right
                direction_valid_pulse_internal <= 1'b1;
            end
            // 注意：如果没有任何方向键按下，direction_out 会保持上一次的值。
            // 如果您希望在没有有效按键时 direction_out 有一个默认值或不更新，
            // 这取决于您的游戏逻辑控制器如何处理 direction_valid_out 信号。
            // 当前的写法是，只有在单个有效方向键按下时才更新 direction_out 和 direction_valid_pulse_internal。
        end
    end

    assign direction_valid_out = direction_valid_pulse_internal;
    assign start_pause_event_out = start_pause_rise;
    assign reset_event_out = reset_rise;

endmodule