module PS2(
	input clk, reset,
	input ps2_clk_in, ps2_data_in,
	output reg [1:0] key_direction_out,
    output reg key_direction_valid_out,
    output reg key_start_pause_event_out,
    output reg key_reset_event_out,
    output reg enter,
    output reg esc
	);

reg ps2_clk_falg0, ps2_clk_falg1, ps2_clk_falg2;
wire negedge_ps2_clk = !ps2_clk_falg1 & ps2_clk_falg2;
reg negedge_ps2_clk_shift;
reg [9:0] data;
reg data_break, data_done, data_expand;
reg[7:0]temp_data;
reg[3:0]num;

always@(posedge clk or posedge reset)begin
	if(reset)begin
		ps2_clk_falg0<=1'b0;
		ps2_clk_falg1<=1'b0;
		ps2_clk_falg2<=1'b0;
	end
	else begin
		ps2_clk_falg0<=ps2_clk_in;
		ps2_clk_falg1<=ps2_clk_falg0;
		ps2_clk_falg2<=ps2_clk_falg1;
	end
end

always@(posedge clk or posedge reset)begin
	if(reset)
		num<=4'd0;
	else if (num==4'd11)
		num<=4'd0;
	else if (negedge_ps2_clk)
		num<=num+1'b1;
end

always@(posedge clk)begin
	negedge_ps2_clk_shift<=negedge_ps2_clk;
end


always@(posedge clk or posedge reset)begin
	if(reset)
		temp_data<=8'd0;
	else if (negedge_ps2_clk_shift)begin
		case(num)
			4'd2 : temp_data[0]<=ps2_data_in;
			4'd3 : temp_data[1]<=ps2_data_in;
			4'd4 : temp_data[2]<=ps2_data_in;
			4'd5 : temp_data[3]<=ps2_data_in;
			4'd6 : temp_data[4]<=ps2_data_in;
			4'd7 : temp_data[5]<=ps2_data_in;
			4'd8 : temp_data[6]<=ps2_data_in;
			4'd9 : temp_data[7]<=ps2_data_in;
			default: temp_data<=temp_data;
		endcase
	end
	else temp_data<=temp_data;
end

always@(posedge clk or posedge reset)begin
	if(reset)begin
		data_break<=1'b0;
		data<=10'd0;
		data_done<=1'b0;
		data_expand<=1'b0;
	end
	else if(num==4'd11)begin
		if(temp_data==8'hE0)begin
			data_expand<=1'b1;
		end
		else if(temp_data==8'hF0)begin
			data_break<=1'b1;
		end
		else begin
			data<={data_expand,data_break,temp_data};
			data_done<=1'b1;
			data_expand<=1'b0;
			data_break<=1'b0;
		end
	end
	else begin
		data<=data;
		data_done<=1'b0;
		data_expand<=data_expand;
		data_break<=data_break;
	end
end

always @(posedge clk) begin
	case (data)
        10'h01D: begin key_direction_out <= 2'b00; key_direction_valid_out <= 1; end
        10'h11D: begin key_direction_out <= 2'b00; key_direction_valid_out <= 0; end
        10'h01B: begin key_direction_out <= 2'b01; key_direction_valid_out <= 1; end
        10'h11B: begin key_direction_out <= 2'b01; key_direction_valid_out <= 0; end
        10'h01C: begin key_direction_out <= 2'b10; key_direction_valid_out <= 1; end
        10'h11C: begin key_direction_out <= 2'b10; key_direction_valid_out <= 0; end
        10'h023: begin key_direction_out <= 2'b11; key_direction_valid_out <= 1; end
        10'h123: begin key_direction_out <= 2'b11; key_direction_valid_out <= 0; end
        10'h029: key_start_pause_event_out <= 1;
        10'h129: key_start_pause_event_out <= 0;
        10'h00D: key_reset_event_out <= 1;
        10'h10D: key_reset_event_out <= 0;
        10'h275: begin key_direction_out <= 2'b00; key_direction_valid_out <= 1; end
        10'h375: begin key_direction_out <= 2'b00; key_direction_valid_out <= 0; end
        10'h272: begin key_direction_out <= 2'b01; key_direction_valid_out <= 1; end
        10'h372: begin key_direction_out <= 2'b01; key_direction_valid_out <= 0; end
        10'h26B: begin key_direction_out <= 2'b10; key_direction_valid_out <= 1; end
        10'h36B: begin key_direction_out <= 2'b10; key_direction_valid_out <= 0; end
        10'h274: begin key_direction_out <= 2'b11; key_direction_valid_out <= 1; end
        10'h374: begin key_direction_out <= 2'b11; key_direction_valid_out <= 0; end
        10'h05A: enter <= 1;
        10'h15A: enter <= 0;
        10'h076: esc <= 1;
        10'h176: esc <= 0;
        default:key_direction_valid_out <= 0;
    endcase
end

endmodule