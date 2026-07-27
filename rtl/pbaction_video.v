//============================================================================
// Pinball Action - Video Subsystem
//
// Generates video timing, tilemap and sprite pixels, layer priority,
// palette lookup, and RGB video output.
//============================================================================

module pbaction_video (
    input  wire        clk_sys,
    input  wire        ce_pix,
    input  wire        reset,
    input  wire        paused,
    
    // Layer alignment offsets
   input  wire signed [8:0] fg_x_adj,
   input  wire signed [8:0] fg_y_adj,
   input  wire signed [8:0] bg_x_adj,
   input  wire signed [8:0] bg_y_adj,
   input  wire signed [8:0] spr_x_adj,
   input  wire signed [8:0] spr_y_adj,
   
   // Global video position offsets
   input  wire signed [8:0] h_pos_adj,
   input  wire signed [8:0] v_pos_adj,

    // Tile/sprite RAM (read by video, written by CPU)
    output wire  [9:0] fg_tile_raddr,
    input  wire  [7:0] fg_tile_q,
    output wire  [9:0] fg_color_raddr,
    input  wire  [7:0] fg_color_q,
    output wire  [9:0] bg_tile_raddr,
    input  wire  [7:0] bg_tile_q,
    output wire  [9:0] bg_color_raddr,
    input  wire  [7:0] bg_color_q,
    input  wire  [7:0] sprite_ram   [0:127],
    input  wire  [7:0] palette_ram  [0:511],

    // ROM data
    output wire [12:0] fg_rom_raddr,
    input  wire  [7:0] fg_rom_p0_q,
    input  wire  [7:0] fg_rom_p1_q,
    input  wire  [7:0] fg_rom_p2_q,
    output wire [13:0] bg_rom_raddr,
    input  wire  [7:0] bg_rom_p0_q,
    input  wire  [7:0] bg_rom_p1_q,
    input  wire  [7:0] bg_rom_p2_q,
    input  wire  [7:0] bg_rom_p3_q,
    output wire [12:0] spr_rom_raddr,
    input  wire  [7:0] spr_rom_p0_q,
    input  wire  [7:0] spr_rom_p1_q,
    input  wire  [7:0] spr_rom_p2_q,

    // Control
    input  wire  [7:0] bg_scroll,
    input  wire        flip,

    // Video outputs
    output wire        HBlank,
    output wire        VBlank,
    output wire        HSync,
    output wire        VSync,
    output wire  [3:0] R,
    output wire  [3:0] G,
    output wire  [3:0] B
);

//================================================================
// Video timing
//================================================================

localparam H_TOTAL     = 10'd384;
localparam H_ACTIVE    = 10'd256;
localparam H_SYNC_START= 10'd320;
localparam H_SYNC_END  = 10'd352;   // 32 pixel sync pulse

localparam V_TOTAL     = 10'd264;
localparam V_ACTIVE    = 10'd224;
localparam V_SYNC_START= 10'd240;
localparam V_SYNC_END  = 10'd244;   // 4 line sync pulse

//================================================================
// H/V counters
//================================================================

reg [9:0] hcnt;
reg [8:0] vcnt;

always @(posedge clk_sys) begin
    if (reset) begin
        hcnt <= 0;
        vcnt <= 0;
    end else if (ce_pix) begin
        if (hcnt == H_TOTAL - 1) begin
            hcnt <= 0;
            if (vcnt == V_TOTAL - 1)
                vcnt <= 0;
            else
                vcnt <= vcnt + 9'd1;
        end else begin
            hcnt <= hcnt + 10'd1;
        end
    end
end

//================================================================
// Sync and blank generation
//================================================================

// Standard active-area blanking
assign HBlank = (hcnt >= H_ACTIVE);
assign VBlank = (vcnt >= V_ACTIVE);

// Global sync position adjustment.
wire signed [10:0] h_pos_s11 = {{2{h_pos_adj[8]}}, h_pos_adj};
wire signed [10:0] v_pos_s11 = {{2{v_pos_adj[8]}}, v_pos_adj};

wire signed [10:0] h_sync_start_s = $signed({1'b0, H_SYNC_START}) + h_pos_s11;
wire signed [10:0] h_sync_end_s   = $signed({1'b0, H_SYNC_END})   + h_pos_s11;

wire signed [10:0] v_sync_start_s = $signed({2'b00, V_SYNC_START}) + v_pos_s11;
wire signed [10:0] v_sync_end_s   = $signed({2'b00, V_SYNC_END})   + v_pos_s11;

assign HSync = ($signed({1'b0, hcnt}) >= h_sync_start_s &&
                $signed({1'b0, hcnt}) <  h_sync_end_s);

assign VSync = ($signed({2'b00, vcnt}) >= v_sync_start_s &&
                $signed({2'b00, vcnt}) <  v_sync_end_s);

//================================================================
// FG tilemap pixel
//================================================================

wire [7:0] fg_pen;
wire       fg_transparent;

pbaction_fg fg (
    .clk_sys     (clk_sys),
    .ce_pix      (ce_pix),
    .hcnt        (hcnt[9:0]),
    .vcnt        (vcnt[8:0]),
    .flip        (flip),
    .x_adj       (fg_x_adj),
    .y_adj       (fg_y_adj),
    .bg_scroll   (bg_scroll),
    .tile_raddr  (fg_tile_raddr),
    .tile_q      (fg_tile_q),
    .color_raddr (fg_color_raddr),
    .color_q     (fg_color_q),
    .rom_raddr   (fg_rom_raddr),
    .rom_p0_q    (fg_rom_p0_q),
    .rom_p1_q    (fg_rom_p1_q),
    .rom_p2_q    (fg_rom_p2_q),
    .pen         (fg_pen),
    .transparent (fg_transparent)
);

//================================================================
// BG tilemap pixel
//================================================================

wire [7:0] bg_pen;
wire       bg_transparent;

pbaction_bg bg (
    .clk_sys     (clk_sys),
    .ce_pix      (ce_pix),
    .hcnt        (hcnt[9:0]),
    .vcnt        (vcnt[8:0]),
    .flip        (flip),
    .x_adj       (bg_x_adj),
    .y_adj       (bg_y_adj),
    .bg_scroll   (bg_scroll),
    .tile_raddr  (bg_tile_raddr),
    .tile_q      (bg_tile_q),
    .color_raddr (bg_color_raddr),
    .color_q     (bg_color_q),
    .rom_raddr   (bg_rom_raddr),
    .rom_p0_q    (bg_rom_p0_q),
    .rom_p1_q    (bg_rom_p1_q),
    .rom_p2_q    (bg_rom_p2_q),
    .rom_p3_q    (bg_rom_p3_q),
    .pen         (bg_pen),
    .transparent (bg_transparent)
);

//================================================================
// Sprite pixel
//================================================================

wire [7:0] spr_pen;
wire       spr_transparent;

pbaction_sprites sprites (
    .clk_sys     (clk_sys),
    .ce_pix      (ce_pix),
    .reset       (reset),
    .paused      (paused),
    .hcnt        (hcnt[9:0]),
    .vcnt        (vcnt[8:0]),
    .flip        (flip),
    .x_adj       (spr_x_adj),
    .y_adj       (spr_y_adj),
    .bg_scroll   (bg_scroll),
    .sprite_ram  (sprite_ram),
    .rom_raddr   (spr_rom_raddr),
    .rom_p0_q    (spr_rom_p0_q),
    .rom_p1_q    (spr_rom_p1_q),
    .rom_p2_q    (spr_rom_p2_q),
    .pen         (spr_pen),
    .transparent (spr_transparent)
);

reg [7:0] final_pen;

// Layer priority:
//   FG > Sprite > BG
always @(*) begin
    if (!fg_transparent)
        final_pen = fg_pen;
    else if (!spr_transparent)
        final_pen = spr_pen;
    else if (!bg_transparent)
        final_pen = bg_pen;
    else
        final_pen = 8'h00;
end

//================================================================
// Palette lookup
//================================================================

pbaction_palette pal (
    .clk_sys     (clk_sys),
    .ce_pix      (ce_pix),
    .pen         (final_pen),
    .palette_ram (palette_ram),
    .blank       (HBlank | VBlank),
    .R           (R),
    .G           (G),
    .B           (B)
);

endmodule
