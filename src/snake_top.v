`timescale 1ns / 1ps

module snake_top (
    // =================== 物理输入 ===================
    input wire sys_clk,             // 系统时钟 (例如 100MHz)
    input wire sys_reset_n,         // 系统复位 (低电平有效)

    // 按键输入 (假设您有这些物理按键)
    input wire btn_up_raw_in,
    input wire btn_down_raw_in,
    input wire btn_left_raw_in,
    input wire btn_right_raw_in,
    input wire btn_start_pause_raw_in,
    input wire btn_game_reset_raw_in,

    // =================== 物理输出 ===================
    // VGA 输出
    output wire vga_hs_out,
    output wire vga_vs_out,
    output wire [3:0] vga_r_out,
    output wire [3:0] vga_g_out,
    output wire [3:0] vga_b_out,

    // 七段数码管输出 (假设8位共阳极数码管，显示4位分数)
    output wire [3:0] seg_an_out,     // 位选，假设低电平有效
    output wire [7:0] seg_data_out,   // 段选，共阳极通常低电平点亮

    // LED 输出 (假设8个LED)
    output wire [7:0] led_out

    output wire buzzer_physical_out // 蜂鸣器输出
);

    // =================== 全局参数定义 ===================
    // 游戏区域定义 (格子数)
    localparam GAME_GRID_WIDTH_X    = 60; // 例如 60 格宽
    localparam GAME_GRID_HEIGHT_Y   = 44; // 例如 40 格高
    localparam GRID_COORD_X_BITS    = 6;  // 需要能表示0到59，6位足够 (2^6=64)
    localparam GRID_COORD_Y_BITS    = 6;  // 需要能表示0到39，6位足够 (2^6=64)

    // 蛇相关参数
    localparam SNAKE_ADDR_BITS      = 6;  // 蛇身数组地址位宽 (2^6 = 64节最大长度)
    localparam SNAKE_LEN_BITS       = 6;  // 蛇长度的位宽

    // 分数和声音
    localparam SCORE_BITS           = 16; // 分数显示
    localparam SOUND_EVENT_BITS     = 2;

    // VGA渲染器中的格子像素大小
    localparam VGA_GRID_PIXEL_SIZE  = 10;


    // =================== 模块间连接线 (Wires) ===================

    // Input Handler -> Game Logic Controller
    wire [1:0] direction_to_logic;
    wire       direction_valid_to_logic;
    wire       start_pause_event_to_logic;
    wire       reset_event_to_logic;

    // Game Logic Controller -> Snake Food Manager
    wire       snake_move_cmd_to_data;
    wire       snake_grow_cmd_to_data; // 来自逻辑控制器的增长命令
    wire       generate_food_cmd_to_data;
    wire       reset_data_manager_cmd_to_data;
    wire [1:0] current_direction_to_data; // 逻辑控制器需要输出当前方向给数据管理器

    // Snake Food Manager -> Game Logic Controller
    wire       food_eaten_from_data;
    wire       collision_from_data;

    // Game Logic Controller -> Display Driver & VGA Renderer
    wire [1:0] game_state_to_display_vga;
    wire [SCORE_BITS-1:0] score_to_display_vga;
    wire [7:0] custom_led_to_display; // 假设 game_logic_controller 会输出自定义LED模式

    // Snake Food Manager -> VGA Renderer
    wire [GRID_COORD_X_BITS-1:0] food_x_to_vga;
    wire [GRID_COORD_Y_BITS-1:0] food_y_to_vga;
    wire [GRID_COORD_X_BITS-1:0] snake_head_x_to_vga;
    wire [GRID_COORD_Y_BITS-1:0] snake_head_y_to_vga;
    wire [SNAKE_LEN_BITS-1:0]    snake_length_to_vga;

    // VGA Renderer <-> Snake Food Manager (查询接口)
    wire [SNAKE_ADDR_BITS-1:0]   vga_query_addr_to_data;
    wire [GRID_COORD_X_BITS-1:0] queried_seg_x_from_data;
    wire [GRID_COORD_Y_BITS-1:0] queried_seg_y_from_data;
    wire                         queried_seg_valid_from_data;

    // Game Logic Controller -> Sound Controller
    wire [SOUND_EVENT_BITS-1:0] sound_event_code_from_logic;
    wire sound_trigger_from_logic;

    // =================== 模块实例化 ===================

    // 1. 输入处理器 (Input Handler)
    input_handler #(
        // 如果 input_handler 有参数，在这里传递
    ) u_input_handler (
        .clk(sys_clk),
        .reset_n(sys_reset_n), // 连接到全局低电平复位
        .btn_up_raw(btn_up_raw_in),
        .btn_down_raw(btn_down_raw_in),
        .btn_left_raw(btn_left_raw_in),
        .btn_right_raw(btn_right_raw_in),
        .sw_start_pause_raw(btn_start_pause_raw_in),
        .sw_reset_raw(btn_game_reset_raw_in),

        .direction_out(direction_to_logic),
        .direction_valid_out(direction_valid_to_logic),
        .start_pause_event_out(start_pause_event_to_logic),
        .reset_event_out(reset_event_to_logic)
    );

    // 2. 游戏逻辑控制器 (Game Logic Controller)
    game_logic_controller #(
        .N(SCORE_BITS),
        .M(SOUND_EVENT_BITS)
        // .INITIAL_SPEED( YourSpeed ), // 如果需要，可以覆盖默认参数
        // .SPEED_INCREMENT( YourIncrement )
    ) u_game_logic_controller (
        .clk(sys_clk),
        .reset_global_n(sys_reset_n), // 连接到全局低电平复位
        .direction_in(direction_to_logic),
        .direction_valid_in(direction_valid_to_logic),
        .start_pause_event_in(start_pause_event_to_logic),
        .reset_event_in(reset_event_to_logic),
        .food_eaten_in(food_eaten_from_data),
        .collision_in(collision_from_data),
        // .game_tick_in(some_external_tick), // 如果使用外部tick

        .game_state_out(game_state_to_display_vga),
        .snake_move_cmd_out(snake_move_cmd_to_data),
        .snake_grow_cmd_out(snake_grow_cmd_to_data), // 连接到数据管理器
        .generate_food_cmd_out(generate_food_cmd_to_data),
        .current_score_out(score_to_display_vga),
        .reset_data_manager_cmd_out(reset_data_manager_cmd_to_data)
        .sound_event_code_out(sound_event_code_from_logic), // <--- 连接到 wire
        .sound_trigger_out(sound_trigger_from_logic)       // <--- 连接到 wire
    );
    // 确保 game_logic_controller 输出 current_direction_in 给 snake_food_manager
    // 这通常是 current_direction 寄存器，这里假设 game_logic_controller 内部有对应的输出
    // 如果没有，你需要在 game_logic_controller 中添加一个输出 current_direction 的端口


    // 3. 蛇身与食物数据管理器 (Snake and Food Data Manager)
    snake_food_manager #(
        .X(GRID_COORD_X_BITS),
        .Y(GRID_COORD_Y_BITS),
        .S_LEN_W(SNAKE_LEN_BITS),
        .S_ADDR_W(SNAKE_ADDR_BITS)
    ) u_snake_food_manager (
        .clk(sys_clk),
        .reset_cmd_in(reset_data_manager_cmd_to_data),
        .snake_move_cmd_in(snake_move_cmd_to_data),
        // snake_food_manager 已移除 snake_grow_cmd_in, 吃食物自动增长
        .current_direction_in(current_direction_to_data), // 需要从game_logic_controller获取
        .generate_food_cmd_in(generate_food_cmd_to_data),
        .game_area_max_x_in(GAME_GRID_WIDTH_X - 1),   // 传入最大坐标 (0到WIDTH-1)
        .game_area_max_y_in(GAME_GRID_HEIGHT_Y - 1),  // 传入最大坐标 (0到HEIGHT-1)
        .vga_query_segment_addr_in(vga_query_addr_to_data),

        .food_eaten_out(food_eaten_from_data),
        .collision_out(collision_from_data),
        .food_x_out(food_x_to_vga),
        .food_y_out(food_y_to_vga),
        .snake_head_x_out(snake_head_x_to_vga),
        .snake_head_y_out(snake_head_y_to_vga),
        .snake_length_out(snake_length_to_vga),
        .queried_segment_x_out(queried_seg_x_from_data),
        .queried_segment_y_out(queried_seg_y_from_data),
        .queried_segment_valid_out(queried_seg_valid_from_data)
    );
    // **重要**: `current_direction_to_data` 需要从 `game_logic_controller` 获取。
    // 您需要确保 `game_logic_controller` 有一个输出当前方向的端口，或者直接将其内部的
    // `current_direction` 信号引出。这里我先用 `current_direction_to_data` 作为占位。
    // 如果 `game_logic_controller` 直接输出更新后的 `next_direction` 作为 `current_direction_out`，
    // 那么可以直接连接。
    assign current_direction_to_data = u_game_logic_controller.current_direction; // 示例，假设可以直接访问


    // 4. VGA 显示控制器 (VGA Renderer)
    snake_vga_renderer #(
        .X_BITS(GRID_COORD_X_BITS),
        .Y_BITS(GRID_COORD_Y_BITS),
        .S_LEN_W(SNAKE_LEN_BITS),
        .S_ADDR_W(SNAKE_ADDR_BITS),
        .SCORE_BITS(SCORE_BITS),
        .GRID_SIZE(VGA_GRID_PIXEL_SIZE),
        // 将 game_area_max_x/y 作为参数传递给渲染器，使其与数据管理器一致
        .GRID_W(GAME_GRID_WIDTH_X), 
        .GRID_H(GAME_GRID_HEIGHT_Y)
    ) u_snake_vga_renderer (
        .sys_clk(sys_clk),
        .sys_reset_n(sys_reset_n),
        .game_state_in(game_state_to_display_vga),
        .score_in(score_to_display_vga),
        .food_x_in(food_x_to_vga),
        .food_y_in(food_y_to_vga),
        .snake_head_x_in(snake_head_x_to_vga),
        .snake_head_y_in(snake_head_y_to_vga),
        // game_area_max_x_in 和 game_area_max_y_in 在渲染器中用于计算边框位置
        // 它们现在通过 GRID_W 和 GRID_H 间接定义了
        .game_area_max_x_in(GAME_GRID_WIDTH_X -1), // 传递给渲染器内部逻辑（如果它还使用的话）
        .game_area_max_y_in(GAME_GRID_HEIGHT_Y -1), // 传递给渲染器内部逻辑（如果它还使用的话）
        .snake_length_in(snake_length_to_vga),
        .queried_segment_x_in(queried_seg_x_from_data),
        .queried_segment_y_in(queried_seg_y_from_data),
        .queried_segment_valid_in(queried_seg_valid_from_data),

        .vga_query_segment_addr_out(vga_query_addr_to_data),
        .vga_hsync_out(vga_hs_out),
        .vga_vsync_out(vga_vs_out),
        .vga_r_out(vga_r_out),
        .vga_g_out(vga_g_out),
        .vga_b_out(vga_b_out)
    );

    // 5. 基础显示驱动 (7段数码管和LED)
    // 假设 game_logic_controller 能直接输出一个 custom_led_pattern
    // assign custom_led_to_display = 8'b0; // 如果没有，先给个默认值
    //assign custom_led_to_display = u_game_logic_controller.sound_trigger_out ? 8'hF0 : 8'h0F; // 示例：用声音触发来闪烁LED


    display_driver_basic #(
        // 如果 display_driver_basic 有参数，在这里传递
    ) u_display_driver_basic (
        .clk(sys_clk), // 注意：数码管扫描时钟通常比VGA时钟慢得多
                       // 这里简单使用sys_clk，实际可能需要进一步分频
        .reset_n(sys_reset_n),
        .score_in(score_to_display_vga),
        .game_state_in(game_state_to_display_vga),
        //.custom_led_pattern_in(custom_led_to_display),

        .seg_an_out(seg_an_out),
        .seg_data_out(seg_data_out),
        .led_out(led_out)
    );

    // 6. 声音控制器 (Sound Controller)
    sound_controller #(
        .M(SOUND_EVENT_BITS),
        .CLK_FREQ(100_000_000) // <--- 注意！您的系统时钟是100MHz，这里要传递正确的值
    ) u_sound_controller (
        .clk(sys_clk),             // 使用100MHz系统时钟
        .reset_n(sys_reset_n),       // 连接到全局低电平有效复位
        .sound_event_code_in(sound_event_code_from_logic),
        .sound_trigger_in(sound_trigger_from_logic),
        .buzzer_out(buzzer_physical_out)
    );

endmodule