module snake_food_manager #(
    parameter X = 6,
    parameter Y = 5,
    parameter S_LEN_W = 6,
    parameter S_ADDR_W = 6
)(
    input wire clk,
    input wire rst,
    input wire mv,
    input wire [1:0] dir,
    input wire genf,
    input wire [X-1:0] max_x,
    input wire [Y-1:0] max_y,
    input wire [S_ADDR_W-1:0] q_addr,
    output reg eat,
    output reg col,
    output reg [X-1:0] fx,
    output reg [Y-1:0] fy,
    output wire [X-1:0] hx,
    output wire [Y-1:0] hy,
    output reg [S_LEN_W-1:0] len,
    output wire [X-1:0] q_x,
    output wire [Y-1:0] q_y,
    output wire q_vld
);

    localparam SNAKE_MAX_LEN = (1 << S_ADDR_W);

    reg [X-1:0] sx [0:SNAKE_MAX_LEN-1];
    reg [Y-1:0] sy [0:SNAKE_MAX_LEN-1];
    reg [S_ADDR_W-1:0] hp;
    reg [X+Y-1:0] lfsr;
    reg [X+Y-1:0] cnt;
    reg gening;

    integer i;

    reg [S_LEN_W-1:0] seg_chk;
    reg [S_LEN_W-1:0] len_chk;

    wire [X-1:0] chx = sx[hp];
    wire [Y-1:0] chy = sy[hp];
    
    reg  [X-1:0] nhx;
    reg  [Y-1:0] nhy;
    wire [S_ADDR_W-1:0] nhp = hp + 1;

    wire eat_next;
    wire wall;
    wire self;
    wire food_on;

    // 时钟计数器
    always @(posedge clk) begin
        cnt <= cnt + 1;
    end

    // 头部移动方向
    always @(*) begin
        case (dir)
            2'b00: begin nhx = chx; nhy = chy - 1; end
            2'b01: begin nhx = chx; nhy = chy + 1; end
            2'b10: begin nhx = chx - 1; nhy = chy; end
            default: begin nhx = chx + 1; nhy = chy; end
        endcase
    end

    // 判断是否吃到食物
    assign eat_next = (nhx == fx) && (nhy == fy);

    // 判断是否撞墙
    assign wall = (nhx > max_x) || (nhy > max_y) || (nhx < 0) || (nhy < 0);

    // 判断是否撞到自己
    reg self_r;
    always @(*) begin
        self_r = 1'b0;
        if (eat_next) seg_chk = len;
        else seg_chk = len - 1;
        
        for (i = 1; i < seg_chk; i = i + 1) begin
            if ((nhx == sx[hp - i]) && (nhy == sy[hp - i])) begin
                self_r = 1'b1;
            end
        end
    end
    assign self = self_r;

    // 判断新食物是否生成在蛇身上
    reg food_r;
    wire [X-1:0] rx = (max_x == 0) ? 0 : (lfsr[X-1:0] % max_x);
    wire [Y-1:0] ry = (max_y == 0) ? 0 : (lfsr[X+Y-1:X] % max_y);

    always @(*) begin
        food_r = 1'b0;
        len_chk = len;
        
        for (i = 0; i < len_chk; i = i + 1) begin
            if ((rx == sx[hp - i]) && (ry == sy[hp - i])) begin
                food_r = 1'b1;
            end
        end
    end
    assign food_on = food_r;

    // 状态寄存器与主逻辑
    always @(posedge clk) begin
        if (rst) begin
            sx[0] <= 8;  sy[0] <= 10;
            sx[1] <= 9;  sy[1] <= 10;
            sx[2] <= 10; sy[2] <= 10;
            hp <= 2;
            len <= 3;
            fx <= 10;
            fy <= 9;
            col <= 0;
            eat <= 0;
            lfsr <= cnt;
            gening <= 0;
        end else begin
            eat <= 0;
            col <= 0;
            
            if (X+Y >= 5) begin
                 lfsr <= {lfsr[X+Y-2:0], lfsr[X+Y-1] ^ lfsr[X+Y-5]};
            end else if (X+Y > 0) begin 
                 lfsr <= {lfsr[X+Y-2:0], lfsr[X+Y-1] ^ lfsr[0]};
            end

            if (mv) begin
                if (wall || self) begin
                    col <= 1;
                end else begin
                    hp <= nhp;
                    sx[nhp] <= nhx;
                    sy[nhp] <= nhy;

                    if (eat_next) begin
                        eat <= 1;
                        if (len < SNAKE_MAX_LEN) begin
                            len <= len + 1;
                        end
                    end
                end
            end
            
            if (genf || gening) begin
                if (!food_on) begin
                    fx <= rx;
                    fy <= ry;
                    gening <= 0;
                end else begin
                    gening <= 1;
                end
            end
        end
    end

    // 输出当前蛇头坐标
    assign hx = chx;
    assign hy = chy;

    // VGA查询接口
    wire [S_ADDR_W-1:0] vga_addr = hp - q_addr;
    
    assign q_x = sx[vga_addr];
    assign q_y = sy[vga_addr];
    assign q_vld = (q_addr < len);

endmodule