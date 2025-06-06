module DisplaySync(
    input [1:0] scan,       
    input [15:0] hexs,    
    input [3:0] points,    
    input [3:0] LEs,      
    output [3:0] HEX,      
    output [3:0] AN,      
    output point,         
    output LE             
);

    assign HEX = (scan == 2'b00) ? hexs[3:0] :    
                 (scan == 2'b01) ? hexs[7:4] :    
                 (scan == 2'b10) ? hexs[11:8] :
                 (scan == 2'b11) ? hexs[15:12] : 
                 4'b0000;                    

    assign point = (scan == 2'b00) ? points[0] : 
                   (scan == 2'b01) ? points[1] : 
                   (scan == 2'b10) ? points[2] :  
                   (scan == 2'b11) ? points[3] :
                   1'b0;                     

    assign LE = (scan == 2'b00) ? LEs[0] :        
                (scan == 2'b01) ? LEs[1] :      
                (scan == 2'b10) ? LEs[2] :     
                (scan == 2'b11) ? LEs[3] :
                1'b0;                    

    assign AN = (scan == 2'b00) ? 4'b1110 :  
                (scan == 2'b01) ? 4'b1101 : 
                (scan == 2'b10) ? 4'b1011 :  
                (scan == 2'b11) ? 4'b0111 :
                4'b1111;                    

endmodule