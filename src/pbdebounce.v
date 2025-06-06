module pbdebounce(
    input wire clk,
    input wire button, 
    output reg pbreg = 1'b0
    );

    reg [7:0] pbshift = 8'h00;

    always@(posedge clk) begin
        pbshift <= {pbshift[6:0], button};
        if (pbshift == 8'b0) begin
            pbreg <= 1'b0;
        end
        else if (pbshift == 8'hFF) begin
            pbreg <= 1'b1;    
        end
    end
endmodule