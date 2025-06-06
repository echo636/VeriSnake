module game_logic_controller #(
    parameter N = 16,
    parameter M = 2,
    parameter INITIAL_SPEED = 26'd50_000_000,
    parameter SPEED_INCREMENT = 26'd20_000_000//此处进行了暂时的修改
)(
    // 时钟和复位
    input wire clk,
    // --- 修正点 1: 修改全局复位端口为低电平有效 ---
    input wire reset_global_n, // <--- 从 reset_global 改为 reset_global_n

    // 来自输入处理器的信号
    input wire [1:0] direction_in,
    input wire direction_valid_in,
    input wire start_pause_event_in,
    input wire reset_event_in,       // 这个通常是一个高电平有效的事件脉冲

    // ... (其他端口不变) ...
    input wire food_eaten_in,
    input wire collision_in,
    input wire game_tick_in,
    output reg [1:0] game_state_out,
    output reg snake_move_cmd_out,
    output reg snake_grow_cmd_out,
    output reg generate_food_cmd_out,
    output reg [N-1:0] current_score_out,
    output reg reset_data_manager_cmd_out,
    output reg [M-1:0] sound_event_code_out,
    output reg sound_trigger_out
);

    // ... (localparam 定义不变) ...
    localparam STATE_IDLE      = 2'b00;
    localparam STATE_PLAYING   = 2'b01;
    localparam STATE_PAUSED    = 2'b10;
    localparam STATE_GAME_OVER = 2'b11;
    localparam DIR_UP          = 2'b00;
    localparam DIR_DOWN        = 2'b01;
    localparam DIR_LEFT        = 2'b10;
    localparam DIR_RIGHT       = 2'b11;
    localparam SOUND_EAT_FOOD  = 2'b01;
    localparam SOUND_GAME_OVER = 2'b10;
    localparam SOUND_GAME_START= 2'b11;

    // --- 修正点 2: 修改内部复位信号的生成逻辑 ---
    // 当全局复位 reset_global_n 为低(0)，或者 reset_event_in (高有效脉冲) 为高(1)时，
    // sys_reset_active 变为高电平，触发复位。
    wire sys_reset_active = !reset_global_n || reset_event_in; // <--- 修改这里的逻辑

    // ... (内部寄存器和标志位定义不变) ...
    reg [1:0] current_state, next_state;
    reg [1:0] current_direction, next_direction;
    reg [N-1:0] score, next_score;
    reg [25:0] speed_counter;
    reg [25:0] current_speed;
    reg game_tick_internal;
    reg game_tick_delayed;
    reg direction_changed;
    reg food_eaten_reg;
    reg collision_reg;
    reg start_pause_pressed;
    reg food_eaten_prev;
    reg collision_prev;
    reg start_pause_prev;
    reg snake_move_cmd_next;
    reg snake_grow_cmd_next;
    reg generate_food_cmd_next;
    reg reset_data_manager_cmd_next;
    reg [M-1:0] sound_event_code_next;
    reg sound_trigger_next;

    // 边沿检测逻辑
    // --- 修正点 3: 修改所有 always 块中的复位判断条件 ---
    always @(posedge clk) begin
        if (sys_reset_active) begin // <--- 使用新的 sys_reset_active
            food_eaten_prev <= 1'b0;
            collision_prev <= 1'b0;
            start_pause_prev <= 1'b0;
            food_eaten_reg <= 1'b0;
            collision_reg <= 1'b0;
            start_pause_pressed <= 1'b0;
        end else begin
            food_eaten_prev <= food_eaten_in;
            collision_prev <= collision_in;
            start_pause_prev <= start_pause_event_in;
            food_eaten_reg <= food_eaten_in & ~food_eaten_prev;
            collision_reg <= collision_in & ~collision_prev;
            start_pause_pressed <= start_pause_event_in & ~start_pause_prev;
        end
    end

    // 游戏时钟分频器
    always @(posedge clk) begin
        if (sys_reset_active) begin // <--- 使用新的 sys_reset_active
            speed_counter <= 26'd0;
            game_tick_internal <= 1'b0;
            game_tick_delayed <= 1'b0;
            current_speed <= INITIAL_SPEED;
        end else if (current_state == STATE_PLAYING) begin
            game_tick_delayed <= game_tick_internal;
            if (speed_counter >= current_speed - 1) begin
                speed_counter <= 26'd0;
                game_tick_internal <= 1'b1;
            end else begin
                speed_counter <= speed_counter + 1;
                game_tick_internal <= 1'b0;
            end
        end else begin
            speed_counter <= 26'd0;
            game_tick_internal <= 1'b0;
            game_tick_delayed <= 1'b0;
        end
    end

    // 状态机时序逻辑
    always @(posedge clk) begin
        if (sys_reset_active) begin // <--- 使用新的 sys_reset_active
            current_state <= STATE_IDLE;
            current_direction <= DIR_UP;
            score <= {N{1'b0}};
            direction_changed <= 1'b0;
        end else begin
            current_state <= next_state;
            current_direction <= next_direction;
            score <= next_score;
            if (direction_valid_in && (direction_in != current_direction)) begin
                direction_changed <= 1'b1;
            end else begin
                direction_changed <= 1'b0;
            end
        end
    end

    // 状态机组合逻辑 (这部分不需要修改复位，因为它不直接使用复位信号)
    always @(*) begin
        // ... (内部逻辑不变) ...
        next_state = current_state;
        next_direction = current_direction;
        next_score = score;
        snake_move_cmd_next = 1'b0;
        snake_grow_cmd_next = 1'b0;
        generate_food_cmd_next = 1'b0;
        reset_data_manager_cmd_next = 1'b0;
        sound_event_code_next = 2'b00;
        sound_trigger_next = 1'b0;

        case (current_state)
            STATE_IDLE: begin
                if (start_pause_pressed) begin
                    next_state = STATE_PLAYING;
                    reset_data_manager_cmd_next = 1'b1;
                    generate_food_cmd_next = 1'b1;
                    next_score = {N{1'b0}};
                    next_direction = DIR_UP;
                    sound_event_code_next = SOUND_GAME_START;
                    sound_trigger_next = 1'b1;
                end
            end
            STATE_PLAYING: begin
                if (start_pause_pressed) begin
                    next_state = STATE_PAUSED;
                end else if (collision_reg) begin
                    next_state = STATE_GAME_OVER;
                    sound_event_code_next = SOUND_GAME_OVER;
                    sound_trigger_next = 1'b1;
                end else begin
                    if (direction_valid_in) begin
                        case (current_direction)
                            DIR_UP:    if (direction_in != DIR_DOWN)  next_direction = direction_in;
                            DIR_DOWN:  if (direction_in != DIR_UP)    next_direction = direction_in;
                            DIR_LEFT:  if (direction_in != DIR_RIGHT) next_direction = direction_in;
                            DIR_RIGHT: if (direction_in != DIR_LEFT)  next_direction = direction_in;
                        endcase
                    end
                    if (game_tick_internal) begin
                        snake_move_cmd_next = 1'b1;
                    end
                    if (food_eaten_reg) begin
                        snake_grow_cmd_next = 1'b1;
                        generate_food_cmd_next = 1'b1;
                        next_score = score + 1;
                        sound_event_code_next = SOUND_EAT_FOOD;
                        sound_trigger_next = 1'b1;
                    end
                end
            end
            STATE_PAUSED: begin
                if (start_pause_pressed) begin
                    next_state = STATE_PLAYING;
                end
            end
            STATE_GAME_OVER: begin
                if (start_pause_pressed) begin
                    next_state = STATE_IDLE;
                end
            end
            default: begin
                next_state = STATE_IDLE;
            end
        endcase
    end

    // 根据分数动态调整游戏速度
    always @(posedge clk) begin
        if (sys_reset_active) begin // <--- 使用新的 sys_reset_active
            current_speed <= INITIAL_SPEED;
        end else if (current_state == STATE_PLAYING && food_eaten_reg) begin
            if (current_speed > SPEED_INCREMENT + 26'd10_000_000) begin
                current_speed <= current_speed - SPEED_INCREMENT;
            end
        end
    end

    // 输出赋值
    always @(posedge clk) begin
        if (sys_reset_active) begin // <--- 使用新的 sys_reset_active
            game_state_out <= STATE_IDLE;
            snake_move_cmd_out <= 1'b0;
            snake_grow_cmd_out <= 1'b0;
            generate_food_cmd_out <= 1'b0;
            current_score_out <= {N{1'b0}};
            reset_data_manager_cmd_out <= 1'b0;
            sound_event_code_out <= 2'b00;
            sound_trigger_out <= 1'b0;
        end else begin
            game_state_out <= next_state;
            snake_move_cmd_out <= snake_move_cmd_next;
            snake_grow_cmd_out <= snake_grow_cmd_next;
            generate_food_cmd_out <= generate_food_cmd_next;
            current_score_out <= next_score;
            reset_data_manager_cmd_out <= reset_data_manager_cmd_next;
            sound_event_code_out <= sound_event_code_next;
            sound_trigger_out <= sound_trigger_next;
        end
    end

    // ... (initial 块不变，仅用于仿真) ...
    initial begin
        // ...
    end

endmodule