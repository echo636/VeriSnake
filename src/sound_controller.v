// ���������� (��������λ�߼�)
module sound_controller #(
    parameter M = 2,
    parameter CLK_FREQ = 50000000 
)(
    input wire clk,
    input wire reset_n, // <--- ������1: �˿�����Ϊ����Ч�� reset_n
    input wire [M-1:0] sound_event_code_in,
    input wire sound_trigger_in,
    output reg buzzer_out
);

    // ... (localparam �� reg/wire ���屣�ֲ���) ...
    localparam EVENT_NONE      = 2'b00;
    localparam EVENT_EAT_FOOD  = 2'b01;
    localparam EVENT_GAME_OVER = 2'b10;
    localparam EVENT_START     = 2'b11;
    // ...
    typedef enum logic [1:0] { IDLE, PLAY } sound_state_t;
    sound_state_t state;
    // ... (���� tone_*, play_*, pwm_* �Ĵ�����������) ...
    reg [31:0] tone_freq;
    reg [31:0] tone_period;
    reg [31:0] play_duration;
    reg [31:0] play_cnt;
    reg [31:0] pwm_cnt;

    // �¼�����ѡ���߼� (�ⲿ��������߼������ܸ�λӰ�죬�����޸�)
    always @(*) begin
        // ... (case ��䱣�ֲ���) ...
        case (sound_event_code_in)
            EVENT_EAT_FOOD: begin
                tone_freq     = FREQ_EAT_FOOD;
                play_duration = DURATION_EAT_FOOD;
            end
            EVENT_GAME_OVER: begin
                tone_freq     = FREQ_GAME_OVER;
                play_duration = DURATION_GAME_OVER;
            end
            EVENT_START: begin
                tone_freq     = FREQ_START;
                play_duration = DURATION_START;
            end
            default: begin
                tone_freq     = 0;
                play_duration = 0;
            end
        endcase
        tone_period = (tone_freq == 0) ? 32'd0 : (CLK_FREQ / (tone_freq * 2)); 
    end

    // ��״̬����PWM���
    // --- ������2: �޸� always ��������б�͸�λ�ж� ---
    always @(posedge clk or negedge reset_n) begin // <--- ʹ�� negedge reset_n
        if (!reset_n) begin // <--- ʹ�� !reset_n
            // ��λ��ȫ������
            state      <= IDLE;
            play_cnt   <= 0;
            pwm_cnt    <= 0;
            buzzer_out <= 0;
        end else begin
            case (state)
                IDLE: begin
                    // ... (IDLE ״̬�߼�����) ...
                    buzzer_out <= 0;
                    if (sound_trigger_in && sound_event_code_in != EVENT_NONE) begin
                        play_cnt   <= play_duration; // װ�س���ʱ��
                        pwm_cnt    <= 0;
                        state      <= PLAY;
                    end
                end
                PLAY: begin
                    // ... (PLAY ״̬�߼�����) ...
                    if (play_cnt == 0) begin
                        state      <= IDLE;
                        buzzer_out <= 0;
                    end else begin
                        if (tone_period > 0) begin
                            if (pwm_cnt < tone_period -1) begin // -1 ��������ƥ������
                                pwm_cnt <= pwm_cnt + 1;
                            end else begin
                                pwm_cnt    <= 0;
                                buzzer_out <= ~buzzer_out;
                            end
                        end else begin
                            buzzer_out <= 0;
                        end
                        play_cnt <= play_cnt - 1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule