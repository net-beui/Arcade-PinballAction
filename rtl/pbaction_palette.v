//============================================================================
// Pinball Action - Palette Lookup
//
// Palette RAM occupies E400-E5FF and stores 256 colors as two bytes
//
//   byte 0: xxxxBBBB
//   byte 1: GGGGRRRR
//
// Resulting RGB output:
//   R = byte1[3:0]
//   G = byte1[7:4]
//   B = byte0[3:0]
//============================================================================

module pbaction_palette (
    input  wire        clk_sys,
    input  wire        ce_pix,
    input  wire  [7:0] pen,
    input  wire  [7:0] palette_ram [0:511],
    input  wire        blank,
    output reg   [3:0] R,
    output reg   [3:0] G,
    output reg   [3:0] B
);

//================================================================
// Palette lookup
//================================================================
wire [8:0] pal_addr_lo = {pen, 1'b0};
wire [8:0] pal_addr_hi = {pen, 1'b1};

wire [7:0] pal_lo = palette_ram[pal_addr_lo];
wire [7:0] pal_hi = palette_ram[pal_addr_hi];

// Force blanking and pen 0 to black
wire force_black = blank || (pen == 8'h00);

// Palette word format:
//
//   xxxx BBBB GGGG RRRR
//
// Palette RAM is byte-addressed:
//
//   pal_lo = GGGG RRRR
//   pal_hi = xxxx BBBB
//
// Therefore:
//
//   R = pal_lo[3:0]
//   G = pal_lo[7:4]
//   B = pal_hi[3:0]
wire [3:0] r_out = force_black ? 4'd0 : pal_lo[3:0];
wire [3:0] g_out = force_black ? 4'd0 : pal_lo[7:4];
wire [3:0] b_out = force_black ? 4'd0 : pal_hi[3:0];

//================================================================
// Registered RGB output
//================================================================
always @(posedge clk_sys) begin
    if (ce_pix) begin
        R <= r_out;
        G <= g_out;
        B <= b_out;
    end
end

endmodule