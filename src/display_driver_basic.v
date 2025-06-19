module display_driver_basic(
    input clk,
    input rst_n,
    input [15:0] sc,
    input [1:0] state,
    output [3:0] an,
    output [7:0] seg,
    output [7:0] led
);
    wire [15:0] bcd_sc;
    reg [15:0] sc_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sc_reg <= 16'b0;
        else sc_reg <= sc;
    end
    bin2bcd score_converter(
        .bin(sc_reg),
        .bcd(bcd_sc)
    );
    reg [15:0] bcd_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) bcd_reg <= 16'b0;
        else bcd_reg <= bcd_sc;
    end
    reg [1:0] rst_sync = 2'b11;
    wire rst_act;
    always @(posedge clk) begin
        rst_sync <= {rst_sync[0], rst_n};
    end
    assign rst_act = ~rst_sync[1];
    DisplayNumber display_controller(
        .clk(clk),
        .rst(rst_act),
        .hexs(bcd_reg),
        .points(4'b0000),
        .LEs(4'b0000),
        .AN(an),
        .SEGMENT(seg)
    );
    reg [7:0] led_state;
    always @(*) begin
        case(state)
            2'b00: led_state = 8'b00000000;
            2'b01: led_state = 8'b11111111;
            2'b10: led_state = 8'b11000011;
            2'b11: led_state = 8'b00111100;
            default: led_state = 8'b00000001;
        endcase
    end
    assign led = led_state;
endmodule