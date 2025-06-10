// image_rom.v
module image_rom #(
    parameter MEM_DEPTH = 307200, // 640 * 480
    parameter ADDR_WIDTH = 19,    // 2^19 = 524288 > 307200
    parameter DATA_WIDTH = 12,    // 12-bit color
    parameter COE_FILE = ""       // COE file path
)(
    input wire                  clk,
    input wire [ADDR_WIDTH-1:0] addr,
    output reg [DATA_WIDTH-1:0] dout
);

    // BRAM/ROM memory declaration
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // Initialize memory from COE file
    // This is a synthesis directive that tools like Vivado/Quartus understand
    initial begin
        if (COE_FILE != "") begin
            $readmemh(COE_FILE, mem);
        end
    end

    // Read operation (registered output for better timing)
    always @(posedge clk) begin
        dout <= mem[addr];
    end

endmodule