`timescale 1ns / 1ps

module snake_top (
    input wire clk,
    input wire rst_n,
    input wire ps2_clk,
    input wire ps2_data,
    output wire vga_hs,
    output wire vga_vs,
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b,
    output wire [3:0] seg_an,
    output wire [7:0] seg_data,
    output wire [7:0] led,
    output wire buzzer
);
    localparam GW = 60;
    localparam GH = 44;
    localparam GX = 6;
    localparam GY = 6;
    localparam SA = 6;
    localparam SL = 6;
    localparam SC = 16;
    localparam SE = 2;
    localparam GP = 10;

    wire [1:0] dir;
    wire dir_vld;
    wire sp_evt;
    wire rst_evt;
    wire mv;
    wire grow;
    wire genf;
    wire rst_dm;
    wire [1:0] cur_dir;
    wire eat;
    wire col;
    wire [1:0] state;
    wire [SC-1:0] sc;
    wire [7:0] custom_led;
    wire [GX-1:0] food_x;
    wire [GY-1:0] food_y;
    wire [GX-1:0] head_x;
    wire [GY-1:0] head_y;
    wire [SL-1:0] snake_len;
    wire [SA-1:0] vga_q_addr;
    wire [GX-1:0] q_seg_x;
    wire [GY-1:0] q_seg_y;
    wire q_seg_vld;
    wire [SE-1:0] snd_evt;
    wire snd_trig;

    PS2 u_ps2 (
        .clk(clk),
        .rst_n(rst_n),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .dir(dir),
        .dir_vld(dir_vld),
        .sp_evt(sp_evt),
        .rst_evt(rst_evt)
    );

    game_logic_controller #(
        .N(SC),
        .M(SE)
    ) u_logic (
        .clk(clk),
        .rst_n(rst_n),
        .dir_in(dir),
        .dir_vld_in(dir_vld),
        .sp_evt_in(sp_evt),
        .rst_evt_in(rst_evt),
        .food_in(eat),
        .col_in(col),
        .tick_in(),
        .state_out(state),
        .mv_out(mv),
        .grow_out(grow),
        .genf_out(genf),
        .sc_out(sc),
        .rst_dm_out(rst_dm),
        .snd_evt_out(snd_evt),
        .snd_trig_out(snd_trig)
    );

    snake_food_manager #(
        .X(GX),
        .Y(GY),
        .S_LEN_W(SL),
        .S_ADDR_W(SA)
    ) u_data (
        .clk(clk),
        .rst(rst_dm),
        .mv(mv),
        .dir(cur_dir),
        .genf(genf),
        .max_x(GW-1),
        .max_y(GH-1),
        .q_addr(vga_q_addr),
        .eat(eat),
        .col(col),
        .fx(food_x),
        .fy(food_y),
        .hx(head_x),
        .hy(head_y),
        .len(snake_len),
        .q_x(q_seg_x),
        .q_y(q_seg_y),
        .q_vld(q_seg_vld)
    );
    assign cur_dir = u_logic.dir;

    snake_vga_renderer #(
        .X_BITS(GX),
        .Y_BITS(GY),
        .S_LEN_W(SL),
        .S_ADDR_W(SA),
        .SCORE_BITS(SC),
        .GRID_SIZE(GP),
        .GRID_W(GW),
        .GRID_H(GH)
    ) u_vga (
        .clk(clk),
        .rst_n(rst_n),
        .state(state),
        .sc(sc),
        .fx(food_x),
        .fy(food_y),
        .hx(head_x),
        .hy(head_y),
        .max_x(GW-1),
        .max_y(GH-1),
        .len(snake_len),
        .q_x(q_seg_x),
        .q_y(q_seg_y),
        .q_vld(q_seg_vld),
        .q_addr(vga_q_addr),
        .hs(vga_hs),
        .vs(vga_vs),
        .r(vga_r),
        .g(vga_g),
        .b(vga_b)
    );

    display_driver_basic u_disp (
        .clk(clk),
        .rst_n(rst_n),
        .sc(sc),
        .state(state),
        .an(seg_an),
        .seg(seg_data),
        .led(led)
    );

    sound_controller #(
        .M(SE),
        .CLK_FREQ(100_000_000)
    ) u_snd (
        .clk(clk),
        .rst_n(rst_n),
        .evt(snd_evt),
        .trig(snd_trig),
        .buzz(buzzer)
    );
endmodule
