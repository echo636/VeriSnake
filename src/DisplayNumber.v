module DisplayNumber(
    input        clk,
    input        rst,
    input [15:0] hexs,
    input [3:0] points,
    input [3:0] LEs,
    output [3:0] AN,
    output [7:0] SEGMENT 
);

    wire [31:0] div_res;
    wire [1:0] scan;
    wire [3:0] HEX;
    wire point;
    wire LE;
    wire p;      
    wire a, b, c, d, e, f, g; 
    
    clkdiv clkdiv_inst(
        .clk(clk),
        .rst(rst),
        .div_res(div_res)
    );
    
    assign scan = div_res[18:17];
    
    DisplaySync display_sync_inst(
        .scan(scan),
        .hexs(hexs),
        .points(points),
        .LEs(LEs),
        .HEX(HEX),
        .AN(AN),
        .point(point),
        .LE(LE)
    );
    
    MyMC14495 seg_decoder(
        .D0(HEX[0]),
        .D1(HEX[1]),
        .D2(HEX[2]),
        .D3(HEX[3]),
        .point(point),
        .LE(LE),
        .p(p),    
        .a(a),    
        .b(b), 
        .c(c),  
        .d(d),    
        .e(e),    
        .f(f),    
        .g(g)    
    );
    
    assign SEGMENT = {p, g, f, e, d, c, b, a};

endmodule