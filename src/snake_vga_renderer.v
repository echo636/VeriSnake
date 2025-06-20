`timescale 1ns / 1ps

//================================================================================
// 最终版VGA渲染模块 (修正了游戏内物体与边框的地址计算)
//================================================================================
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
    input wire clk,             // 主时钟 (仅用于帧缓冲逻辑)
    input wire px_clk,          // 像素时钟 (用于所有像素渲染逻辑!)
    input wire rst_n,
    input wire [1:0] state,
    input wire [SCORE_BITS-1:0] sc,
    input wire [X_BITS-1:0] fx,
    input wire [Y_BITS-1:0] fy,
    input wire [X_BITS-1:0] hx,
    input wire [Y_BITS-1:0] hy,
    input wire [X_BITS-1:0] max_x,
    input wire [Y_BITS-1:0] max_y,
    input wire [S_LEN_W-1:0] len,
    input wire [X_BITS-1:0] q_x,
    input wire [Y_BITS-1:0] q_y,
    input wire q_vld,
    output reg [S_ADDR_W-1:0] q_addr,
    output wire hs,
    output wire vs,
    output wire [3:0] r,
    output wire [3:0] g,
    output wire [3:0] b
);

    // --- 信号定义 ---
    wire [9:0] row, col;
    wire rdn;
    reg [11:0] px_out;

    // --- VGA控制器例化 ---
    vgac u_vgac (
        .vga_clk(px_clk), .clrn(rst_n), .d_in(px_out),
        .row_addr(row), .col_addr(col), .rdn(rdn),
        .r(r), .g(g), .b(b), .hs(hs), .vs(vs)
    );

    // --- ROM IP核数据线 ---
    wire [11:0] food_data, start_data, gameover_data;
    wire [11:0] head_data, body_data, tail_data;
    wire [11:0] b_t_data, b_b_data, b_l_data, b_r_data;
    wire [11:0] b_tl_data, b_tr_data, b_bl_data, b_br_data;

    // ROM地址线 (关键修正：分离地址)
    wire [18:0] vga_addr;
    wire [6:0] game_sprite_addr;   // 用于蛇、食物等游戏内物体
    wire [6:0] border_sprite_addr; // 用于所有边框
    
    // --- IP核例化 ---
    food_rom            u_food_rom     ( .clka(px_clk), .addra(game_sprite_addr), .douta(food_data) );
    start_screen_rom    u_start_rom    ( .clka(px_clk), .addra(vga_addr), .douta(start_data) );
    gameover_screen_rom u_gameover_rom ( .clka(px_clk), .addra(vga_addr), .douta(gameover_data) );
    snake_head_rom      u_head_rom     ( .clka(px_clk), .addra(game_sprite_addr), .douta(head_data) );
    snake_body_rom      u_body_rom     ( .clka(px_clk), .addra(game_sprite_addr), .douta(body_data) );
    snake_tail_rom      u_tail_rom     ( .clka(px_clk), .addra(game_sprite_addr), .douta(tail_data) );
    border_t_rom        u_border_t     ( .clka(px_clk), .addra(border_sprite_addr), .douta(b_t_data) );
    border_b_rom        u_border_b     ( .clka(px_clk), .addra(border_sprite_addr), .douta(b_b_data) );
    border_l_rom        u_border_l     ( .clka(px_clk), .addra(border_sprite_addr), .douta(b_l_data) );
    border_r_rom        u_border_r     ( .clka(px_clk), .addra(border_sprite_addr), .douta(b_r_data) );
    border_tl_rom       u_border_tl    ( .clka(px_clk), .addra(border_sprite_addr), .douta(b_tl_data) );
    border_tr_rom       u_border_tr    ( .clka(px_clk), .addra(border_sprite_addr), .douta(b_tr_data) );
    border_bl_rom       u_border_bl    ( .clka(px_clk), .addra(border_sprite_addr), .douta(b_bl_data) );
    border_br_rom       u_border_br    ( .clka(px_clk), .addra(border_sprite_addr), .douta(b_br_data) );

    // --- 帧缓冲定义 ---
    localparam FB_DEPTH = GRID_W * GRID_H;
    localparam [2:0] EMPTY = 3'd0, BODY = 3'd1, HEAD = 3'd2, FOOD = 3'd3, TAIL = 3'd4;
    reg [2:0] fb [0:FB_DEPTH-1];
    
    // --- 坐标常量 ---
    localparam LATENCY = 4; // 修正后确认的总延迟
    localparam SX = ((640 - GRID_W * GRID_SIZE) / 2) - LATENCY;
    localparam EX = SX + GRID_W * GRID_SIZE;
    localparam SY = (480 - GRID_H * GRID_SIZE) / 2;
    localparam EY = SY + GRID_H * GRID_SIZE;

    // --- 流水线核心逻辑 ---
    // p1, p2, p3 分别代表流水线第1、2、3级
    reg [9:0] col_p1, row_p1;
    reg [1:0] state_p1;
    reg [X_BITS-1:0] fx_p1;
    reg [Y_BITS-1:0] fy_p1;

    reg in_area_p2;
    reg [X_BITS-1:0] gx_p2;
    reg [Y_BITS-1:0] gy_p2;
    reg [3:0] px_x_p2, px_y_p2;
    reg [1:0] state_p2;
    reg [11:0] start_px_p2, gameover_px_p2, border_pixel_p2;
    
    reg in_food_p3;
    reg [2:0] cell_type_p3;
    reg [1:0] state_p3;
    reg [11:0] food_px_p3, head_px_p3, body_px_p3, tail_px_p3;

    // 地址计算 (组合逻辑)
    assign vga_addr           = row_p1 * 640 + col_p1;
    assign border_sprite_addr = (row_p1 % GRID_SIZE) * 10 + (col_p1 % GRID_SIZE);
    assign game_sprite_addr   = px_y_p2 * 10 + px_x_p2;
    
    // 提前选择正确的边框像素
    wire [11:0] selected_border_pixel;
    assign selected_border_pixel = (row_p1 < SY && col_p1 < SX)  ? b_tl_data :
                                   (row_p1 < SY && col_p1 >= EX) ? b_tr_data :
                                   (row_p1 >= EY && col_p1 < SX) ? b_bl_data :
                                   (row_p1 >= EY && col_p1 >= EX) ? b_br_data :
                                   (row_p1 < SY)                 ? b_t_data  :
                                   (row_p1 >= EY)                ? b_b_data  :
                                   (col_p1 < SX)                 ? b_l_data  :
                                   (col_p1 >= EX)                ? b_r_data  :
                                                                   12'h000;
    
    always @(posedge px_clk) begin
        // --- Pipeline Stage 1 ---
        col_p1 <= col; row_p1 <= row; state_p1 <= state; fx_p1 <= fx; fy_p1 <= fy;
        
        // --- Pipeline Stage 2 ---
        state_p2 <= state_p1;
        in_area_p2 <= (col_p1 >= SX) && (col_p1 < EX) && (row_p1 >= SY) && (row_p1 < EY);
        gx_p2 <= (col_p1 - SX) / GRID_SIZE;
        gy_p2 <= (row_p1 - SY) / GRID_SIZE;
        px_x_p2 <= (col_p1 - SX) % GRID_SIZE;
        px_y_p2 <= (row_p1 - SY) % GRID_SIZE;
        start_px_p2 <= start_data;
        gameover_px_p2 <= gameover_data;
        border_pixel_p2 <= selected_border_pixel;
        
        // --- Pipeline Stage 3 ---
        state_p3      <= state_p2;
        cell_type_p3  <= fb[gy_p2 * GRID_W + gx_p2];
        in_food_p3    <= in_area_p2 && (gx_p2 == fx_p1) && (gy_p2 == fy_p1);
        food_px_p3    <= food_data;
        head_px_p3    <= head_data;
        body_px_p3    <= body_data;
        tail_px_p3    <= tail_data;
    end

    // --- 最终像素颜色决策 (纯组合逻辑) ---
    reg [11:0] color_next;
    always @(*) begin
        case (state_p3)
            2'b00: color_next = start_px_p2;
            2'b01, 2'b10: begin // 游戏进行中
                if (in_area_p2) begin
                    case (cell_type_p3)
                        HEAD: color_next = head_px_p3;
                        BODY: color_next = body_px_p3;
                        TAIL: color_next = tail_px_p3;
                        FOOD: color_next = food_px_p3;
                        default: color_next = 12'h000;
                    endcase
                end else begin // 边框逻辑
                    color_next = border_pixel_p2;
                end
            end
            2'b11: color_next = gameover_px_p2;
            default: color_next = 12'h000;
        endcase
    end
    
    // --- 输出寄存器 ---
    always @(posedge px_clk) begin
        if (~rdn) px_out <= color_next;
        else px_out <= 12'h000;
    end

    // --- 帧缓冲写入逻辑 (由主时钟clk驱动, 保持不变) ---
    localparam U_IDLE = 3'd0, U_CLR = 3'd1, U_SNAKE = 3'd2, U_FOOD_FB = 3'd3, U_HEAD_FB = 3'd4;
    reg [2:0] u_state;
    reg [11:0] u_addr;
    reg [S_LEN_W-1:0] s_cnt;
    reg vs1, vs2, vs3;
    wire vs_pos = vs2 & ~vs3;

    always @(posedge clk or negedge rst_n) {vs1, vs2, vs3} <= !rst_n ? 3'b0 : {vs, vs1, vs2};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            u_state <= U_CLR; u_addr <= 0; s_cnt <= 0; q_addr <= 0;
        end else begin
            case (u_state)
                U_IDLE: if (vs_pos) begin u_state <= U_CLR; u_addr <= 0; end
                U_CLR: begin
                    fb[u_addr] <= EMPTY;
                    if (u_addr == FB_DEPTH - 1) begin u_state <= U_SNAKE; s_cnt <= 1; q_addr <= 1; end
                    else u_addr <= u_addr + 1;
                end
                U_SNAKE: begin
                    if (s_cnt < len) begin
                        if (q_vld) begin
                            if ((q_y < GRID_H) && (q_x < GRID_W)) begin
                                if (s_cnt == len - 1) fb[q_y * GRID_W + q_x] <= TAIL;
                                else fb[q_y * GRID_W + q_x] <= BODY;
                            end
                        end
                        s_cnt <= s_cnt + 1; q_addr <= s_cnt + 1;
                    end else u_state <= U_HEAD_FB;
                end
                U_HEAD_FB: begin if(hx < GRID_W && hy < GRID_H) fb[hy * GRID_W + hx] <= HEAD; u_state <= U_FOOD_FB; end
                U_FOOD_FB: begin if(fx < GRID_W && fy < GRID_H) fb[fy * GRID_W + fx] <= FOOD; u_state <= U_IDLE; end
                default: u_state <= U_IDLE;
            endcase
        end
    end

endmodule