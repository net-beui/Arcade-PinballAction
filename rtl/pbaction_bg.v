//============================================================================
// Pinball Action - BG tilemap renderer
// (BRAM-pipelined: plane ROMs are external dprams in pbaction.sv)
//============================================================================
module pbaction_bg (
    input  wire        clk_sys,
    input  wire        ce_pix,
    input  wire  [9:0] hcnt,
    input  wire  [8:0] vcnt,
    input  wire        flip,
    input  wire signed [8:0] x_adj,
    input  wire signed [8:0] y_adj,
    input  wire  [7:0] bg_scroll,
    output wire  [9:0] tile_raddr,
    input  wire  [7:0] tile_q,
    output wire  [9:0] color_raddr,
    input  wire  [7:0] color_q,

    // Plane ROM interface
    output wire [13:0] rom_raddr,
    input  wire  [7:0] rom_p0_q,
    input  wire  [7:0] rom_p1_q,
    input  wire  [7:0] rom_p2_q,
    input  wire  [7:0] rom_p3_q,

    output reg   [7:0] pen,
    output reg         transparent
);

localparam signed [9:0] FLIP_BG_X_BASE    = 10'sd16;
localparam signed [9:0] FLIP_BG_Y_BASE    = -10'sd2;
localparam signed [9:0] NONFLIP_BG_X_BASE = 10'sd16;

// Background prefetch handling
//
// During the final two HBlank pixels, prefetch native hcnt 0/1 using
// the next scanline vcnt
wire bg_prefetch = (hcnt >= 10'd382);

wire [9:0] bg_hcnt_lookup =
    bg_prefetch ? (hcnt - 10'd382) : hcnt;

wire [8:0] bg_vcnt_lookup =
    bg_prefetch
        ? ((vcnt == 9'd263) ? 9'd0 : (vcnt + 9'd1))
        : vcnt;

//================================================================
// Screen-space coordinate adjustment
//
// Alignment offsets are supplied by the top level. Flip mode uses
// separate baselines to compensate for the rotated coordinate system
//================================================================

wire signed [9:0] y_adj_s10 = $signed({y_adj[8], y_adj});
wire signed [9:0] x_adj_s10 = $signed({x_adj[8], x_adj});

wire signed [9:0] px_screen_s =
    $signed({2'b00, bg_hcnt_lookup[7:0]})
    - (flip
        ? (FLIP_BG_Y_BASE + y_adj_s10)
        : y_adj_s10);

wire signed [9:0] py_screen_s =
    $signed({2'b00, bg_vcnt_lookup[7:0]})
    - (flip ? (FLIP_BG_X_BASE + x_adj_s10) : x_adj_s10)
    + (!flip ? NONFLIP_BG_X_BASE : 10'sd0);

wire [7:0] px_screen = px_screen_s[7:0];
wire [7:0] py_screen = py_screen_s[7:0];

wire [7:0] px_base = flip ? (8'd255 - px_screen) : px_screen;
wire [7:0] py      = flip ? (8'd223 - py_screen) : py_screen;

// Apply playfield scroll to the background layer
wire [7:0] px = px_base + bg_scroll;

// Tile and pixel coordinates
wire [4:0] tile_col    = px[7:3];
wire [4:0] tile_row    = py[7:3];
wire [2:0] tile_px     = px[2:0];
wire [2:0] tile_py_raw = py[2:0];

// Drive RAM read addresses
assign tile_raddr  = {tile_row, tile_col};
assign color_raddr = {tile_row, tile_col};

wire [7:0] tile_idx   = tile_q;
wire [7:0] color_attr = color_q;

//================================================================
// Graphics ROM address
//================================================================
//
// BG is 4bpp with an 11-bit tile code
//   tile RAM        = tile code bits [7:0]
//   color RAM [6:4] = tile code bits [10:8]
//   color RAM [7]   = flip Y
wire [10:0] tile_code = {color_attr[6:4], tile_idx};
wire  [2:0] tile_py   = color_attr[7] ? (3'd7 - tile_py_raw) : tile_py_raw;

assign rom_raddr = {tile_code, tile_py};

//================================================================
// Pipeline alignment
//
// Tile/color RAM and graphics ROM are pipelined. Delay tile_px and
// color_attr so bit select and palette bank align with the ROM output
//================================================================
reg [2:0] tile_px_d1;
reg [7:0] color_attr_d1;

always @(posedge clk_sys) begin
    tile_px_d1    <= tile_px;
    color_attr_d1 <= color_attr;
end

//================================================================
// Pixel decode
//================================================================
wire plane0_bit = rom_p0_q[3'd7 - tile_px_d1];
wire plane1_bit = rom_p1_q[3'd7 - tile_px_d1];
wire plane2_bit = rom_p2_q[3'd7 - tile_px_d1];
wire plane3_bit = rom_p3_q[3'd7 - tile_px_d1];

wire [3:0] pix_idx = {plane0_bit, plane1_bit, plane2_bit, plane3_bit};

// Background is 4bpp
// Attribute bits select the palette bank and pixel bits select the color
wire [7:0] pen_out  = {1'b1, color_attr_d1[2:0], pix_idx};
// Pen 0 is transparent
wire transp_w = (pix_idx == 4'd0);

//================================================================
// Registered output stage
//================================================================
always @(posedge clk_sys) begin
    if (ce_pix) begin
        pen         <= pen_out;
        transparent <= transp_w;
    end
end

endmodule