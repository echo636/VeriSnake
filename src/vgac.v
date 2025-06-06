module vgac (vga_clk,clrn,d_in,row_addr,col_addr,rdn,r,g,b,hs,vs); // vgac
   input     [11:0] d_in;     // bbbb_gggg_rrrr, pixel
   input            vga_clk;  // 25MHz
   input            clrn;
   output reg [8:0] row_addr; // pixel ram row address, 480 lines
   output reg [9:0] col_addr; // pixel ram col address, 640 pixels
   output reg [3:0] r,g,b; // red, green, blue colors
   output reg       rdn;      // read pixel RAM (active_low)
   output reg       hs,vs;    // horizontal and vertical synchronization

   // h_count: VGA horizontal counter (0-799)
   reg [9:0] h_count; // VGA horizontal counter (0-799): pixels
   always @ (posedge vga_clk or negedge clrn) begin
       if (!clrn) begin
           h_count <= 10'h0;
       end else if (h_count == 10'd799) begin
           h_count <= 10'h0;
       end else begin 
           h_count <= h_count + 10'h1;
       end
   end

   // v_count: VGA vertical counter (0-524)
   reg [9:0] v_count; // VGA vertical counter (0-524): lines
   always @ (posedge vga_clk or negedge clrn) begin
       if (!clrn) begin
           v_count <= 10'h0;
       end else if (h_count == 10'd799) begin
           if (v_count == 10'd524) begin
               v_count <= 10'h0;
           end else begin
               v_count <= v_count + 10'h1;
           end
       end
   end

    // 修复地址计算 - 确保不会下溢
    wire [9:0] row_raw = v_count - 10'd35;     
    wire [9:0] col_raw = h_count - 10'd144;    

    // 只在有效显示区域内计算正确的地址
    wire [8:0] row_valid = (v_count >= 10'd35 && v_count <= 10'd514) ? 
                          (v_count - 10'd35) : 9'd0;
    wire [9:0] col_valid = (h_count >= 10'd144 && h_count <= 10'd783) ? 
                          (h_count - 10'd144) : 10'd0;

    wire h_sync = (h_count > 10'd95);    //  96 -> 799
    wire v_sync = (v_count > 10'd1);     //   2 -> 524
    wire read   = (h_count >= 10'd144) && // 144 -> 783 (修改为>=)
                  (h_count <= 10'd783) && //        640 pixels
                  (v_count >= 10'd35)  && //  35 -> 514 (修改为>=)
                  (v_count <= 10'd514);   //        480 lines

    // vga signals
    always @ (posedge vga_clk) begin
        row_addr <= row_valid;     // 使用修复后的行地址
        col_addr <= col_valid;     // 使用修复后的列地址
        rdn      <= ~read;         // read pixel (active low)
        hs       <= h_sync;        // horizontal synchronization
        vs       <= v_sync;        // vertical synchronization
        r        <= rdn ? 4'h0 : d_in[3:0];  // 4-bit red
        g        <= rdn ? 4'h0 : d_in[7:4];  // 4-bit green
        b        <= rdn ? 4'h0 : d_in[11:8]; // 4-bit blue
    end
endmodule