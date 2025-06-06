`timescale 1ns / 1ps

module tb_debug_food_and_score;

    // =================== Testbench Parameters ===================
    localparam CLK_PERIOD_NS = 10; // 10ns for 100MHz clock
    // 游戏节拍时间 (基于 game_logic_controller 中的 INITIAL_SPEED)
    // 假设 INITIAL_SPEED = 50_000_000, 100MHz clk -> 0.5秒/tick
    localparam ONE_GAME_TICK_NS = 500_000_000; // 500ms in ns
    localparam BTN_PRESS_DURATION_NS = 100;    // 100ns 按键持续时间

    // =================== Signal Declarations ===================
    reg tb_sys_clk;
    reg tb_sys_reset_n;
    reg tb_btn_up_raw_in;
    reg tb_btn_down_raw_in;
    reg tb_btn_left_raw_in;
    reg tb_btn_right_raw_in;
    reg tb_btn_start_pause_raw_in;
    reg tb_btn_game_reset_raw_in;

    wire tb_vga_hs_out;
    wire tb_vga_vs_out;
    wire [3:0] tb_vga_r_out, tb_vga_g_out, tb_vga_b_out;
    wire [3:0] tb_seg_an_out; // 假设顶层是4位位选，如果您的顶层是8位，请改为 [7:0]
    wire [7:0] tb_seg_data_out;
    wire [7:0] tb_led_out;

    // =================== DUT Instantiation ===================
    snake_top uut (
        .sys_clk(tb_sys_clk), .sys_reset_n(tb_sys_reset_n),
        .btn_up_raw_in(tb_btn_up_raw_in), .btn_down_raw_in(tb_btn_down_raw_in),
        .btn_left_raw_in(tb_btn_left_raw_in), .btn_right_raw_in(tb_btn_right_raw_in),
        .btn_start_pause_raw_in(tb_btn_start_pause_raw_in),
        .btn_game_reset_raw_in(tb_btn_game_reset_raw_in),
        .vga_hs_out(tb_vga_hs_out), .vga_vs_out(tb_vga_vs_out),
        .vga_r_out(tb_vga_r_out), .vga_g_out(tb_vga_g_out), .vga_b_out(tb_vga_b_out),
        .seg_an_out(tb_seg_an_out), .seg_data_out(tb_seg_data_out), .led_out(tb_led_out)
    );

    // Clock Generation
    initial tb_sys_clk = 1'b0;
    always #(CLK_PERIOD_NS / 2) tb_sys_clk = ~tb_sys_clk;

    // Stimulus Sequence
    initial begin
        // --- 1. Initialize and Reset ---
        tb_sys_reset_n            = 1'b0;
        tb_btn_up_raw_in          = 1'b0; tb_btn_down_raw_in        = 1'b0;
        tb_btn_left_raw_in        = 1'b0; tb_btn_right_raw_in       = 1'b0;
        tb_btn_start_pause_raw_in = 1'b0; tb_btn_game_reset_raw_in  = 1'b0;
        $display("[%0t ns] TB: Reset Asserted.", $time);
        #(20 * CLK_PERIOD_NS); // 200ns
        tb_sys_reset_n = 1'b1;
        $display("[%0t ns] TB: Reset Released. Initial snake head (e.g. 10,10), food (e.g. 10,12), dir UP.", $time);
        #(100 * CLK_PERIOD_NS); // Wait 1us

        // --- 2. Press Start ---
        $display("[%0t ns] TB: Pressing START button.", $time);
        tb_btn_start_pause_raw_in = 1'b1;
        #(BTN_PRESS_DURATION_NS);
        tb_btn_start_pause_raw_in = 1'b0;
        #(CLK_PERIOD_NS);
        $display("[%0t ns] TB: START processed. Game should be PLAYING.", $time);

        // --- 3. Game Tick 1: Snake moves UP. Expected Head: (10,9) ---
        $display("[%0t ns] TB: Waiting for 1st game tick (snake moves UP).", $time);
        #(ONE_GAME_TICK_NS + 100 * CLK_PERIOD_NS); 

        // --- 4. Press DOWN button to change direction ---
        $display("[%0t ns] TB: Pressing DOWN button.", $time);
        tb_btn_down_raw_in = 1'b1;
        #(BTN_PRESS_DURATION_NS);
        tb_btn_down_raw_in = 1'b0;
        #(CLK_PERIOD_NS);
        $display("[%0t ns] TB: DOWN button processed. Snake direction should be DOWN.", $time);

        // --- 5. Game Tick 2: Snake moves DOWN. Expected Head: (10,10) (back to start X,Y) ---
        $display("[%0t ns] TB: Waiting for 2nd game tick (snake moves DOWN).", $time);
        #(ONE_GAME_TICK_NS + 100 * CLK_PERIOD_NS);

        // --- 6. Game Tick 3: Snake moves DOWN. Expected Head: (10,11) ---
        $display("[%0t ns] TB: Waiting for 3rd game tick (snake moves DOWN).", $time);
        #(ONE_GAME_TICK_NS + 100 * CLK_PERIOD_NS);

        // --- 7. Game Tick 4: Snake moves DOWN. Expected Head: (10,12) - EATS FOOD! ---
        $display("[%0t ns] TB: Waiting for 4th game tick (snake moves DOWN to EAT FOOD at (10,12)).", $time);
        #(ONE_GAME_TICK_NS + 100 * CLK_PERIOD_NS);
        $display("[%0t ns] TB: FOOD SHOULD BE EATEN NOW! Score should increment. New food should generate.", $time);

        // --- 8. Wait to observe food regeneration and score update ---
        $display("[%0t ns] TB: Waiting for 2 more game ticks to observe changes...", $time);
        #(2 * ONE_GAME_TICK_NS + 100 * CLK_PERIOD_NS);

        $display("[%0t ns] TB: Debugging Food/Score Test Finished.", $time);
        $finish;
    end
endmodule