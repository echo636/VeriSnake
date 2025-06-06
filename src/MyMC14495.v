module MyMC14495(
  input D0, D1, D2, D3,
  input LE,
  input point,
  output reg p,
  output reg a, b, c, d, e, f, g
);
  
  always @(*) begin
    if (LE) begin
      {a, b, c, d, e, f, g} = 7'b1111111;
      p = 1'b1; 
    end else begin
      case ({D3, D2, D1, D0})
        4'b0000: {a, b, c, d, e, f, g} = 7'b0000001; 
        4'b0001: {a, b, c, d, e, f, g} = 7'b1001111; 
        4'b0010: {a, b, c, d, e, f, g} = 7'b0010010; 
        4'b0011: {a, b, c, d, e, f, g} = 7'b0000110; 
        4'b0100: {a, b, c, d, e, f, g} = 7'b1001100; 
        4'b0101: {a, b, c, d, e, f, g} = 7'b0100100; 
        4'b0110: {a, b, c, d, e, f, g} = 7'b0100000; 
        4'b0111: {a, b, c, d, e, f, g} = 7'b0001111; 
        4'b1000: {a, b, c, d, e, f, g} = 7'b0000000; 
        4'b1001: {a, b, c, d, e, f, g} = 7'b0000100; 
        4'b1010: {a, b, c, d, e, f, g} = 7'b0001000; 
        4'b1011: {a, b, c, d, e, f, g} = 7'b1100000; 
        4'b1100: {a, b, c, d, e, f, g} = 7'b0110001; 
        4'b1101: {a, b, c, d, e, f, g} = 7'b1000010; 
        4'b1110: {a, b, c, d, e, f, g} = 7'b0110000; 
        4'b1111: {a, b, c, d, e, f, g} = 7'b0111000; 
        default: {a, b, c, d, e, f, g} = 7'b1111111; 
      endcase
      
      p = ~point;
    end
  end
  
endmodule

