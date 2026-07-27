//============================================================================
// Pinball Action (Tehkan 1985)
//
// Core top-level:
//
//   - Main Z80 subsystem
//   - Sound subsystem
//   - Video subsystem
//   - ROM/RAM storage
//   - Memory-mapped I/O
//============================================================================

`define ENABLE_SOUND

module pbaction (
   input  wire    clk_sys,  // 48 MHz system clock
   input  wire    reset,

   // ROM download interface (from HPS via emu)
   input  wire [15:0] ioctl_addr,
   input  wire  [7:0] ioctl_data,
   input  wire    rom_maincpu_wr,
   input  wire    rom_audiocpu_wr,
   input  wire    rom_fgchars_wr,
   input  wire    rom_bgchars_wr,
   input  wire    rom_sprites_wr,

   // Video outputs
   output wire    ce_pix,
   output wire    HBlank,
   output wire    VBlank,
   output wire    HSync,
   output wire    VSync,
   output wire  [3:0] R,
   output wire  [3:0] G,
   output wire  [3:0] B,

   // Audio
   output wire [15:0] audio_l,
   output wire [15:0] audio_r,

   // Player inputs (active high)
   input  wire    p1_flipper_l,
   input  wire    p1_flipper_r,
   input  wire    p1_nudge,
   input  wire    p1_launch,
   input  wire    p2_flipper_l,
   input  wire    p2_flipper_r,
   input  wire    p2_nudge,
   input  wire    p2_launch,
   input  wire    p1_start,
   input  wire    p2_start,
   input  wire    coin1,

   // DIP switches
   input  wire  [7:0] dip_sw1,
   input  wire  [7:0] dip_sw2,

   // Flip screen
   input  wire    flip,
   
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

   // Pause
   input  wire    paused
);

//================================================================
// Clock enables derived from 48 MHz clk_sys
//
// ce_pix = 6 MHz
// ce_cpu = 4 MHz
// ce_snd = 3 MHz
//================================================================

reg [2:0] ce_cnt;
always @(posedge clk_sys) begin
   if (reset)  ce_cnt <= 0;
   else        ce_cnt <= ce_cnt + 3'd1;
end
assign ce_pix = (ce_cnt == 3'd0);

reg [3:0] cpu_ce_cnt;
always @(posedge clk_sys) begin
   if (reset)  cpu_ce_cnt <= 0;
   else        cpu_ce_cnt <= cpu_ce_cnt + 4'd1;
end
wire ce_cpu = (cpu_ce_cnt == 4'd0) && !paused;

reg [3:0] snd_ce_cnt;
always @(posedge clk_sys) begin
   if (reset)  snd_ce_cnt <= 0;
   else        snd_ce_cnt <= snd_ce_cnt + 4'd1;
end
wire ce_snd = (snd_ce_cnt == 4'd0) && !paused;

//================================================================
// ROM blocks (written during download, read during game)
//================================================================

// Main CPU program ROM
wire [7:0] rom_maincpu_q;
dpram #(.AW(16), .DW(8)) u_rom_maincpu (
   .clk(clk_sys),
   .waddr(ioctl_addr),  .wdata(ioctl_data), .we(rom_maincpu_wr),
   .raddr(cpu_addr),    .rdata(rom_maincpu_q)
);

// Audio CPU ROM: 8KB
reg [7:0] rom_audiocpu [0:8191];
always @(posedge clk_sys)
   if (rom_audiocpu_wr) rom_audiocpu[ioctl_addr[12:0]] <= ioctl_data;

// FG char ROM: 3 planes x 8KB
wire [12:0] fg_rom_raddr;
wire  [7:0] fg_rom_p0_q, fg_rom_p1_q, fg_rom_p2_q;

wire rom_fg_p0_we = rom_fgchars_wr & (ioctl_addr[14:13] == 2'b00);
wire rom_fg_p1_we = rom_fgchars_wr & (ioctl_addr[14:13] == 2'b01);
wire rom_fg_p2_we = rom_fgchars_wr & (ioctl_addr[14:13] == 2'b10);

dpram #(.AW(13), .DW(8)) u_rom_fg_p0 (
   .clk(clk_sys),
   .waddr(ioctl_addr[12:0]), .wdata(ioctl_data), .we(rom_fg_p0_we),
   .raddr(fg_rom_raddr),     .rdata(fg_rom_p0_q)
);
dpram #(.AW(13), .DW(8)) u_rom_fg_p1 (
   .clk(clk_sys),
   .waddr(ioctl_addr[12:0]), .wdata(ioctl_data), .we(rom_fg_p1_we),
   .raddr(fg_rom_raddr),     .rdata(fg_rom_p1_q)
);
dpram #(.AW(13), .DW(8)) u_rom_fg_p2 (
   .clk(clk_sys),
   .waddr(ioctl_addr[12:0]), .wdata(ioctl_data), .we(rom_fg_p2_we),
   .raddr(fg_rom_raddr),     .rdata(fg_rom_p2_q)
);

// BG char ROM: 4 planes x 16KB
wire [13:0] bg_rom_raddr;
wire  [7:0] bg_rom_p0_q, bg_rom_p1_q, bg_rom_p2_q, bg_rom_p3_q;

wire rom_bg_p0_we = rom_bgchars_wr & (ioctl_addr[15:14] == 2'b00);
wire rom_bg_p1_we = rom_bgchars_wr & (ioctl_addr[15:14] == 2'b01);
wire rom_bg_p2_we = rom_bgchars_wr & (ioctl_addr[15:14] == 2'b10);
wire rom_bg_p3_we = rom_bgchars_wr & (ioctl_addr[15:14] == 2'b11);

dpram #(.AW(14), .DW(8)) u_rom_bg_p0 (
   .clk(clk_sys),
   .waddr(ioctl_addr[13:0]), .wdata(ioctl_data), .we(rom_bg_p0_we),
   .raddr(bg_rom_raddr),     .rdata(bg_rom_p0_q)
);
dpram #(.AW(14), .DW(8)) u_rom_bg_p1 (
   .clk(clk_sys),
   .waddr(ioctl_addr[13:0]), .wdata(ioctl_data), .we(rom_bg_p1_we),
   .raddr(bg_rom_raddr),     .rdata(bg_rom_p1_q)
);
dpram #(.AW(14), .DW(8)) u_rom_bg_p2 (
   .clk(clk_sys),
   .waddr(ioctl_addr[13:0]), .wdata(ioctl_data), .we(rom_bg_p2_we),
   .raddr(bg_rom_raddr),     .rdata(bg_rom_p2_q)
);
dpram #(.AW(14), .DW(8)) u_rom_bg_p3 (
   .clk(clk_sys),
   .waddr(ioctl_addr[13:0]), .wdata(ioctl_data), .we(rom_bg_p3_we),
   .raddr(bg_rom_raddr),     .rdata(bg_rom_p3_q)
);

// Sprite ROM: 3 planes x 8KB
wire [12:0] spr_rom_raddr;
wire  [7:0] spr_rom_p0_q, spr_rom_p1_q, spr_rom_p2_q;

wire rom_spr_p0_we = rom_sprites_wr & (ioctl_addr[14:13] == 2'b00);
wire rom_spr_p1_we = rom_sprites_wr & (ioctl_addr[14:13] == 2'b01);
wire rom_spr_p2_we = rom_sprites_wr & (ioctl_addr[14:13] == 2'b10);

dpram #(.AW(13), .DW(8)) u_rom_spr_p0 (
    .clk(clk_sys),
    .waddr(ioctl_addr[12:0]), .wdata(ioctl_data), .we(rom_spr_p0_we),
    .raddr(spr_rom_raddr),    .rdata(spr_rom_p0_q)
);
dpram #(.AW(13), .DW(8)) u_rom_spr_p1 (
   .clk(clk_sys),
   .waddr(ioctl_addr[12:0]), .wdata(ioctl_data), .we(rom_spr_p1_we),
   .raddr(spr_rom_raddr),    .rdata(spr_rom_p1_q)
);
dpram #(.AW(13), .DW(8)) u_rom_spr_p2 (
   .clk(clk_sys),
   .waddr(ioctl_addr[12:0]), .wdata(ioctl_data), .we(rom_spr_p2_we),
   .raddr(spr_rom_raddr),    .rdata(spr_rom_p2_q)
);

//================================================================
// Video-side tile/color RAMs (M10K-backed dprams)
// CPU writes go to both these AND the CPU-mirror dprams below
//================================================================

wire [9:0] fg_tile_raddr, fg_color_raddr, bg_tile_raddr, bg_color_raddr;
wire [7:0] fg_tile_q,     fg_color_q,     bg_tile_q,     bg_color_q;

wire fg_tile_we  = (!cpu_mreq_n && !cpu_wr_n && in_fg_tile);
wire fg_color_we = (!cpu_mreq_n && !cpu_wr_n && in_fg_color);
wire bg_tile_we  = (!cpu_mreq_n && !cpu_wr_n && in_bg_tile);
wire bg_color_we = (!cpu_mreq_n && !cpu_wr_n && in_bg_color);

dpram #(.AW(10), .DW(8)) u_fg_tile_ram (
   .clk(clk_sys),
   .waddr(cpu_addr[9:0]), .wdata(cpu_dout), .we(fg_tile_we),
   .raddr(fg_tile_raddr), .rdata(fg_tile_q)
);
dpram #(.AW(10), .DW(8)) u_fg_color_ram (
   .clk(clk_sys),
   .waddr(cpu_addr[9:0]),  .wdata(cpu_dout), .we(fg_color_we),
   .raddr(fg_color_raddr), .rdata(fg_color_q)
);
dpram #(.AW(10), .DW(8)) u_bg_tile_ram (
   .clk(clk_sys),
   .waddr(cpu_addr[9:0]), .wdata(cpu_dout), .we(bg_tile_we),
   .raddr(bg_tile_raddr), .rdata(bg_tile_q)
);
dpram #(.AW(10), .DW(8)) u_bg_color_ram (
   .clk(clk_sys),
   .waddr(cpu_addr[9:0]),  .wdata(cpu_dout), .we(bg_color_we),
   .raddr(bg_color_raddr), .rdata(bg_color_q)
);

// CPU-visible mirrors of the video RAM
// Separate read ports avoid video-side RAM latency during CPU reads
wire [7:0] fg_tile_cpu_q, fg_color_cpu_q, bg_tile_cpu_q, bg_color_cpu_q;

dpram #(.AW(10), .DW(8)) u_fg_tile_ram_cpu (
   .clk(clk_sys),
   .waddr(cpu_addr[9:0]), .wdata(cpu_dout), .we(fg_tile_we),
   .raddr(cpu_addr[9:0]), .rdata(fg_tile_cpu_q)
);
dpram #(.AW(10), .DW(8)) u_fg_color_ram_cpu (
   .clk(clk_sys),
   .waddr(cpu_addr[9:0]), .wdata(cpu_dout), .we(fg_color_we),
   .raddr(cpu_addr[9:0]), .rdata(fg_color_cpu_q)
);
dpram #(.AW(10), .DW(8)) u_bg_tile_ram_cpu (
   .clk(clk_sys),
   .waddr(cpu_addr[9:0]), .wdata(cpu_dout), .we(bg_tile_we),
   .raddr(cpu_addr[9:0]), .rdata(bg_tile_cpu_q)
);
dpram #(.AW(10), .DW(8)) u_bg_color_ram_cpu (
   .clk(clk_sys),
   .waddr(cpu_addr[9:0]), .wdata(cpu_dout), .we(bg_color_we),
   .raddr(cpu_addr[9:0]), .rdata(bg_color_cpu_q)
);

//================================================================
// Sprite RAM (E000-E07F) and Palette RAM (E400-E5FF)
//================================================================

reg [7:0] sprite_ram  [0:127];
reg [7:0] palette_ram [0:511];

//================================================================
// Work RAM (C000-CFFF)
//
// Implemented with combinational reads to preserve immediate
// read-after-write visibility expected by the Z80 software
//================================================================

reg   [7:0] work_ram_mem [0:4095];
wire  [11:0] work_ram_raddr = cpu_addr[11:0];
wire  [7:0] work_ram_q = work_ram_mem[work_ram_raddr];
wire        work_ram_we = (!cpu_mreq_n && !cpu_wr_n && in_work_ram);

always @(posedge clk_sys) begin
   if (work_ram_we)
      work_ram_mem[cpu_addr[11:0]] <= cpu_dout;
end

//================================================================
// I/O registers
//================================================================

reg         irq_enable;   // E600 bit 0
reg         flip_screen;  // E604 bit 0
reg [7:0]   bg_scroll;    // E606
reg [7:0]   sound_latch;  // E800

//================================================================
// Main CPU bus
//================================================================

wire  [15:0] cpu_addr;
wire  [7:0] cpu_dout;
wire  [7:0] cpu_din;
wire        cpu_mreq_n;
wire        cpu_iorq_n;
wire        cpu_rd_n;
wire        cpu_wr_n;
wire        cpu_rfsh_n;
wire        cpu_m1_n;
wire        cpu_int_n;
wire        cpu_nmi_n;
wire        cpu_busak_n;

// Address decode
wire in_rom      = (cpu_addr <= 16'hBFFF);
wire in_work_ram = (cpu_addr >= 16'hC000 && cpu_addr <= 16'hCFFF);
wire in_fg_tile  = (cpu_addr >= 16'hD000 && cpu_addr <= 16'hD3FF);
wire in_fg_color = (cpu_addr >= 16'hD400 && cpu_addr <= 16'hD7FF);
wire in_bg_tile  = (cpu_addr >= 16'hD800 && cpu_addr <= 16'hDBFF);
wire in_bg_color = (cpu_addr >= 16'hDC00 && cpu_addr <= 16'hDFFF);
wire in_sprite   = (cpu_addr >= 16'hE000 && cpu_addr <= 16'hE07F);
wire in_palette  = (cpu_addr >= 16'hE400 && cpu_addr <= 16'hE5FF);
wire in_io       = (cpu_addr >= 16'hE600 && cpu_addr <= 16'hE606);
wire in_sound    = (cpu_addr == 16'hE800);
wire sound_strobe = (!cpu_mreq_n && !cpu_wr_n && in_sound);

// CPU data input mux
reg [7:0] cpu_din_reg;
always @(*) begin
   cpu_din_reg = 8'hFF;
   if (!cpu_m1_n || (!cpu_mreq_n && !cpu_rd_n)) begin
      if      (in_rom)      cpu_din_reg = rom_maincpu_q;
      else if (in_work_ram) cpu_din_reg = work_ram_q;
      else if (in_fg_tile)  cpu_din_reg = fg_tile_cpu_q;
      else if (in_fg_color) cpu_din_reg = fg_color_cpu_q;
      else if (in_bg_tile)  cpu_din_reg = bg_tile_cpu_q;
      else if (in_bg_color) cpu_din_reg = bg_color_cpu_q;
      else if (in_sprite)   cpu_din_reg = sprite_ram[cpu_addr[6:0]];
      else if (in_palette)  cpu_din_reg = palette_ram[cpu_addr[8:0]];
      else if (in_io) begin
         case (cpu_addr[2:0])
               // E600: P1 inputs
               3'd0: cpu_din_reg = {
                   3'b000,        // bits 7:5 unknown
                   p1_flipper_r,  // bit 4
                   p1_flipper_l,  // bit 3
                   p1_launch,     // bit 2
                   1'b0,          // bit 1
                   p1_nudge       // bit 0
               };

               // E601: P2 inputs
               3'd1: cpu_din_reg = {
                   3'b000,        // bits 7:5 unknown
                   p2_flipper_r,  // bit 4
                   p2_flipper_l,  // bit 3
                   p2_launch,     // bit 2
                   1'b0,          // bit 1
                   p2_nudge       // bit 0
               };

               3'd2: cpu_din_reg = {4'b0000, p2_start, p1_start, 1'b0, coin1};
               // E604: DSW1
               3'd4: cpu_din_reg = dip_sw1;
               // E605: DSW2
               3'd5: cpu_din_reg = dip_sw2;
               // E606
               3'd6: cpu_din_reg = 8'hFF;
               default: cpu_din_reg = 8'hFF;
         endcase
      end
   end
end
assign cpu_din = cpu_din_reg;

// CPU write handling
integer sprclr_i;

always @(posedge clk_sys) begin
   if (reset) begin
      irq_enable  <= 1'b0;
      flip_screen <= 1'b0;
      bg_scroll   <= 8'd0;
      sound_latch <= 8'd0;

      // Clear sprite RAM on reset
      for (sprclr_i = 0; sprclr_i < 128; sprclr_i = sprclr_i + 1)
         sprite_ram[sprclr_i] <= 8'd0;
   end else if (!cpu_mreq_n && !cpu_wr_n) begin
      if (in_sprite)  sprite_ram[cpu_addr[6:0]]  <= cpu_dout;
      if (in_palette) palette_ram[cpu_addr[8:0]] <= cpu_dout;
      if (in_io) begin
         case (cpu_addr[2:0])
            3'd0: irq_enable  <= cpu_dout[0];       // E600 - NMI enable
            3'd4: flip_screen <= cpu_dout[0];       // E604 - flip
            3'd6: bg_scroll   <= cpu_dout - 8'd3;   // E606 - BG scroll, adjusted to match video timing
         endcase
      end
      if (in_sound) sound_latch <= cpu_dout;
   end
end

//================================================================
// NMI generation
//
// Pinball Action's main CPU uses NMI for the frame tick
// VBlank generates an edge-triggered NMI when enabled by E600 bit 0
// The armed flag ensures only one NMI is generated per frame
//================================================================

// Main CPU IRQ is unused
assign cpu_int_n = 1'b1;

reg   [7:0] nmi_pulse_cnt;
reg         nmi_armed;
reg         vblank_d, vblank_dd;
wire        vblank_rising  = vblank_d && !vblank_dd;
wire        vblank_falling = !vblank_d && vblank_dd;
wire        cpu_nmi = (nmi_pulse_cnt != 0);

always @(posedge clk_sys) begin
   if (reset) begin
      vblank_d      <= 0;
      vblank_dd     <= 0;
      nmi_pulse_cnt <= 0;
      nmi_armed     <= 0;
   end else begin
      vblank_d  <= VBlank;
      vblank_dd <= vblank_d;

      // Re-arm NMI on every VBlank falling edge
      if (vblank_falling)
         nmi_armed <= 1;

         // Fire NMI on VBlank rising edge if armed and enabled
      if (vblank_rising && irq_enable && nmi_armed) begin
         nmi_pulse_cnt <= 8'd32;   // ~8 us pulse
         nmi_armed     <= 0;
      end
         // Count down the NMI pulse on ce_cpu
      else if (ce_cpu && nmi_pulse_cnt != 0) begin
         nmi_pulse_cnt <= nmi_pulse_cnt - 1'd1;
      end
   end
end

assign cpu_nmi_n = ~cpu_nmi;

//================================================================
// Main CPU (T80s wrapper)
//================================================================

pbaction_cpu cpu (
   .clk_sys (clk_sys),
   .ce_cpu  (ce_cpu),
   .reset_n (~reset),
   .addr    (cpu_addr),
   .din     (cpu_din),
   .dout    (cpu_dout),
   .mreq_n  (cpu_mreq_n),
   .iorq_n  (cpu_iorq_n),
   .rd_n    (cpu_rd_n),
   .wr_n    (cpu_wr_n),
   .rfsh_n  (cpu_rfsh_n),
   .m1_n    (cpu_m1_n),
   .int_n   (cpu_int_n),
   .nmi_n   (cpu_nmi_n),
   .busak_n (cpu_busak_n)
);

//================================================================
// Sound subsystem
//================================================================

`ifdef ENABLE_SOUND

wire [15:0] snd_l, snd_r;

pbaction_sound sound (
   .clk_sys       (clk_sys),
   .ce_snd        (ce_snd),
   .reset         (reset),
   .sound_latch   (sound_latch),
   .sound_strobe  (sound_strobe),
   .rom_data      (rom_audiocpu),
   .audio_l       (snd_l),
   .audio_r       (snd_r)
);

assign audio_l = snd_l;
assign audio_r = snd_r;

`else

assign audio_l = 16'sd0;
assign audio_r = 16'sd0;

`endif

//================================================================
// Video subsystem
//================================================================

pbaction_video video (
   .clk_sys (clk_sys),
   .ce_pix  (ce_pix),
   .reset   (reset),
   .paused  (paused),
    
   .fg_x_adj  (fg_x_adj),
   .fg_y_adj  (fg_y_adj),
   .bg_x_adj  (bg_x_adj),
   .bg_y_adj  (bg_y_adj),
   .spr_x_adj (spr_x_adj),
   .spr_y_adj (spr_y_adj),

   // Tile/sprite data from RAMs
   .fg_tile_raddr  (fg_tile_raddr),
   .fg_tile_q      (fg_tile_q),
   .fg_color_raddr (fg_color_raddr),
   .fg_color_q     (fg_color_q),
   .bg_tile_raddr  (bg_tile_raddr),
   .bg_tile_q      (bg_tile_q),
   .bg_color_raddr (bg_color_raddr),
   .bg_color_q     (bg_color_q),
   .sprite_ram     (sprite_ram),
   .palette_ram    (palette_ram),

   // ROM data
   .fg_rom_raddr  (fg_rom_raddr),
   .fg_rom_p0_q   (fg_rom_p0_q),
   .fg_rom_p1_q   (fg_rom_p1_q),
   .fg_rom_p2_q   (fg_rom_p2_q),
   .bg_rom_raddr  (bg_rom_raddr),
   .bg_rom_p0_q   (bg_rom_p0_q),
   .bg_rom_p1_q   (bg_rom_p1_q),
   .bg_rom_p2_q   (bg_rom_p2_q),
   .bg_rom_p3_q   (bg_rom_p3_q),
   .spr_rom_raddr (spr_rom_raddr),
   .spr_rom_p0_q  (spr_rom_p0_q),
   .spr_rom_p1_q  (spr_rom_p1_q),
   .spr_rom_p2_q  (spr_rom_p2_q),

   // Scroll / flip
   .bg_scroll (bg_scroll),

   // Combine game-controlled cocktail flip with OSD flip
   .flip (flip_screen ^ flip),

   // Global screen position
   .h_pos_adj (h_pos_adj),
   .v_pos_adj (v_pos_adj),

   // Video outputs
   .HBlank (HBlank),
   .VBlank (VBlank),
   .HSync  (HSync),
   .VSync  (VSync),
   .R      (R),
   .G      (G),
   .B      (B)
);

endmodule