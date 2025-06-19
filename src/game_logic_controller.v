module game_logic_controller #(
    parameter N = 16,
    parameter M = 2,
    parameter INITIAL_SPEED = 26'd10_000_000,
    parameter SPEED_INCREMENT = 26'd20_000_000
)(
    // 时钟和复位
    input wire clk,
    input wire rst_n,

    // 来自输入处理器的信号
    input wire [1:0] dir_in,
    input wire dir_vld_in,
    input wire sp_evt_in,
    input wire rst_evt_in,      

    input wire food_in,
    input wire col_in,
    input wire tick_in,
    output reg [1:0] state_out,
    output reg mv_out,
    output reg grow_out,
    output reg genf_out,
    output reg [N-1:0] sc_out,
    output reg rst_dm_out,
    output reg [M-1:0] snd_evt_out,
    output reg snd_trig_out
);

    localparam S_IDLE = 2'b00;
    localparam S_PLAY = 2'b01;
    localparam S_PAUSE = 2'b10;
    localparam S_OVER = 2'b11;
    localparam UP = 2'b00;
    localparam DOWN = 2'b01;
    localparam LEFT = 2'b10;
    localparam RIGHT = 2'b11;
    localparam SND_EAT = 2'b01;
    localparam SND_OVER = 2'b10;
    localparam SND_START = 2'b11;


    wire rst_act = !rst_n || rst_evt_in; 

    reg [1:0] state, nstate;
    reg [1:0] dir, ndir;
    reg [N-1:0] sc, nsc;
    reg [25:0] spd_cnt;
    reg [25:0] spd;
    reg tick, tick_d;
    reg dir_chg;
    reg eat_reg;
    reg col_reg;
    reg sp_pressed;
    reg eat_prev;
    reg col_prev;
    reg sp_prev;
    reg mv_nxt;
    reg grow_nxt;
    reg genf_nxt;
    reg rst_dm_nxt;
    reg [M-1:0] snd_evt_nxt;
    reg snd_trig_nxt;

    // 边沿检测逻辑
    always @(posedge clk) begin
        if (rst_act) begin
            eat_prev <= 1'b0;
            col_prev <= 1'b0;
            sp_prev <= 1'b0;
            eat_reg <= 1'b0;
            col_reg <= 1'b0;
            sp_pressed <= 1'b0;
        end else begin
            eat_prev <= food_in;
            col_prev <= col_in;
            sp_prev <= sp_evt_in;
            eat_reg <= food_in & ~eat_prev;
            col_reg <= col_in & ~col_prev;
            sp_pressed <= sp_evt_in & ~sp_prev;
        end
    end

    // 游戏时钟分频器
    always @(posedge clk) begin
        if (rst_act) begin 
            spd_cnt <= 26'd0;
            tick <= 1'b0;
            tick_d <= 1'b0;
            spd <= INITIAL_SPEED;
        end else if (state == S_PLAY) begin
            tick_d <= tick;
            if (spd_cnt >= spd - 1) begin
                spd_cnt <= 26'd0;
                tick <= 1'b1;
            end else begin
                spd_cnt <= spd_cnt + 1;
                tick <= 1'b0;
            end
        end else begin
            spd_cnt <= 26'd0;
            tick <= 1'b0;
            tick_d <= 1'b0;
        end
    end

    // 状态机时序逻辑
    always @(posedge clk) begin
        if (rst_act) begin 
            state <= S_IDLE;
            dir <= UP;
            sc <= {N{1'b0}};
            dir_chg <= 1'b0;
        end else begin
            state <= nstate;
            dir <= ndir;
            sc <= nsc;
            if (dir_vld_in && (dir_in != dir)) begin
                dir_chg <= 1'b1;
            end else begin
                dir_chg <= 1'b0;
            end
        end
    end

    // 状态机组合逻辑 
    always @(*) begin
        nstate = state;
        ndir = dir;
        nsc = sc;
        mv_nxt = 1'b0;
        grow_nxt = 1'b0;
        genf_nxt = 1'b0;
        rst_dm_nxt = 1'b0;
        snd_evt_nxt = 2'b00;
        snd_trig_nxt = 1'b0;

        case (state)
            S_IDLE: begin
                if (sp_pressed) begin
                    nstate = S_PLAY;
                    rst_dm_nxt = 1'b1;
                    genf_nxt = 1'b1;
                    nsc = {N{1'b0}};
                    ndir = UP;
                    snd_evt_nxt = SND_START;
                    snd_trig_nxt = 1'b1;
                end
            end
            S_PLAY: begin
                if (sp_pressed) begin
                    nstate = S_PAUSE;
                end else if (col_reg) begin
                    nstate = S_OVER;
                    snd_evt_nxt = SND_OVER;
                    snd_trig_nxt = 1'b1;
                end else begin
                    if (dir_vld_in) begin
                        case (dir)
                            UP:    if (dir_in != DOWN)  ndir = dir_in;
                            DOWN:  if (dir_in != UP)    ndir = dir_in;
                            LEFT:  if (dir_in != RIGHT) ndir = dir_in;
                            RIGHT: if (dir_in != LEFT)  ndir = dir_in;
                        endcase
                    end
                    if (tick) begin
                        mv_nxt = 1'b1;
                    end
                    if (eat_reg) begin
                        grow_nxt = 1'b1;
                        genf_nxt = 1'b1;
                        nsc = sc + 1;
                        snd_evt_nxt = SND_EAT;
                        snd_trig_nxt = 1'b1;
                    end
                end
            end
            S_PAUSE: begin
                if (sp_pressed) begin
                    nstate = S_PLAY;
                end
            end
            S_OVER: begin
                if (sp_pressed) begin
                    nstate = S_IDLE;
                end
            end
            default: begin
                nstate = S_IDLE;
            end
        endcase
    end

    // 根据分数动态调整游戏速度
    always @(posedge clk) begin
        if (rst_act) begin 
            spd <= INITIAL_SPEED;
        end else if (state == S_PLAY && eat_reg) begin
            if (spd > SPEED_INCREMENT + 26'd10_000_000) begin
                spd <= spd - SPEED_INCREMENT;
            end
        end
    end

    // 输出赋值
    always @(posedge clk) begin
        if (rst_act) begin 
            state_out <= S_IDLE;
            mv_out <= 1'b0;
            grow_out <= 1'b0;
            genf_out <= 1'b0;
            sc_out <= {N{1'b0}};
            rst_dm_out <= 1'b0;
            snd_evt_out <= 2'b00;
            snd_trig_out <= 1'b0;
        end else begin
            state_out <= nstate;
            mv_out <= mv_nxt;
            grow_out <= grow_nxt;
            genf_out <= genf_nxt;
            sc_out <= nsc;
            rst_dm_out <= rst_dm_nxt;
            snd_evt_out <= snd_evt_nxt;
            snd_trig_out <= snd_trig_nxt;
        end
    end

endmodule