module bin2bcd(
    input  [15:0] bin,
    output reg [15:0] bcd
);

    integer i;
    reg [31:0] shift_reg;

    always @(*) begin
        shift_reg = {16'b0, bin};

        for (i = 0; i < 16; i = i + 1) begin
            if (shift_reg[31:28] >= 5)
                shift_reg[31:28] = shift_reg[31:28] + 3;
            if (shift_reg[27:24] >= 5)
                shift_reg[27:24] = shift_reg[27:24] + 3;
            if (shift_reg[23:20] >= 5)
                shift_reg[23:20] = shift_reg[23:20] + 3;
            if (shift_reg[19:16] >= 5)
                shift_reg[19:16] = shift_reg[19:16] + 3;

            shift_reg = shift_reg << 1;
        end

        bcd = shift_reg[31:16];
    end

endmodule
