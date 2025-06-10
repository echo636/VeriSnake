// =================================================================================
// 贪吃蛇VGA渲染模块 (已修改以支持静态图片)
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
    // --- 端口列表不变 ---
    input wire sys_clk,
    input wire sys_reset_n,
    input wire [1:0] game_state_in,
    input wire [SCORE_BITS-1:0] score_in,
    input wire [X_BITS-1:0] food_x_in,
    input wire [Y_BITS-1:0] food_y_in,
    input wire [X_BITS-1:0] snake_head_x_in,
    input wire [Y_BITS-1:0] snake_head_y_in,
    input wire [X_BITS-1:0] game_area_max_x_in,
    input wire [Y_BITS-1:0] game_area_max_y_in,
    input wire [S_LEN_W-1:0] snake_length_in,
    input wire [X_BITS-1:0] queried_segment_x_in,
    input wire [Y_BITS-1:0] queried_segment_y_in,
    input wire queried_segment_valid_in,
    output reg [S_ADDR_W-1:0] vga_query_segment_addr_out,
    output wire vga_hsync_out,
    output wire vga_vsync_out,
    output wire [3:0] vga_r_out,
    output wire [3:0] vga_g_out,
    output wire [3:0] vga_b_out
);

    // ================== 1. 时钟和VGA控制器 (无变化) ==================
    reg [1:0] clk_div_cnt;
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (!sys_reset_n)
            clk_div_cnt <= 2'b0;
        else
            clk_div_cnt <= clk_div_cnt + 1;
    end
    wire pixel_clk = clk_div_cnt[1];

    wire [9:0] vga_row; // 对应480行
    wire [9:0] vga_col; // 对应640列
    wire vga_rdn;
    reg [11:0] pixel_data;

    vgac u_vgac (
        .vga_clk(pixel_clk), .clrn(sys_reset_n), .d_in(pixel_data),
        .row_addr(vga_row), .col_addr(vga_col), .rdn(vga_rdn),
        .r(vga_r_out), .g(vga_g_out), .b(vga_b_out),
        .hs(vga_hsync_out), .vs(vga_vsync_out)
    );

    // ================== 2. 帧缓冲及相关定义 (无变化) ==================
    localparam GAME_AREA_WIDTH   = GRID_W;
    localparam GAME_AREA_HEIGHT  = GRID_H;
    localparam FRAME_BUFFER_DEPTH = GAME_AREA_WIDTH * GAME_AREA_HEIGHT;
    localparam FRAME_BUFFER_ADDR_W = 12; // 60*40=2400, 2^12=4096

    localparam [1:0] CELL_EMPTY      = 2'b00;
    localparam [1:0] CELL_SNAKE_BODY = 2'b01;
    localparam [1:0] CELL_SNAKE_HEAD = 2'b10;
    localparam [1:0] CELL_FOOD       = 2'b11;

    reg [1:0] frame_buffer [0:FRAME_BUFFER_DEPTH-1];
    
    // ================== 新增: 图像ROMs实例化 ==================
    localparam VGA_WIDTH = 640;
    localparam VGA_HEIGHT = 480;
    localparam VGA_MEM_DEPTH = VGA_WIDTH * VGA_HEIGHT; // 307200
    localparam VGA_ADDR_WIDTH = 19;                   // 2^19 > 307200

    wire [11:0] start_screen_pixel;
    wire [11:0] gameover_screen_pixel;
    wire [VGA_ADDR_WIDTH-1:0] vga_addr = vga_row * VGA_WIDTH + vga_col;

    // 实例化开始画面ROM (请确保您有名为 "image_rom.v" 的文件)
    image_rom #(
        .MEM_DEPTH(VGA_MEM_DEPTH), .ADDR_WIDTH(VGA_ADDR_WIDTH), .DATA_WIDTH(12),
        .COE_FILE("start_screen.coe") // 指定开始画面的.coe文件
    ) u_rom_start (
        .clk(sys_clk), .addr(vga_addr), .dout(start_screen_pixel)
    );

    // 实例化游戏结束画面ROM
    image_rom #(
        .MEM_DEPTH(VGA_MEM_DEPTH), .ADDR_WIDTH(VGA_ADDR_WIDTH), .DATA_WIDTH(12),
        .COE_FILE("gameover_screen.coe") // 指定结束画面的.coe文件
    ) u_rom_gameover (
        .clk(sys_clk), .addr(vga_addr), .dout(gameover_screen_pixel)
    );

    // ================== 3. 像素拾取 (逻辑已重写) ==================
    localparam [11:0] COLOR_BLACK  = 12'h000;
    localparam [11:0] COLOR_WHITE  = 12'hFFF;
    localparam [11:0] COLOR_RED    = 12'h00F;
    localparam [11:0] COLOR_GREEN  = 12'h0F0;
    localparam [11:0] COLOR_BLUE   = 12'hF00;
    localparam [11:0] COLOR_YELLOW = 12'h0FF;

    localparam GAME_AREA_START_X = (640 - GRID_W * GRID_SIZE) / 2;
    localparam GAME_AREA_END_X   = GAME_AREA_START_X + GRID_W * GRID_SIZE;
    localparam GAME_AREA_START_Y = (480 - GRID_H * GRID_SIZE) / 2;
    localparam GAME_AREA_END_Y   = GAME_AREA_START_Y + GRID_H * GRID_SIZE;
    
    wire in_game_area = (vga_col >= GAME_AREA_START_X) && (vga_col < GAME_AREA_END_X) &&
                      (vga_row >= GAME_AREA_START_Y) && (vga_row < GAME_AREA_END_Y);

    wire [X_BITS-1:0] grid_x = (vga_col - GAME_AREA_START_X) / GRID_SIZE;
    wire [Y_BITS-1:0] grid_y = (vga_row - GAME_AREA_START_Y) / GRID_SIZE;
    wire [FRAME_BUFFER_ADDR_W-1:0] read_addr = grid_y * GRID_W + grid_x;

    wire [1:0] current_cell = frame_buffer[read_addr];
    
    always @(*) begin
        if (~vga_rdn) begin // 仅在有效显示区域
            case (game_state_in)
                // 状态: IDLE -> 显示开始画面
                2'b00: begin // STATE_IDLE
                    pixel_data = start_screen_pixel;
                end
                
                // 状态: PLAYING 或 PAUSED -> 显示游戏画面
                2'b01, 2'b10: begin // STATE_PLAYING, STATE_PAUSED
                    if (in_game_area) begin
                        case (current_cell)
                            CELL_SNAKE_HEAD: pixel_data = COLOR_RED;
                            CELL_SNAKE_BODY: pixel_data = COLOR_GREEN;
                            CELL_FOOD:       pixel_data = COLOR_YELLOW;
                            default:         pixel_data = COLOR_BLACK;
                        endcase
                    end else begin
                        pixel_data = COLOR_BLUE; // 游戏区域外的边框
                    end
                end
                
                // 状态: GAME_OVER -> 显示结束画面
                2'b11: begin // STATE_GAME_OVER
                    pixel_data = gameover_screen_pixel;
                end

                default: begin
                    pixel_data = COLOR_BLACK;
                end
            endcase
        end else begin
            pixel_data = 12'h000; // 消隐区为黑色
        end
    end

    // ================== 4. 帧缓冲写入逻辑 (无变化) ==================
    localparam UPDATE_IDLE  = 3'd0;
    localparam UPDATE_CLEAR = 3'd1;
    localparam UPDATE_SNAKE = 3'd2;
    localparam UPDATE_FOOD  = 3'd3;
    localparam UPDATE_HEAD  = 3'd4;
    
    reg [2:0] update_state;
    reg [FRAME_BUFFER_ADDR_W-1:0] update_addr_cnt;
    reg [S_ADDR_W-1:0] snake_seg_cnt;

    reg vsync_sync1, vsync_sync2, vsync_sync3;
    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (!sys_reset_n) {vsync_sync1, vsync_sync2, vsync_sync3} <= 3'b0;
        else {vsync_sync1, vsync_sync2, vsync_sync3} <= {vga_vsync_out, vsync_sync1, vsync_sync2};
    end
    wire vsync_posedge = vsync_sync2 & ~vsync_sync3;

    always @(posedge sys_clk or negedge sys_reset_n) begin
        if (!sys_reset_n) begin
            update_state <= UPDATE_CLEAR;
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
                        snake_seg_cnt <= 1;
                        vga_query_segment_addr_out <= 1;
                    end else begin
                        update_addr_cnt <= update_addr_cnt + 1;
                    end
                end
                UPDATE_SNAKE: begin
                    if (snake_seg_cnt < snake_length_in) begin
                        if (queried_segment_valid_in) begin
                            if ((queried_segment_y_in < GRID_H) && (queried_segment_x_in < GRID_W))
                                frame_buffer[queried_segment_y_in * GRID_W + queried_segment_x_in] <= CELL_SNAKE_BODY;
                        end
                        snake_seg_cnt <= snake_seg_cnt + 1;
                        vga_query_segment_addr_out <= snake_seg_cnt + 1;
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