//============================================================================
// Pinball Action - FG tilemap renderer
// (BRAM-pipelined: plane ROMs are external dprams in pbaction.sv)
//============================================================================

module pbaction_fg (
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
    output wire [12:0] rom_raddr,
    input  wire  [7:0] rom_p0_q,
    input  wire  [7:0] rom_p1_q,
    input  wire  [7:0] rom_p2_q,

    output reg   [7:0] pen,
    output wire        transparent
);

localparam signed [9:0] FLIP_FG_X_BASE      =  10'sd16;
localparam signed [9:0] FLIP_FG_Y_BASE      = -10'sd2;
localparam signed [9:0] NORMAL_SCREEN_X_ADJ =  10'sd16;

// Foreground prefetch and wrap handling
//
// The FG pipeline fetches one pixel ahead near the end of each line and
// wraps the leftmost active pixel to the final source position

wire fg_prefetch = (hcnt >= 10'd382);

wire fg_native_left_active = (hcnt == 10'd0);

wire [9:0] fg_wrap_src = 10'd255;

wire [9:0] fg_hcnt_lookup =
    fg_prefetch           ? (hcnt - 10'd382) :
    fg_native_left_active ? fg_wrap_src :
                            hcnt;

wire [8:0] fg_vcnt_lookup =
    fg_prefetch
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
    $signed({2'b00, fg_hcnt_lookup[7:0]})
    - (flip ? (FLIP_FG_Y_BASE + y_adj_s10) : y_adj_s10);

wire signed [9:0] py_screen_s =
    $signed({2'b00, fg_vcnt_lookup[7:0]})
    - (flip ? (FLIP_FG_X_BASE + x_adj_s10) : x_adj_s10)
    + (!flip ? NORMAL_SCREEN_X_ADJ : 10'sd0);

wire [7:0] px_raw = px_screen_s[7:0];
wire [7:0] py_raw = py_screen_s[7:0];

wire [7:0] px = flip ? (8'd255 - px_raw) : px_raw;
wire [7:0] py = flip ? (8'd223 - py_raw) : py_raw;

// Apply playfield scroll to the foreground layer

wire [7:0] px_eff = px + bg_scroll;
wire [7:0] py_eff = py;

// Tile and pixel coordinates

wire [4:0] tile_col = px_eff[7:3];
wire [4:0] tile_row = py_eff[7:3];

wire [2:0] tile_px_raw = px_eff[2:0];
wire [2:0] tile_py_raw = py_eff[2:0];

// Drive RAM read addresses

assign tile_raddr  = {tile_row, tile_col};
assign color_raddr = {tile_row, tile_col};

wire [7:0] tile_idx   = tile_q;
wire [7:0] color_attr = color_q;

//================================================================
// Graphics ROM address
//================================================================
//
// FG attribute format:
//   bits [5:4] = tile code high bits
//   bit  6     = flip X
//   bit  7     = flip Y

wire [2:0] tile_px = color_attr[6] ? (3'd7 - tile_px_raw) : tile_px_raw;
wire [2:0] tile_py = color_attr[7] ? (3'd7 - tile_py_raw) : tile_py_raw;

assign rom_raddr = {color_attr[5:4], tile_idx, tile_py};

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

// Foreground is 3bpp
// Attribute bits select the palette bank and pixel bits select the color

wire [2:0] pix_idx_w = {plane0_bit, plane1_bit, plane2_bit};
wire [7:0] pen_out   = {1'b0, color_attr_d1[3:0], pix_idx_w};

// Pen 0 is transparent

wire transp_int = (pix_idx_w == 3'd0);

//================================================================
// Registered output stage
//================================================================

reg transp_r;

always @(posedge clk_sys) begin
    if (ce_pix) begin
        pen      <= pen_out;
        transp_r <= transp_int;
    end
end

assign transparent = transp_r;

endmodule