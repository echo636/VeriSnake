`timescale 1ns / 1ps

// 贪吃蛇VGA渲染模块 
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
    input wire clk,
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

    //  时钟和VGA控制器 
    reg [1:0] clkdiv;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clkdiv <= 2'b0;
        else
            clkdiv <= clkdiv + 1;
    end
    wire px_clk = clkdiv[1];

    wire [9:0] row;
    wire [9:0] col;
    wire rdn;
    reg [11:0] px;

    vgac u_vgac (
        .vga_clk(px_clk), .clrn(rst_n), .d_in(px),
        .row_addr(row), .col_addr(col), .rdn(rdn),
        .r(r), .g(g), .b(b),
        .hs(hs), .vs(vs)
    );

    //  帧缓冲及相关定义
    localparam GW = GRID_W;
    localparam GH = GRID_H;
    localparam FB_DEPTH = GW * GH;
    localparam FB_ADDR_W = 12;

    localparam [1:0] EMPTY      = 2'b00;
    localparam [1:0] BODY       = 2'b01;
    localparam [1:0] HEAD       = 2'b10;
    localparam [1:0] FOOD       = 2'b11;

    reg [1:0] fb [0:FB_DEPTH-1];
    
    // 图像ROMs实例化 
    localparam VGA_W = 640;
    localparam VGA_H = 480;
    localparam VGA_MEM_DEPTH = VGA_W * VGA_H; 
    localparam VGA_ADDR_W = 19;                     

    wire [11:0] start_px;
    wire [11:0] over_px;
    wire [11:0] food_px; 
    wire [FOOD_ADDR_WIDTH-1:0] food_addr;

    wire [VGA_ADDR_W-1:0] vga_addr = row * VGA_W + col;

    image_rom #(.MEM_DEPTH(VGA_MEM_DEPTH), .ADDR_WIDTH(VGA_ADDR_W), .DATA_WIDTH(12), .COE_FILE("start_screen.coe")) 
    u_rom_start (.clk(clk), .addr(vga_addr), .dout(start_px));

    image_rom #(.MEM_DEPTH(VGA_MEM_DEPTH), .ADDR_WIDTH(VGA_ADDR_W), .DATA_WIDTH(12), .COE_FILE("gameover_screen.coe"))
    u_rom_gameover (.clk(clk), .addr(vga_addr), .dout(over_px));

    image_rom #(.MEM_DEPTH(FOOD_MEM_DEPTH), .ADDR_WIDTH(FOOD_ADDR_WIDTH), .DATA_WIDTH(12), .COE_FILE("food.coe"))
    u_rom_food (.clk(clk), .addr(food_addr), .dout(food_px));

    // 像素拾取 
    localparam [11:0] BLACK   = 12'h000;
    localparam [11:0] WHITE   = 12'hFFF;
    localparam [11:0] RED     = 12'h00F;
    localparam [11:0] GREEN   = 12'h0F0;
    localparam [11:0] BLUE    = 12'hF00;
    localparam [11:0] YELLOW  = 12'h0FF;
    localparam [11:0] TRANSP  = 12'hF0F;

    localparam SX = (640 - GW * GRID_SIZE) / 2;
    localparam EX = SX + GW * GRID_SIZE;
    localparam SY = (480 - GH * GRID_SIZE) / 2;
    localparam EY = SY + GH * GRID_SIZE;
    
    wire in_area = (col >= SX) && (col < EX) &&
                  (row >= SY) && (row < EY);

    wire [X_BITS-1:0] gx = (col - SX) / GRID_SIZE;
    wire [Y_BITS-1:0] gy = (row - SY) / GRID_SIZE;
    wire [FB_ADDR_W-1:0] r_addr = gy * GW + gx;

    wire [1:0] cur_cell = fb[r_addr];

    wire [9:0] tx = col - SX;
    wire [9:0] ty = row - SY;
    wire [9:0] gx_off = gx * GRID_SIZE;
    wire [9:0] gy_off = gy * GRID_SIZE;
    wire [3:0] px_x = tx - gx_off;
    wire [3:0] px_y = ty - gy_off;

    assign food_addr = (px_y * FOOD_IMAGE_WIDTH) + px_x;
    
    always @(*) begin
        if (~rdn) begin
            case (state)
                2'b00: px = start_px;
                2'b01, 2'b10: begin
                    if (in_area) begin
                        case (cur_cell)
                            HEAD: px = RED;
                            BODY: px = GREEN;
                            FOOD: px = (food_px != TRANSP) ? food_px : BLACK;
                            default: px = BLACK;
                        endcase
                    end else begin
                        px = BLUE;
                    end
                end
                2'b11: px = over_px;
                default: px = BLACK;
            endcase
        end else begin
            px = 12'h000;
        end
    end

    // 帧缓冲写入逻辑 
    localparam U_IDLE  = 3'd0;
    localparam U_CLR = 3'd1;
    localparam U_SNAKE = 3'd2;
    localparam U_FOOD  = 3'd3;
    localparam U_HEAD  = 3'd4;
    
    reg [2:0] u_state;
    reg [FB_ADDR_W-1:0] u_addr;
    reg [S_ADDR_W-1:0] s_cnt;

    reg vs1, vs2, vs3;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) {vs1, vs2, vs3} <= 3'b0;
        else {vs1, vs2, vs3} <= {vs, vs1, vs2};
    end
    wire vs_pos = vs2 & ~vs3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            u_state <= U_CLR;
            u_addr <= 0;
            s_cnt <= 0;
            q_addr <= 0;
        end else begin
            case (u_state)
                U_IDLE: begin
                    if (vs_pos) begin
                        u_state <= U_CLR;
                        u_addr <= 0;
                    end
                end
                U_CLR: begin
                    fb[u_addr] <= EMPTY;
                    if (u_addr == FB_DEPTH - 1) begin
                        u_state <= U_SNAKE;
                        s_cnt <= 1;
                        q_addr <= 1;
                    end else begin
                        u_addr <= u_addr + 1;
                    end
                end
                U_SNAKE: begin
                    if (s_cnt < len) begin
                        if (q_vld) begin
                            if ((q_y < GH) && (q_x < GW))
                                fb[q_y * GW + q_x] <= BODY;
                        end
                        s_cnt <= s_cnt + 1;
                        q_addr <= s_cnt + 1;
                    end else begin
                        u_state <= U_HEAD;
                    end
                end
                U_HEAD: begin
                    if(hx < GW && hy < GH)
                        fb[hy * GW + hx] <= HEAD;
                    u_state <= U_FOOD;
                end
                U_FOOD: begin
                    if(fx < GW && fy < GH)
                        fb[fy * GW + fx] <= FOOD;
                    u_state <= U_IDLE;
                end
                default: u_state <= U_IDLE;
            endcase
        end
    end
endmodule