//============================================================================
// Pinball Action (Tehkan 1985) - MiSTer FPGA Core
//
// Copyright (C) 2024
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation; either version 2 of the License, or (at your option)
// any later version
//============================================================================

module emu
(
    `include "sys/emu_ports.vh"
);

//////////////////////////////////////////////////////////////////
// Unused framework ports - tie off cleanly
//////////////////////////////////////////////////////////////////

assign    ADC_BUS        = 'Z;
assign    USER_OUT       = '1;
assign    {UART_RTS, UART_TXD, UART_DTR}   =  0;
assign    {SD_SCK, SD_MOSI, SD_CS}         =  'Z;
assign    {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE,
          SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS,
          SDRAM_nRAS, SDRAM_nCS}        = 'Z;
assign    {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN,
          DDRAM_BE, DDRAM_RD, DDRAM_WE}  = '0;

assign VGA_SL           = 0;
assign VGA_F1           = 0;
assign VGA_SCALER       = 0;
assign VGA_DISABLE      = 0;
assign HDMI_FREEZE      = 0;
assign HDMI_BLACKOUT    = 0;
assign HDMI_BOB_DEINT   = 0;

assign LED_DISK         = 0;
assign LED_POWER        = 0;
assign BUTTONS          = 0;

//////////////////////////////////////////////////////////////////
// OSD / HPS configuration string
//
// ROM loading layout (ioctl_index values):
//   0x00 - Main CPU ROM  (maincpu, up to 40KB: 0000-9FFF)
//   0x01 - Audio CPU ROM (audiocpu, 8KB)
//   0x02 - FG chars      (fgchars, 24KB: three 8KB ROMs)
//   0x03 - BG chars      (bgchars, 64KB: four 16KB ROMs)
//   0x04 - Sprites       (sprites, 24KB: three 8KB ROMs)
//
// MRA file will map MAME ROM regions to these indices
//////////////////////////////////////////////////////////////////

`include "build_id.v"

localparam CONF_STR = {
    "PinballAction;;",
     "-;",
    "O2,Flip,Off,On;",
    "OU,Flippers,Normal,Split Controllers;",
    "-;",
    "O48,Analog HPos,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
    "O9D,Analog VPos,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
    "-;",
    "DIP;",
    "OJK,Lives,3,4,5,2;",
    "OL,Cabinet,Upright,Cocktail;",
    "OE,Demo Sounds,On,Off;",
    "OMO,Bonus Life,70k 200k,70k 200k 1000k,100k,100k 300k,100k 300k 1000k,200k,200k 1000k,None;",
    "OP,Extra,Easy,Hard;",
    "OQR,Difficulty Flippers,Easy,Medium,Hard,Hardest;",
    "OST,Difficulty Outlanes,Easy,Medium,Hard,Hardest;",
    "-;",
    "R0,Reset;",
    "J1,Flipper L,Flipper R,Nudge,Launch,Start 1P,Start 2P,Coin,Pause;",
    "jn,A,B,X,Y,Start,Select,R,L;",
    "V,v",`BUILD_DATE
};

//////////////////////////////////////////////////////////////////
// HPS Interface
//////////////////////////////////////////////////////////////////

wire  [1:0]    buttons;
wire  [127:0]  status;
wire  [10:0]   ps2_key;
wire           forced_scandoubler;

function signed [8:0] status_s5_to_s9(input [4:0] v);
begin
   status_s5_to_s9 = {{4{v[4]}}, v};
end
endfunction

wire  signed   [8:0] h_pos_adj_osd = status_s5_to_s9(status[8:4]);
wire  signed   [8:0] v_pos_adj_osd = status_s5_to_s9(status[13:9]);

wire  osd_flip = status[2];
wire  split_flippers = status[30];

// Layer alignment baselines
// Flip and non-flip modes require different offsets to keep
// foreground, background and sprite layers aligned

localparam signed [8:0] FLIP_FG_X_BASELINE      =  9'sd0;
localparam signed [8:0] FLIP_FG_Y_BASELINE      =  9'sd0;
localparam signed [8:0] FLIP_BG_X_BASELINE      =  9'sd0;
localparam signed [8:0] FLIP_BG_Y_BASELINE      =  9'sd0;
localparam signed [8:0] FLIP_SPR_X_BASELINE     =  -9'sd1;
localparam signed [8:0] FLIP_SPR_Y_BASELINE     =  9'sd0;

localparam signed [8:0] NONFLIP_FG_X_BASELINE   =  9'sd0;
localparam signed [8:0] NONFLIP_FG_Y_BASELINE   =  -9'sd2;
localparam signed [8:0] NONFLIP_BG_X_BASELINE   =  9'sd0;
localparam signed [8:0] NONFLIP_BG_Y_BASELINE   =  -9'sd2;
localparam signed [8:0] NONFLIP_SPR_X_BASELINE  =  9'sd16;
localparam signed [8:0] NONFLIP_SPR_Y_BASELINE  =  -9'sd2;

wire signed [8:0] fg_x_adj    = osd_flip ? FLIP_FG_X_BASELINE  : NONFLIP_FG_X_BASELINE;
wire signed [8:0] fg_y_adj    = osd_flip ? FLIP_FG_Y_BASELINE  : NONFLIP_FG_Y_BASELINE;

wire signed [8:0] bg_x_adj    = osd_flip ? FLIP_BG_X_BASELINE  : NONFLIP_BG_X_BASELINE;
wire signed [8:0] bg_y_adj    = osd_flip ? FLIP_BG_Y_BASELINE  : NONFLIP_BG_Y_BASELINE;

wire signed [8:0] spr_x_adj   = osd_flip ? FLIP_SPR_X_BASELINE : NONFLIP_SPR_X_BASELINE;
wire signed [8:0] spr_y_adj   = osd_flip ? FLIP_SPR_Y_BASELINE : NONFLIP_SPR_Y_BASELINE;

// Joystick inputs - 6-button layout
wire [31:0] joy0, joy1;

// IOCTL - ROM loading from HPS
wire           ioctl_download;
wire  [7:0]    ioctl_index;
wire           ioctl_wr;
wire  [24:0]   ioctl_addr;
wire  [7:0]    ioctl_dout;

// DIP switches are implemented through CONF_STR status bits
// rather than MRA <switches> entries. The game reads:
//
//   E604 = DSW1
//   E605 = DSW2
//
// Status bit mapping:
//
//   status[20:19] = Lives
//   status[21]    = Cabinet
//   status[14]    = Demo Sounds
//   status[24:22] = Bonus Life
//   status[25]    = Extra
//   status[27:26] = Flipper Difficulty
//   status[29:28] = Outlane Difficulty

wire [1:0]  dip_lives         = status[20:19];
wire        dip_cabinet       = status[21];
wire        dip_demo_sounds   = status[14];

wire [2:0]  dip_bonus_life    = status[24:22];
wire        dip_extra         = status[25];
wire [1:0]  dip_diff_flip     = status[27:26];
wire [1:0]  dip_diff_outlane  = status[29:28];

// Fixed coinage

wire [1:0]  dip_coin_a = 2'b00; // fixed 1C/1C candidate
wire [1:0]  dip_coin_b = 2'b00; // fixed 1C/1C candidate

// DSW1 layout:
//   bits 1:0 = Coin A
//   bits 3:2 = Coin B
//   bits 5:4 = Lives
//   bit  6   = Cabinet
//   bit  7   = Demo Sounds
//
// Demo Sounds OSD string is "On,Off":
//   status[14] = 0 -> On
//   status[14] = 1 -> Off
wire [7:0] dip_sw1_core = {
    dip_demo_sounds,
    dip_cabinet,
    dip_lives,
    dip_coin_b,
    dip_coin_a
};

// DSW2 layout:
//   bits 2:0 = Bonus Life
//   bit  3   = Extra
//   bits 5:4 = Difficulty Flippers
//   bits 7:6 = Difficulty Outlanes
wire [7:0] dip_sw2_core = {
    dip_diff_outlane,
    dip_diff_flip,
    dip_extra,
    dip_bonus_life
};

wire [15:0] dip_sw = {dip_sw2_core, dip_sw1_core};

hps_io #(
    .CONF_STR(CONF_STR),
    .PS2DIV(1000),
    .WIDE(0)
) hps_io (
    .clk_sys    (clk_sys),
    .HPS_BUS    (HPS_BUS),
    .buttons    (buttons),
    .status     (status),
    .status_menumask(0),

    .forced_scandoubler(forced_scandoubler),

    .ps2_key    (ps2_key),

    .joystick_0  (joy0),
    .joystick_1  (joy1),

    .ioctl_download   (ioctl_download),
    .ioctl_index      (ioctl_index),
    .ioctl_wr         (ioctl_wr),
    .ioctl_addr       (ioctl_addr),
    .ioctl_dout       (ioctl_dout),

    .status_in   ({status[127:1], 1'b0}),
    .status_set  (1'b0)
);

//////////////////////////////////////////////////////////////////
// Clocks
//////////////////////////////////////////////////////////////////

wire clk_sys;   // System clock
wire clk_vid;   // Video clock
wire pll_locked;

pll pll (
    .refclk   (CLK_50M),
    .rst    (0),
    .outclk_0 (clk_sys),
    .outclk_1 (clk_vid),
    .locked   (pll_locked)
);

//////////////////////////////////////////////////////////////////
// Reset
//////////////////////////////////////////////////////////////////

reg [15:0] reset_counter;
wire reset_req = RESET | status[0] | buttons[1] | ~pll_locked | ioctl_download;

always @(posedge clk_sys) begin
    if (reset_req)
        reset_counter <= 16'hFFFF;
    else if (reset_counter != 0)
        reset_counter <= reset_counter - 1'd1;
end

wire reset = (reset_counter != 0);

//////////////////////////////////////////////////////////////////
// ROM write routing
//////////////////////////////////////////////////////////////////

wire rom_wr = ioctl_wr & ioctl_download;

wire rom_maincpu_wr     = rom_wr & (ioctl_index == 8'h00);
wire rom_audiocpu_wr    = rom_wr & (ioctl_index == 8'h01);
wire rom_fgchars_wr     = rom_wr & (ioctl_index == 8'h02);
wire rom_bgchars_wr     = rom_wr & (ioctl_index == 8'h03);
wire rom_sprites_wr     = rom_wr & (ioctl_index == 8'h04);

//////////////////////////////////////////////////////////////////
// Video signals from core
//////////////////////////////////////////////////////////////////

wire ce_pix;
wire HBlank, VBlank, HSync, VSync;
wire [3:0] R, G, B;

//////////////////////////////////////////////////////////////////
// Audio from core
//////////////////////////////////////////////////////////////////

wire [15:0] audio_l, audio_r;

//////////////////////////////////////////////////////////////////
// MiSTer input mapping
//
// Normal mode:
//   Controller 1 controls P1
//   Controller 2 controls P2
//
// Split Controllers mode:
//   Controller 1 controls the left flipper
//   Controller 2 controls the right flipper
//   Launch and nudge can be triggered from either controller
//////////////////////////////////////////////////////////////////

wire p1_flipper_l = joy0[4];
wire p1_flipper_r = split_flippers ? joy1[5] : joy0[5];
wire p1_launch    = split_flippers ? (joy0[6] | joy1[6]) : joy0[6];
wire p1_nudge     = split_flippers ? (joy0[7] | joy1[7]) : joy0[7];

wire p2_flipper_l = joy1[4];
wire p2_flipper_r = joy1[5];
wire p2_launch    = joy1[6];
wire p2_nudge     = joy1[7];

wire p1_start     = joy0[8]  | joy1[8];
wire p2_start     = joy0[9]  | joy1[9];

wire coin1        = joy0[10] | joy1[10];
wire pause_btn    = joy0[11] | joy1[11];

//////////////////////////////////////////////////////////////////
// Pause
//////////////////////////////////////////////////////////////////

reg pause_btn_prev;
reg paused;

always @(posedge clk_sys) begin
    if (reset) begin
        paused         <= 1'b0;
        pause_btn_prev <= 1'b0;
    end else begin
        pause_btn_prev <= pause_btn;
    if (pause_btn && !pause_btn_prev)
        paused <= ~paused;
    end
end

//////////////////////////////////////////////////////////////////
// Core instantiation
//////////////////////////////////////////////////////////////////

pbaction pbaction (
    .clk_sys    (clk_sys),
    .reset      (reset),

    // ROM download
    .ioctl_addr       (ioctl_addr[15:0]),
    .ioctl_data       (ioctl_dout),
    .rom_maincpu_wr   (rom_maincpu_wr),
    .rom_audiocpu_wr  (rom_audiocpu_wr),
    .rom_fgchars_wr   (rom_fgchars_wr),
    .rom_bgchars_wr   (rom_bgchars_wr),
    .rom_sprites_wr   (rom_sprites_wr),

    // Video outputs
    .ce_pix        (ce_pix),
    .HBlank        (HBlank),
    .VBlank        (VBlank),
    .HSync         (HSync),
    .VSync         (VSync),
    .R             (R),
    .G             (G),
    .B             (B),

    // Audio outputs
    .audio_l       (audio_l),
    .audio_r       (audio_r),

    // Inputs
    .p1_flipper_l  (p1_flipper_l),
    .p1_flipper_r  (p1_flipper_r),
    .p1_nudge      (p1_nudge),
    .p1_launch     (p1_launch),

    .p2_flipper_l  (p2_flipper_l),
    .p2_flipper_r  (p2_flipper_r),
    .p2_nudge      (p2_nudge),
    .p2_launch     (p2_launch),

    .p1_start      (p1_start),
    .p2_start      (p2_start),
    .coin1         (coin1),

    // DIP switches (from OSD/MRA)
    .dip_sw1       (dip_sw[7:0]),
    .dip_sw2       (dip_sw[15:8]),

    // Flip
    .flip          (status[2]),
    
    .fg_x_adj      (fg_x_adj),
    .fg_y_adj      (fg_y_adj),
    .bg_x_adj      (bg_x_adj),
    .bg_y_adj      (bg_y_adj),
    .spr_x_adj     (spr_x_adj),
    .spr_y_adj     (spr_y_adj),

    .h_pos_adj     (h_pos_adj_osd),
    .v_pos_adj     (v_pos_adj_osd),

    .paused        (paused)
);

//////////////////////////////////////////////////////////////////
// MiSTer Video Output
//////////////////////////////////////////////////////////////////

assign CLK_VIDEO  = clk_vid;
assign CE_PIXEL   = ce_pix;

assign VGA_DE     = ~(HBlank | VBlank);
assign VGA_HS     = HSync;
assign VGA_VS     = VSync;

// Expand 4-bit color to 8-bit for the framework
assign VGA_R = {R, R};
assign VGA_G = {G, G};
assign VGA_B = {B, B};

//////////////////////////////////////////////////////////////////
// MiSTer Audio Output
//////////////////////////////////////////////////////////////////

assign AUDIO_S    = 1;        // signed audio
assign AUDIO_L    = audio_l;
assign AUDIO_R    = audio_r;
assign AUDIO_MIX  = 0;

//////////////////////////////////////////////////////////////////
// Aspect ratio
// Vertical game displayed in 3:4 portrait aspect ratio
//////////////////////////////////////////////////////////////////

assign VIDEO_ARX  = 13'd4;
assign VIDEO_ARY  = 13'd3;

//////////////////////////////////////////////////////////////////
// Activity LED
//////////////////////////////////////////////////////////////////

reg [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1;
assign LED_USER = act_cnt[26] ? act_cnt[25:18] > act_cnt[7:0]
                              : act_cnt[25:18] <= act_cnt[7:0];

endmodule
