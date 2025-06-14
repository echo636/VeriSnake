`timescale 1ns / 1ps

// =================================================================================
// 贪吃蛇VGA渲染模块 (已修正颜色和错位问题)
// =================================================================================
module snake_vga_renderer #(
    parameter X_BITS = 6,
    parameter Y_BITS = 6,
    parameter S_LEN_W = 8,
    parameter S_ADDR_W = 8,
    parameter SCORE_BITS = 16,
    parameter GRID_SIZE = 10,
    parameter GRID_W = 60, 
    parameter GRID_H = 40,
    parameter FOOD_IMAGE_WIDTH  = 10,
    parameter FOOD_IMAGE_HEIGHT = 10,
    parameter FOOD_MEM_DEPTH    = 100,
    parameter FOOD_ADDR_WIDTH   = 7
)(
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

    wire [9:0] vga_row;
    wire [9:0] vga_col;
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
    localparam FRAME_BUFFER_ADDR_W = 12;

    localparam [1:0] CELL_EMPTY      = 2'b00;
    localparam [1:0] CELL_SNAKE_BODY = 2'b01;
    localparam [1:0] CELL_SNAKE_HEAD = 2'b10;
    localparam [1:0] CELL_FOOD       = 2'b11;

    reg [1:0] frame_buffer [0:FRAME_BUFFER_DEPTH-1];
    
    // ================== 图像ROMs实例化 (有修改) ==================
    localparam VGA_WIDTH = 640;
    localparam VGA_HEIGHT = 480;
    localparam VGA_MEM_DEPTH = VGA_WIDTH * VGA_HEIGHT; 
    localparam VGA_ADDR_WIDTH = 19;                     

    wire [11:0] start_screen_pixel;
    wire [11:0] gameover_screen_pixel;
    wire [11:0] food_pixel_data; 
    wire [FOOD_ADDR_WIDTH-1:0] food_rom_addr;

    wire [VGA_ADDR_WIDTH-1:0] vga_addr = vga_row * VGA_WIDTH + vga_col;

    image_rom #(.MEM_DEPTH(VGA_MEM_DEPTH), .ADDR_WIDTH(VGA_ADDR_WIDTH), .DATA_WIDTH(12), .COE_FILE("start_screen.coe")) 
    u_rom_start (.clk(sys_clk), .addr(vga_addr), .dout(start_screen_pixel));

    image_rom #(.MEM_DEPTH(VGA_MEM_DEPTH), .ADDR_WIDTH(VGA_ADDR_WIDTH), .DATA_WIDTH(12), .COE_FILE("gameover_screen.coe"))
    u_rom_gameover (.clk(sys_clk), .addr(vga_addr), .dout(gameover_screen_pixel));

    image_rom #(.MEM_DEPTH(FOOD_MEM_DEPTH), .ADDR_WIDTH(FOOD_ADDR_WIDTH), .DATA_WIDTH(12), .COE_FILE("food.coe"))
    u_rom_food (.clk(sys_clk), .addr(food_rom_addr), .dout(food_pixel_data));

    // ================== 3. 像素拾取 (逻辑有修改) ==================
    // --- FIX 1: 恢复你原始的颜色定义 ---
    localparam [11:0] COLOR_BLACK   = 12'h000;
    localparam [11:0] COLOR_WHITE   = 12'hFFF;
    localparam [11:0] COLOR_RED     = 12'h00F;
    localparam [11:0] COLOR_GREEN   = 12'h0F0;
    localparam [11:0] COLOR_BLUE    = 12'hF00;
    localparam [11:0] COLOR_YELLOW  = 12'h0FF;
    localparam [11:0] COLOR_TRANSPARENT = 12'hF0F;

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

    // --- FIX 2: 使用硬件友好的乘减法代替取模(%)运算 ---
    wire [9:0] total_offset_x = vga_col - GAME_AREA_START_X;
    wire [9:0] total_offset_y = vga_row - GAME_AREA_START_Y;
    wire [9:0] grid_start_offset_x = grid_x * GRID_SIZE;
    wire [9:0] grid_start_offset_y = grid_y * GRID_SIZE;
    wire [3:0] pixel_in_grid_x = total_offset_x - grid_start_offset_x;
    wire [3:0] pixel_in_grid_y = total_offset_y - grid_start_offset_y;

    assign food_rom_addr = (pixel_in_grid_y * FOOD_IMAGE_WIDTH) + pixel_in_grid_x;
    
    always @(*) begin
        if (~vga_rdn) begin
            case (game_state_in)
                2'b00: pixel_data = start_screen_pixel;
                2'b01, 2'b10: begin
                    if (in_game_area) begin
                        case (current_cell)
                            CELL_SNAKE_HEAD: pixel_data = COLOR_RED;
                            CELL_SNAKE_BODY: pixel_data = COLOR_GREEN;
                            CELL_FOOD: begin
                                if (food_pixel_data != COLOR_TRANSPARENT)
                                    pixel_data = food_pixel_data;
                                else
                                    pixel_data = COLOR_BLACK;
                            end
                            default: pixel_data = COLOR_BLACK;
                        endcase
                    end else begin
                        pixel_data = COLOR_BLUE;
                    end
                end
                2'b11: pixel_data = gameover_screen_pixel;
                default: pixel_data = COLOR_BLACK;
            endcase
        end else begin
            pixel_data = 12'h000;
        end
    end

    // ================== 4. 帧缓冲写入逻辑 (无变化) ==================
    // ... 此部分完全不变 ...
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