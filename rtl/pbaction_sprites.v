//============================================================================
// Pinball Action - Sprite Renderer
//
// Renders 16x16 and 32x32 sprites from E000-E07F sprite RAM using a
// double-buffered scanline renderer
//
// Sprite RAM format:
//   offs+0 = tile index, bit 7 selects 32x32 sprite
//   offs+1 = attributes, bit 7 flip Y, bit 6 flip X, bits 3:0 color bank
//   offs+2 = Y position
//   offs+3 = X position
//============================================================================

module pbaction_sprites (
    input  wire        clk_sys,
    input  wire        ce_pix,
    input  wire        reset,
    input  wire        paused,
    input  wire  [9:0] hcnt,
    input  wire  [8:0] vcnt,
    input  wire        flip,
    input  wire signed [8:0] x_adj,
    input  wire signed [8:0] y_adj,
    input  wire  [7:0] sprite_ram [0:127],
    input  wire  [7:0] bg_scroll,

    output reg  [12:0] rom_raddr,
    input  wire  [7:0] rom_p0_q,
    input  wire  [7:0] rom_p1_q,
    input  wire  [7:0] rom_p2_q,

    output reg   [7:0] pen,
    output reg         transparent
);

localparam signed [9:0] FLIP_SPR_X_BASE        = -10'sd16;

// Separate Y/raster-X flip alignment for normal vs large sprites.
// Large sprites include the title logo. Normal sprites likely include ball/flippers.
localparam signed [9:0] FLIP_SPR_Y_BIG_BASE    = -10'sd2;
localparam signed [9:0] FLIP_SPR_Y_NORMAL_BASE = -10'sd2;

localparam signed [9:0] NONFLIP_SPR_X_BASE = 10'sd16;

// Line buffers: [7]=valid, [6:0]=palette pen
reg [7:0] line_buf0 [0:255];
reg [7:0] line_buf1 [0:255];

reg display_buf;   // buffer currently being displayed
reg render_buf;    // buffer currently being rendered for next scanline

//================================================================
// State machine
//================================================================

localparam ST_IDLE     = 4'd0;
localparam ST_CLEAR    = 4'd1;
localparam ST_FETCH    = 4'd2;
localparam ST_CHECK    = 4'd3;
localparam ST_SETUP    = 4'd4;
localparam ST_ROM_WAIT = 4'd5;
localparam ST_WRITE    = 4'd6;
localparam ST_NEXT     = 4'd7;

reg [3:0] state;
reg [7:0] clear_addr;

// MAME draws from offs=124 down to 0.
// So spr_idx starts at 31 and decrements to 0.
reg [4:0] spr_idx;
reg [5:0] spr_col;       // up to 31 for double-size sprites

// Latched sprite fields
reg [7:0] spr_tile;
reg [7:0] spr_attr;
reg [7:0] spr_sy;
reg [7:0] spr_x;
reg [7:0] spr_raw_y;
reg       spr_big;

wire spr_xflip = spr_attr[6] ^ flip;
wire spr_yflip = spr_attr[7] ^ flip;

reg [4:0] spr_row;       // up to 31 for double-size sprites
reg signed [9:0] dest_x_r;
reg [2:0] bit_sel_r;

// Render target line, latched at scanline start.
// We render the next scanline while displaying the current one.
reg [7:0] target_y_r;

// Sprite screen X position
//
// Use signed 10-bit arithmetic so subtracts do not wrap in 8-bit space
wire signed [9:0] spr_x_s      = $signed({2'b00, spr_x});
wire signed [9:0] bg_scroll_s  = $signed({2'b00, bg_scroll});
wire signed [9:0] spr_flip_base =
    spr_big ? 10'sd224 : 10'sd240;

wire signed [9:0] spr_screen_x =
    flip
        ? ((spr_flip_base - spr_x_s) + bg_scroll_s)
        : (spr_x_s - bg_scroll_s);

// Do not modify vertical row selection for the ball in this test.
wire [8:0] spr_sy_eff = {1'b0, spr_sy};

// Position-only correction disabled for this test.
//
// The generic sprite X calculation now uses signed 10-bit arithmetic,
// so the old launcher-ball correction can double-correct the ball and
// move it to the opposite side of the rotated display.
//
// Test using the generic signed sprite position for all sprites,
// including the launcher/waiting ball.
wire signed [9:0] spr_screen_x_eff =
    spr_screen_x;

//================================================================
// Sprite pixel decode
//================================================================
wire p0 = rom_p0_q[bit_sel_r];
wire p1 = rom_p1_q[bit_sel_r];
wire p2 = rom_p2_q[bit_sel_r];

wire [2:0] spr_pix_idx = {p0, p1, p2};
wire [7:0] spr_pen_val = {1'b0, spr_attr[3:0], spr_pix_idx};

// Swap at hcnt=382 to align with FG/BG prefetch window
wire buf_swap = ce_pix && (hcnt == 10'd382);

integer ii;
initial begin
    for (ii = 0; ii < 256; ii = ii + 1) begin
        line_buf0[ii] = 8'd0;
        line_buf1[ii] = 8'd0;
    end
end

//================================================================
// Sprite render state machine
//================================================================

always @(posedge clk_sys) begin
    if (reset) begin
        state        <= ST_IDLE;
        clear_addr   <= 8'd0;
        spr_idx      <= 5'd31;
        spr_col      <= 6'd0;
        rom_raddr    <= 13'd0;
        display_buf  <= 1'b0;
        render_buf   <= 1'b1;
        target_y_r   <= 8'd1;
    end else if (buf_swap) begin
        // Swap buffers at the start of the scanline
        //
        // The display buffer contains the sprite line rendered during the
        // previous scanline. The newly selected render buffer is cleared and
        // rendered for the next visible scanline
        display_buf <= render_buf;
        render_buf  <= ~render_buf;

        // Render the next visible scanline
        // During line 223 and VBlank, prepare line 0 for the next frame
        target_y_r <= (vcnt[7:0] >= 8'd223) ? 8'd0 : (vcnt[7:0] + 8'd1);

         clear_addr  <= 8'd0;
         spr_idx     <= 5'd31;
         spr_col     <= 6'd0;
         state       <= ST_CLEAR;
    end else begin
        case (state)

            ST_IDLE: begin
                state <= ST_IDLE;
            end

            ST_CLEAR: begin
                if (render_buf == 1'b0)
                    line_buf0[clear_addr] <= 8'd0;
                else
                    line_buf1[clear_addr] <= 8'd0;

                clear_addr <= clear_addr + 8'd1;

                if (clear_addr == 8'hFF) begin
                    spr_idx <= 5'd31;
                    state   <= ST_FETCH;
                end
            end
           
            ST_FETCH: begin
              // Skip entries consumed by the previous lower-offset 32x32 sprite
              if (spr_idx != 5'd0 && sprite_ram[{(spr_idx - 5'd1), 2'b00}][7]) begin
              state <= ST_NEXT;
              end else begin
              spr_tile  <= sprite_ram[{spr_idx, 2'b00} + 7'd0];
              spr_attr  <= sprite_ram[{spr_idx, 2'b00} + 7'd1];
              spr_big   <= sprite_ram[{spr_idx, 2'b00} + 7'd0][7];
              spr_raw_y <= sprite_ram[{spr_idx, 2'b00} + 7'd2];
              spr_x     <= sprite_ram[{spr_idx, 2'b00} + 7'd3];

              begin : sy_calc
                   reg signed [9:0] base_sy;
                   reg signed [9:0] adj_sy;
                   reg signed [9:0] x_adj_s10;

                   x_adj_s10 = {x_adj[8], x_adj};

                   if (sprite_ram[{spr_idx, 2'b00} + 7'd0][7]) begin
                   // 32x32 sprite
                   base_sy = flip
                        ? $signed({2'b00, sprite_ram[{spr_idx, 2'b00} + 7'd2]})
                        : $signed({2'b00, (8'd225 - sprite_ram[{spr_idx, 2'b00} + 7'd2])}) + 10'sd16;
                       end else begin
                   // 16x16 sprite
                   base_sy = flip
                        ? $signed({2'b00, sprite_ram[{spr_idx, 2'b00} + 7'd2]})
                        : $signed({2'b00, (8'd241 - sprite_ram[{spr_idx, 2'b00} + 7'd2])}) + 10'sd16;
                   end

                   // Visual X maps to raster/sprite Y on the rotated display
                   // In non-flip mode, x_adj moves sprites on the same axis as FG/BG X
                   adj_sy = base_sy
                        + (flip ? (FLIP_SPR_X_BASE + x_adj_s10) : -x_adj_s10)
                        - (!flip ? NONFLIP_SPR_X_BASE : 10'sd0);

                   // Clamp out-of-range sprites using 0xFF as the invalid Y sentinel
                   spr_sy <= (adj_sy < 10'sd0 || adj_sy >= 10'sd224) ? 8'hFF : adj_sy[7:0];
               end

                   state <= ST_CHECK;
               end
            end

            ST_CHECK: begin
                if (!spr_big) begin
                    // Normal 16x16 sprite
                    if (target_y_r < 8'd224 &&
                        {1'b0, target_y_r} >= spr_sy_eff &&
                        {1'b0, target_y_r} <  (spr_sy_eff + 9'd16)) begin
                        begin : row_calc_16
                            reg [8:0] raw_row9;
                            reg [7:0] raw_row;
                            reg       row_flip_eff;

                            raw_row9 = {1'b0, target_y_r} - spr_sy_eff;
                            raw_row  = raw_row9[7:0];
                            row_flip_eff = spr_yflip;

                            spr_row <= row_flip_eff ? {1'b0, (4'd15 - raw_row[3:0])}
                                                     : {1'b0, raw_row[3:0]};
                        end

                        spr_col <= 6'd0;
                        state   <= ST_SETUP;
                    end else begin
                        state <= ST_NEXT;
                    end
                end else begin
                    // Double 32x32 sprite
                    if (target_y_r < 8'd224 &&
                        {1'b0, target_y_r} >= {1'b0, spr_sy} &&
                        {1'b0, target_y_r} <  ({1'b0, spr_sy} + 9'd32)) begin
                        begin : row_calc_32
                            reg [7:0] raw_row;
                            raw_row = target_y_r - spr_sy;
                            spr_row <= spr_yflip ? (5'd31 - raw_row[4:0])
                                                  : raw_row[4:0];
                        end
                        spr_col <= 6'd0;
                        state   <= ST_SETUP;
                    end else begin
                        state <= ST_NEXT;
                    end
                end
            end
            ST_SETUP: begin
                begin : setup_calc
                    reg [5:0] src_col;
                    reg [6:0] byte_ofs;

                    src_col = spr_xflip ? ((spr_big ? 6'd31 : 6'd15) - spr_col)
                                         : spr_col;

                    if (!spr_big) begin
                        // 16x16 layout uses two 8-pixel columns and two 8-pixel row banks
                        byte_ofs =
                            (spr_row[3] ? (7'd16 + {4'b0000, spr_row[2:0]})
                                        : {4'b0000, spr_row[2:0]}) +
                            (src_col[3] ? 7'd8 : 7'd0);

                        // normal sprite: tile * 32 + byte_ofs
                        rom_raddr <= {spr_tile, 5'b00000} + {6'b000000, byte_ofs};
                    end else begin
                        // 32x32 layout uses four 8-pixel columns and four 8-pixel row banks
                        byte_ofs =
                            (spr_row[4] ? 7'd64 : 7'd0) +
                            (spr_row[3] ? 7'd16 : 7'd0) +
                            (src_col[4] ? 7'd32 : 7'd0) +
                            (src_col[3] ? 7'd8  : 7'd0) +
                            {4'b0000, spr_row[2:0]};

                        // Large sprite region starts at 0x1000 per plane.
                        // Large layout gives 32 tiles, so use low 5 bits.
                        rom_raddr <= 13'h1000 +
                                     {spr_tile[4:0], 7'b0000000} +
                                     {6'b000000, byte_ofs};
                    end
                    bit_sel_r <= 3'd7 - src_col[2:0];

                    // Apply separate flip-mode alignment for 16x16 and 32x32 sprites
                    dest_x_r <= spr_screen_x_eff
                                  + $signed({4'b0000, spr_col})
                                  + (flip ? (
                                              spr_big
                                              ? FLIP_SPR_Y_BIG_BASE
                                              : (FLIP_SPR_Y_NORMAL_BASE + $signed({y_adj[8], y_adj}))
                                  ) : $signed({y_adj[8], y_adj}));
                end
                state <= ST_ROM_WAIT;
            end

            ST_ROM_WAIT: begin
                state <= ST_WRITE;
            end

            ST_WRITE: begin
                // MAME draws lower offsets later, therefore lower offsets have priority.
                // Since we scan downward, opaque pixels overwrite previous pixels.

                if (spr_pix_idx != 3'd0 &&
                    dest_x_r >= 10'sd0 &&
                    dest_x_r <  10'sd256) begin

                    if (render_buf == 1'b0)
                        line_buf0[dest_x_r[7:0]] <= {1'b1, spr_pen_val[6:0]};
                    else
                        line_buf1[dest_x_r[7:0]] <= {1'b1, spr_pen_val[6:0]};
                end

                if (spr_col == (spr_big ? 6'd31 : 6'd15))
                    state <= ST_NEXT;
                else begin
                    spr_col <= spr_col + 6'd1;
                    state   <= ST_SETUP;
                end
            end

            ST_NEXT: begin
                if (spr_idx == 5'd0)
                    state <= ST_IDLE;
                else begin
                    spr_idx <= spr_idx - 5'd1;
                    state   <= ST_FETCH;
                end
            end

            default: state <= ST_IDLE;

        endcase
    end
end

//================================================================
// Display line buffer output
//================================================================

always @(posedge clk_sys) begin
    if (ce_pix) begin
        if (hcnt < 10'd256) begin
            if (display_buf == 1'b0) begin
                pen         <= {1'b0, line_buf0[hcnt[7:0]][6:0]};
                transparent <= ~line_buf0[hcnt[7:0]][7];
            end else begin
                pen         <= {1'b0, line_buf1[hcnt[7:0]][6:0]};
                transparent <= ~line_buf1[hcnt[7:0]][7];
            end
        end else begin
            pen         <= 8'h00;
            transparent <= 1'b1;
        end
    end
end

endmodule