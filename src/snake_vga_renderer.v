// =================================================================================
// 贪吃蛇VGA渲染模块 (最终修正版)
// =================================================================================
module snake_vga_renderer #(
    parameter X_BITS = 6,
    parameter Y_BITS = 6,
    parameter S_LEN_W = 8,
    parameter S_ADDR_W = 8,
    parameter SCORE_BITS = 16,
    parameter GRID_SIZE = 10,
    parameter GRID_W = 60, // 提供一个默认值，但允许被顶层覆盖
    parameter GRID_H = 40  // 提供一个默认值，但允许被顶层覆盖
)(
    // --- 修正点 1：使用低电平有效的复位端口名 ---
    input wire sys_clk,
    input wire sys_reset_n,

    // 游戏状态输入
    input wire [1:0] game_state_in,
    input wire [SCORE_BITS-1:0] score_in,
    input wire [X_BITS-1:0] food_x_in,
    input wire [Y_BITS-1:0] food_y_in,
    input wire [X_BITS-1:0] snake_head_x_in,
    input wire [Y_BITS-1:0] snake_head_y_in,
    input wire [X_BITS-1:0] game_area_max_x_in,
    input wire [Y_BITS-1:0] game_area_max_y_in,
    input wire [S_LEN_W-1:0] snake_length_in,

    // 蛇身查询接口
    input wire [X_BITS-1:0] queried_segment_x_in,
    input wire [Y_BITS-1:0] queried_segment_y_in,
    input wire queried_segment_valid_in,
    output reg [S_ADDR_W-1:0] vga_query_segment_addr_out,

    // VGA输出
    output wire vga_hsync_out,
    output wire vga_vsync_out,
    output wire [3:0] vga_r_out,
    output wire [3:0] vga_g_out,
    output wire [3:0] vga_b_out
);

    // ================== 1. 时钟和VGA控制器 ==================
    reg [1:0] clk_div_cnt;
    // --- 修正点 2：在所有 always 块中修正复位逻辑 ---
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (!sys_reset_n)
            clk_div_cnt <= 2'b0;
        else
            clk_div_cnt <= clk_div_cnt + 1;
    end
    wire pixel_clk = clk_div_cnt[1];

    wire [8:0] vga_row;
    wire [9:0] vga_col;
    wire vga_rdn;
    reg [11:0] pixel_data;

    vgac u_vgac (
        .vga_clk(pixel_clk),
        .clrn(sys_reset_n), // --- 修正点 3：直接连接低电平复位 ---
        .d_in(pixel_data),
        .row_addr(vga_row),
        .col_addr(vga_col),
        .rdn(vga_rdn),
        .r(vga_r_out), .g(vga_g_out), .b(vga_b_out),
        .hs(vga_hsync_out), .vs(vga_vsync_out)
    );

    // ================== 2. 帧缓冲及相关定义 ==================
    localparam GAME_AREA_WIDTH    = GRID_W;
    localparam GAME_AREA_HEIGHT   = GRID_H;
    localparam FRAME_BUFFER_DEPTH = GAME_AREA_WIDTH * GAME_AREA_HEIGHT;
    localparam FRAME_BUFFER_ADDR_W = X_BITS + Y_BITS;

    localparam [1:0] CELL_EMPTY      = 2'b00;
    localparam [1:0] CELL_SNAKE_BODY = 2'b01;
    localparam [1:0] CELL_SNAKE_HEAD = 2'b10;
    localparam [1:0] CELL_FOOD       = 2'b11;

    reg [1:0] frame_buffer [0:FRAME_BUFFER_DEPTH-1];
    
    // --- 修正点 4：移除不可综合的 initial 块 ---
    // initial begin ... end

    // ================== 3. 像素拾取 ==================
    // --- 修正点 5：修正颜色定义以匹配 BGR 格式 ---
    localparam [11:0] COLOR_BLACK  = 12'h000;
    localparam [11:0] COLOR_WHITE  = 12'hFFF;
    localparam [11:0] COLOR_RED    = 12'h00F; // BGR
    localparam [11:0] COLOR_GREEN  = 12'h0F0; // BGR
    localparam [11:0] COLOR_BLUE   = 12'hF00; // BGR
    localparam [11:0] COLOR_YELLOW = 12'h0FF; // BGR for Yellow (G+R)

    // ... (坐标计算逻辑保持不变, 但可以优化一下让边框可见) ...
    //localparam GRID_W = 60; // 宽度改为60格
    //localparam GRID_H = 40; // 高度改为40格
    localparam GAME_AREA_START_X = (640 - GRID_W * GRID_SIZE) / 2;
    localparam GAME_AREA_END_X   = GAME_AREA_START_X + GRID_W * GRID_SIZE;
    localparam GAME_AREA_START_Y = (480 - GRID_H * GRID_SIZE) / 2;
    localparam GAME_AREA_END_Y   = GAME_AREA_START_Y + GRID_H * GRID_SIZE;
    
    wire in_game_area = (vga_col >= GAME_AREA_START_X) && (vga_col < GAME_AREA_END_X) &&
                        (vga_row >= GAME_AREA_START_Y) && (vga_row < GAME_AREA_END_Y);

    wire [X_BITS-1:0] grid_x = (vga_col - GAME_AREA_START_X) / GRID_SIZE;
    wire [Y_BITS-1:0] grid_y = (vga_row - GAME_AREA_START_Y) / GRID_SIZE;
    wire [FRAME_BUFFER_ADDR_W-1:0] read_addr = grid_y * GRID_W + grid_x; // 注意这里用 GRID_W

    wire [1:0] current_cell = frame_buffer[read_addr];
    
    always @(*) begin
        if (~vga_rdn) begin
            if (in_game_area) begin
                case (current_cell)
                    CELL_SNAKE_HEAD: pixel_data = COLOR_RED;
                    CELL_SNAKE_BODY: pixel_data = COLOR_GREEN;
                    CELL_FOOD:       pixel_data = COLOR_YELLOW;
                    default:         pixel_data = COLOR_BLACK;
                endcase
            end else begin
                pixel_data = COLOR_BLUE; // 蓝色边框
            end
        end else begin
            pixel_data = COLOR_BLACK;
        end
    end

    // ================== 4. 帧缓冲写入逻辑 ==================
    localparam UPDATE_IDLE  = 3'd0;
    localparam UPDATE_CLEAR = 3'd1;
    localparam UPDATE_SNAKE = 3'd2;
    localparam UPDATE_FOOD  = 3'd3;
    localparam UPDATE_HEAD  = 3'd4;
    
    reg [2:0] update_state;
    reg [FRAME_BUFFER_ADDR_W-1:0] update_addr_cnt;
    reg [S_ADDR_W-1:0] snake_seg_cnt;

    // --- 修正点 6：使用可靠的3级Vsync边沿检测 ---
    reg vsync_sync1, vsync_sync2, vsync_sync3;
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (!sys_reset_n) begin
            vsync_sync1 <= 1'b0;
            vsync_sync2 <= 1'b0;
            vsync_sync3 <= 1'b0;
        end else begin
            vsync_sync1 <= vga_vsync_out;
            vsync_sync2 <= vsync_sync1;
            vsync_sync3 <= vsync_sync2;
        end
    end
    wire vsync_posedge = vsync_sync2 & ~vsync_sync3;

    always @(posedge sys_clk or negedge sys_reset_n) begin
        // --- 修正点 7：修正状态机的复位逻辑 ---
        if (!sys_reset_n) begin
            update_state <= UPDATE_CLEAR; // 复位后立即清屏
            update_addr_cnt <= 0;
            snake_seg_cnt <= 0;
            vga_query_segment_addr_out <= 0;
        end else begin
            case (update_state)
                UPDATE_IDLE: begin
                    if (vsync_posedge) begin
                        update_state <= UPDATE_CLEAR;
                        update_addr_cnt <= 0;
                    end
                end
                UPDATE_CLEAR: begin
                    frame_buffer[update_addr_cnt] <= CELL_EMPTY;
                    if (update_addr_cnt == FRAME_BUFFER_DEPTH - 1) begin
                        update_state <= UPDATE_SNAKE;
                        snake_seg_cnt <= 1; // 蛇身从第1段开始查询
                        vga_query_segment_addr_out <= 1;
                    end else begin
                        update_addr_cnt <= update_addr_cnt + 1;
                    end
                end
                UPDATE_SNAKE: begin
                    if (snake_seg_cnt < snake_length_in) begin
                        if (queried_segment_valid_in) begin // 假设数据在同一周期有效
                            frame_buffer[queried_segment_y_in * GRID_W + queried_segment_x_in] <= CELL_SNAKE_BODY;
                        end
                        snake_seg_cnt <= snake_seg_cnt + 1;
                        vga_query_segment_addr_out <= snake_seg_cnt + 1; // 请求下一段
                    end else begin
                        update_state <= UPDATE_HEAD;
                    end
                end
                UPDATE_HEAD: begin
                    if(snake_head_x_in < GRID_W && snake_head_y_in < GRID_H)
                        frame_buffer[snake_head_y_in * GRID_W + snake_head_x_in] <= CELL_SNAKE_HEAD;
                    update_state <= UPDATE_FOOD;
                end
                UPDATE_FOOD: begin
                    if(food_x_in < GRID_W && food_y_in < GRID_H)
                        frame_buffer[food_y_in * GRID_W + food_x_in] <= CELL_FOOD;
                    update_state <= UPDATE_IDLE;
                end
                default: update_state <= UPDATE_IDLE;
            endcase
        end
    end
endmodule