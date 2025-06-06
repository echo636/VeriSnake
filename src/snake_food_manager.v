// ������ʳ�����ݹ����� (����������������)
module snake_food_manager #(
    parameter X = 6,
    parameter Y = 5,
    parameter S_LEN_W = 6,
    parameter S_ADDR_W = 6
)(
    input wire clk,
    input wire reset_cmd_in,
    input wire snake_move_cmd_in,
    input wire [1:0] current_direction_in,
    input wire generate_food_cmd_in,
    input wire [X-1:0] game_area_max_x_in, // Ӧ����ʵ�ʿ��/�߶�ֵ, e.g., 60, ������������� 59
    input wire [Y-1:0] game_area_max_y_in, // Ӧ����ʵ�ʿ��/�߶�ֵ, e.g., 40, ������������� 39
    input wire [S_ADDR_W-1:0] vga_query_segment_addr_in,

    output reg food_eaten_out,
    output reg collision_out,
    output reg [X-1:0] food_x_out,
    output reg [Y-1:0] food_y_out,
    output wire [X-1:0] snake_head_x_out,
    output wire [Y-1:0] snake_head_y_out,
    output reg [S_LEN_W-1:0] snake_length_out,
    output wire [X-1:0] queried_segment_x_out,
    output wire [Y-1:0] queried_segment_y_out,
    output wire queried_segment_valid_out
);

    localparam SNAKE_MAX_LEN = (1 << S_ADDR_W);

    reg [X-1:0] snake_x [0:SNAKE_MAX_LEN-1];
    reg [Y-1:0] snake_y [0:SNAKE_MAX_LEN-1];
    reg [S_ADDR_W-1:0] head_ptr;
    reg [X+Y-1:0] lfsr;
    reg [X+Y-1:0] free_run_counter; // ����λ����Ժ�lfsrһ��
    reg generating_food;

    integer i; // ģ�鼶����

    // Ϊ����ײ��ʳ������ for ѭ���ı߽��������� reg
    reg [S_LEN_W-1:0] segments_to_check_for_collide;
    reg [S_LEN_W-1:0] snake_len_for_food_check;


    wire [X-1:0] current_head_x = snake_x[head_ptr];
    wire [Y-1:0] current_head_y = snake_y[head_ptr];
    
    reg  [X-1:0] next_head_x; // ������Ϊ reg
    reg  [Y-1:0] next_head_y; // ������Ϊ reg
    wire [S_ADDR_W-1:0] next_head_ptr = head_ptr + 1;

    wire will_eat_food;
    wire will_collide_wall;
    wire will_collide_self;
    wire is_food_on_snake;
    
    // --- �Ƴ���ģ�鼶��: reg [S_ADDR_W-1:0] physical_addr; ---

    // ========== ����߼�: ������һ��״̬ ==========

    // ��� always ��ֻ��Ӧʱ�ӣ�û�и�λ����������һֱ����
    always @(posedge clk) begin
        free_run_counter <= free_run_counter + 1;
    end

    // 1. ������һ����ͷ��λ��
    always @(*) begin
        case (current_direction_in)
            2'b00: begin next_head_x = current_head_x; next_head_y = current_head_y - 1; end
            2'b01: begin next_head_x = current_head_x; next_head_y = current_head_y + 1; end
            2'b10: begin next_head_x = current_head_x - 1; next_head_y = current_head_y; end
            default: begin next_head_x = current_head_x + 1; next_head_y = current_head_y; end
        endcase
    end

    // 2. �ж���һ��λ���Ƿ���ʳ��
    assign will_eat_food = (next_head_x == food_x_out) && (next_head_y == food_y_out);

    // 3. �ж���һ��λ���Ƿ��ײǽ
    // ���� game_area_max_x_in �ǿ�� (e.g., 60), game_area_max_y_in �Ǹ߶� (e.g., 40)
    // ��Ч���귶Χ�� x: 0 to width-1, y: 0 to height-1
    assign will_collide_wall = (next_head_x > game_area_max_x_in) || (next_head_y > game_area_max_y_in) ||
                               (next_head_x < 0) || (next_head_y < 0); // �ϸ���˵���޷�����<0���ƻأ�����>=dimension�Ѱ��������

    // 4. �ж���һ��λ���Ƿ��ײ�Լ�
    reg will_collide_self_reg;
    always @(*) begin
        will_collide_self_reg = 1'b0;
        if (will_eat_food) begin // ʹ�ü���õ� will_eat_food
            segments_to_check_for_collide = snake_length_out;
        end else begin
            segments_to_check_for_collide = snake_length_out - 1;
        end
        
        for (i = 1; i < segments_to_check_for_collide; i = i + 1) begin
            // ֱ��ʹ�õ�ַ���ʽ������ֵ������� physical_addr
            if ((next_head_x == snake_x[head_ptr - i]) && (next_head_y == snake_y[head_ptr - i])) begin
                will_collide_self_reg = 1'b1;
            end
        end
    end
    assign will_collide_self = will_collide_self_reg;
    
    // 5. �ж�������ɵ�ʳ���Ƿ���������
    reg is_food_on_snake_reg;
    // ���� game_area_max_x_in ��ʵ�ʿ��/�߶�, ����ȡģ
    wire [X-1:0] rand_x_eff = (game_area_max_x_in == 0) ? 0 : (lfsr[X-1:0] % game_area_max_x_in);
    wire [Y-1:0] rand_y_eff = (game_area_max_y_in == 0) ? 0 : (lfsr[X+Y-1:X] % game_area_max_y_in);

    always @(*) begin
        is_food_on_snake_reg = 1'b0;
        snake_len_for_food_check = snake_length_out; // ��ֵ��ģ�鼶 reg
        
        for (i = 0; i < snake_len_for_food_check; i = i + 1) begin
            // ֱ��ʹ�õ�ַ���ʽ
            if ((rand_x_eff == snake_x[head_ptr - i]) && (rand_y_eff == snake_y[head_ptr - i])) begin
                is_food_on_snake_reg = 1'b1;
            end
        end
    end
    assign is_food_on_snake = is_food_on_snake_reg;

    // ========== ʱ���߼�: ״̬���� ==========
    always @(posedge clk) begin
        if (reset_cmd_in) begin
            snake_x[0] <= 8;  snake_y[0] <= 10;
            snake_x[1] <= 9;  snake_y[1] <= 10;
            snake_x[2] <= 10; snake_y[2] <= 10;
            head_ptr <= 2;
            snake_length_out <= 3;
            food_x_out <= 10;
            food_y_out <= 9;
            collision_out <= 0;
            food_eaten_out <= 0;
            //lfsr <= {X+Y{1'b1}}; 
            lfsr <= free_run_counter;
            generating_food <= 0;
        end else begin
            food_eaten_out <= 0; // Ĭ�����������ź�
            collision_out <= 0;  // Ĭ�����������ź�
            
            if (X+Y >= 5) begin // ȷ��LFSR��ͷ��Ч
                 lfsr <= {lfsr[X+Y-2:0], lfsr[X+Y-1] ^ lfsr[X+Y-5]};
            end else if (X+Y > 0) begin 
                 lfsr <= {lfsr[X+Y-2:0], lfsr[X+Y-1] ^ lfsr[0]}; // �򻯵�LFSR�����̫��
            end


            if (snake_move_cmd_in) begin
                if (will_collide_wall || will_collide_self) begin
                    collision_out <= 1;
                end else begin
                    head_ptr <= next_head_ptr;
                    snake_x[next_head_ptr] <= next_head_x;
                    snake_y[next_head_ptr] <= next_head_y;

                    if (will_eat_food) begin
                        food_eaten_out <= 1;
                        if (snake_length_out < SNAKE_MAX_LEN) begin
                            snake_length_out <= snake_length_out + 1;
                        end
                    end
                end
            end
            
            if (generate_food_cmd_in || generating_food) begin
                if (!is_food_on_snake) begin
                    food_x_out <= rand_x_eff; // ʹ�ü��������Ч�������
                    food_y_out <= rand_y_eff; // ʹ�ü��������Ч�������
                    generating_food <= 0;
                end else begin
                    generating_food <= 1;
                end
            end
        end
    end

    // ========== ����߼� ==========
    assign snake_head_x_out = current_head_x;
    assign snake_head_y_out = current_head_y;

    // ΪVGA��ѯ����ר�õĵ�ַ��
    wire [S_ADDR_W-1:0] vga_lookup_physical_addr = head_ptr - vga_query_segment_addr_in;
    
    assign queried_segment_x_out = snake_x[vga_lookup_physical_addr];
    assign queried_segment_y_out = snake_y[vga_lookup_physical_addr];
    assign queried_segment_valid_out = (vga_query_segment_addr_in < snake_length_out);

endmodule