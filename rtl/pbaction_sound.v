//============================================================================
// Pinball Action (Tehkan 1985) - Sound Subsystem
//
// Implements the sound Z80, RAM, sound latch, three AY-compatible PSGs,
// and the approximated IM2/CTC interrupt behavior used by the sound ROM
//
// The original board uses a Z80 CTC. This core currently models the
// observed interrupt behavior with:
//   - vector 00h for main-to-sound command handling
//   - vector 02h for the periodic sound-engine tick
//   - a fixed 120 Hz CTC-like timer
//============================================================================

module pbaction_sound (
    input  wire        clk_sys,
    input  wire        ce_snd,
    input  wire        reset,

    input  wire  [7:0] sound_latch,
    input  wire        sound_strobe,

    input  wire  [7:0] rom_data [0:8191],

    output wire [15:0] audio_l,
    output wire [15:0] audio_r
);

//================================================================
// Sound CPU RAM: 4000-47FF
//================================================================

reg [7:0] snd_ram [0:2047];

//================================================================
// Sound CPU bus
//================================================================

wire [15:0] snd_addr;
wire  [7:0] snd_dout;
reg   [7:0] snd_din;

wire        snd_mreq_n;
wire        snd_iorq_n;
wire        snd_rd_n;
wire        snd_wr_n;
wire        snd_m1_n;
wire        snd_rfsh_n;

// Address decode
wire snd_in_rom = (snd_addr <= 16'h1FFF);
wire snd_in_ram = (snd_addr >= 16'h4000 && snd_addr <= 16'h47FF);
wire snd_in_lat = (snd_addr == 16'h8000);

// I/O port value
wire [7:0] snd_port = snd_addr[7:0];

//================================================================
// Minimal Z80 CTC decode
//
// The sound board maps the CTC at I/O ports 00-03. This model only
// captures enough behavior for IM2 vector setup and periodic IRQ timing
//================================================================

wire ctc_cs = !snd_iorq_n && (snd_port >= 8'h00 && snd_port <= 8'h03);
wire ctc_wr = ctc_cs && !snd_wr_n;
wire ctc_rd = ctc_cs && !snd_rd_n;

// Periodic CTC-like interrupt
// 3 MHz / 25,000 = 120 Hz

localparam [15:0] CTC_DIV_MAX = 16'd24999;

reg [15:0] ctc_irq_div;
reg        ctc_irq_pulse;
reg        ctc_vector_loaded;

always @(posedge clk_sys) begin
    if (reset) begin
        ctc_irq_div       <= 16'd0;
        ctc_irq_pulse     <= 1'b0;
        ctc_vector_loaded <= 1'b0;
    end else begin
        ctc_irq_pulse <= 1'b0;

        if (ctc_wr && snd_port == 8'h00 && snd_dout[0] == 1'b0)
            ctc_vector_loaded <= 1'b1;

        if (ce_snd) begin
            if (ctc_vector_loaded) begin
                if (ctc_irq_div == CTC_DIV_MAX) begin
                    ctc_irq_div   <= 16'd0;
                    ctc_irq_pulse <= 1'b1;
                end else begin
                    ctc_irq_div <= ctc_irq_div + 16'd1;
                end
            end else begin
                ctc_irq_div <= 16'd0;
            end
        end
    end
end

//================================================================
// IM2 interrupt handling
//
// The sound ROM uses IM2 vector table entries at 0100h
//   vector 00h = main-to-sound command handler
//   vector 02h = periodic sound-engine update
//================================================================

reg [7:0] snd_irq_vector;
reg       snd_irq;

// Z80 interrupt acknowledge cycle
wire snd_int_ack = (!snd_m1_n && !snd_iorq_n);

always @(posedge clk_sys) begin
    if (reset) begin
        snd_irq        <= 1'b0;
        snd_irq_vector <= 8'h00;
    end else begin
		  // Sound command IRQs take priority over the periodic timer IRQ
        if (sound_strobe) begin
            snd_irq        <= 1'b1;
            snd_irq_vector <= 8'h00;
        end else if (ctc_irq_pulse) begin
            snd_irq        <= 1'b1;
            snd_irq_vector <= 8'h02;
        end else if (snd_int_ack) begin
            snd_irq <= 1'b0;
        end
    end
end

//================================================================
// AY / JT49 I/O decode
//================================================================

wire ay1_cs = !snd_iorq_n && (snd_port == 8'h10 || snd_port == 8'h11);
wire ay2_cs = !snd_iorq_n && (snd_port == 8'h20 || snd_port == 8'h21);
wire ay3_cs = !snd_iorq_n && (snd_port == 8'h30 || snd_port == 8'h31);

wire [7:0] ay1_dout;
wire [7:0] ay2_dout;
wire [7:0] ay3_dout;

// AY I/O ports use separate address and data registers
wire ay1_addr_wr = ay1_cs && !snd_wr_n && (snd_port == 8'h10);
wire ay1_data_wr = ay1_cs && !snd_wr_n && (snd_port == 8'h11);
wire ay1_data_rd = ay1_cs && !snd_rd_n && (snd_port == 8'h11);

wire ay2_addr_wr = ay2_cs && !snd_wr_n && (snd_port == 8'h20);
wire ay2_data_wr = ay2_cs && !snd_wr_n && (snd_port == 8'h21);
wire ay2_data_rd = ay2_cs && !snd_rd_n && (snd_port == 8'h21);

wire ay3_addr_wr = ay3_cs && !snd_wr_n && (snd_port == 8'h30);
wire ay3_data_wr = ay3_cs && !snd_wr_n && (snd_port == 8'h31);
wire ay3_data_rd = ay3_cs && !snd_rd_n && (snd_port == 8'h31);

//================================================================
// AY/JT49 write bridges
//================================================================

wire [3:0] ay1_addr_l;
wire [3:0] ay2_addr_l;
wire [3:0] ay3_addr_l;

wire [7:0] ay1_data_l;
wire [7:0] ay2_data_l;
wire [7:0] ay3_data_l;

wire ay1_wr_pulse;
wire ay2_wr_pulse;
wire ay3_wr_pulse;

ay_jt49_write_bridge u_ay1_bridge (
    .clk_sys     (clk_sys),
    .reset       (reset),
    .ce_ay       (ce_snd),

    .addr_wr     (ay1_addr_wr),
    .data_wr     (ay1_data_wr),
    .cpu_dout    (snd_dout),

    .jt_addr     (ay1_addr_l),
    .jt_data     (ay1_data_l),
    .jt_wr_pulse (ay1_wr_pulse),
);

ay_jt49_write_bridge u_ay2_bridge (
    .clk_sys     (clk_sys),
    .reset       (reset),
    .ce_ay       (ce_snd),

    .addr_wr     (ay2_addr_wr),
    .data_wr     (ay2_data_wr),
    .cpu_dout    (snd_dout),

    .jt_addr     (ay2_addr_l),
    .jt_data     (ay2_data_l),
    .jt_wr_pulse (ay2_wr_pulse),
);

ay_jt49_write_bridge u_ay3_bridge (
    .clk_sys     (clk_sys),
    .reset       (reset),
    .ce_ay       (ce_snd),

    .addr_wr     (ay3_addr_wr),
    .data_wr     (ay3_data_wr),
    .cpu_dout    (snd_dout),

    .jt_addr     (ay3_addr_l),
    .jt_data     (ay3_data_l),
    .jt_wr_pulse (ay3_wr_pulse),
);

//================================================================
// Sound CPU data input mux
//================================================================

always @(*) begin
    snd_din = 8'hFF;

    if (snd_int_ack) begin
        snd_din = snd_irq_vector;
    end else if (!snd_mreq_n && !snd_rd_n) begin
        if      (snd_in_rom) snd_din = rom_data[snd_addr[12:0]];
        else if (snd_in_ram) snd_din = snd_ram[snd_addr[10:0]];
        else if (snd_in_lat) snd_din = sound_latch;
        else                 snd_din = 8'hFF;
    end else if (!snd_iorq_n && !snd_rd_n) begin
        if      (ctc_rd)      snd_din = 8'h00;
        else if (ay1_data_rd) snd_din = ay1_dout;
        else if (ay2_data_rd) snd_din = ay2_dout;
        else if (ay3_data_rd) snd_din = ay3_dout;
        else                  snd_din = 8'hFF;
    end
end

//================================================================
// Sound RAM write
//================================================================

always @(posedge clk_sys) begin
    if (ce_snd) begin
        if (!snd_mreq_n && !snd_wr_n && snd_in_ram)
            snd_ram[snd_addr[10:0]] <= snd_dout;
    end
end

//================================================================
// Sound CPU
//================================================================

T80s #(
    .Mode   (0),
    .T2Write(1),
    .IOWait (1)
) u_snd_cpu (
    .RESET_n (~reset),
    .CLK     (clk_sys),
    .CEN     (ce_snd),
    .WAIT_n  (1'b1),
    .INT_n   (~snd_irq),
    .NMI_n   (1'b1),
    .BUSRQ_n (1'b1),
    .M1_n    (snd_m1_n),
    .MREQ_n  (snd_mreq_n),
    .IORQ_n  (snd_iorq_n),
    .RD_n    (snd_rd_n),
    .WR_n    (snd_wr_n),
    .RFSH_n  (snd_rfsh_n),
    .HALT_n  (),
    .BUSAK_n (),
    .A       (snd_addr),
    .DI      (snd_din),
    .DO      (snd_dout)
);

//================================================================
// Three AY-3-8910 compatible PSGs via direct jt49 interface
//================================================================

wire [9:0] ay1_out;
wire [9:0] ay2_out;
wire [9:0] ay3_out;

jt49 u_ay1 (
    .rst_n   (~reset),
    .clk     (clk_sys),
    .clk_en  (ce_snd),
    .addr    (ay1_addr_l),
    .cs_n    (~ay1_wr_pulse),
    .wr_n    (~ay1_wr_pulse),
    .din     (ay1_data_l),
    .sel     (1'b0),
    .dout    (ay1_dout),
    .sound   (ay1_out),
    .A       (),
    .B       (),
    .C       ()
);

jt49 u_ay2 (
    .rst_n   (~reset),
    .clk     (clk_sys),
    .clk_en  (ce_snd),
    .addr    (ay2_addr_l),
    .cs_n    (~ay2_wr_pulse),
    .wr_n    (~ay2_wr_pulse),
    .din     (ay2_data_l),
    .sel     (1'b0),
    .dout    (ay2_dout),
    .sound   (ay2_out),
    .A       (),
    .B       (),
    .C       ()
);

jt49 u_ay3 (
    .rst_n   (~reset),
    .clk     (clk_sys),
    .clk_en  (ce_snd),
    .addr    (ay3_addr_l),
    .cs_n    (~ay3_wr_pulse),
    .wr_n    (~ay3_wr_pulse),
    .din     (ay3_data_l),
    .sel     (1'b0),
    .dout    (ay3_dout),
    .sound   (ay3_out),
    .A       (),
    .B       (),
    .C       ()
);

//================================================================
// Audio mixer
//
// Sums the three unsigned PSG outputs and scales the result into
// the MiSTer signed audio range
//================================================================

wire [11:0] mix_sum = {2'b00, ay1_out}
                    + {2'b00, ay2_out}
                    + {2'b00, ay3_out};

// Convert the unsigned PSG sum to the signed MiSTer audio path
wire signed [15:0] mix_out =
    $signed({1'b0, mix_sum, 3'b000});

assign audio_l = mix_out;
assign audio_r = mix_out;

endmodule

//================================================================
// AY/JT49 write bridge
//
// Captures Z80 AY address/data writes and delivers stable jt49
// register writes on the PSG clock enable. A small FIFO prevents
// back-to-back address/data writes from being dropped
//================================================================

module ay_jt49_write_bridge (
    input  wire       clk_sys,
    input  wire       reset,
    input  wire       ce_ay,

    input  wire       addr_wr,
    input  wire       data_wr,
    input  wire [7:0] cpu_dout,

    output reg  [3:0] jt_addr,
    output reg  [7:0] jt_data,
    output reg        jt_wr_pulse
);

    wire wr_raw = addr_wr | data_wr;

    reg wr_raw_d;
    wire wr_edge = wr_raw & ~wr_raw_d;

    wire [8:0] new_op = {addr_wr, cpu_dout}; // bit 8: 1=addr, 0=data

    reg [8:0] fifo0;
    reg [8:0] fifo1;
    reg [1:0] fifo_count;

    reg data_pending;

    always @(posedge clk_sys) begin
        if (reset) begin
            wr_raw_d     <= 1'b0;
            fifo0        <= 9'd0;
            fifo1        <= 9'd0;
            fifo_count   <= 2'd0;
            data_pending <= 1'b0;

            jt_addr      <= 4'd0;
            jt_data      <= 8'd0;
            jt_wr_pulse  <= 1'b0;
        end else begin
            wr_raw_d <= wr_raw;

            if (ce_ay)
                jt_wr_pulse <= 1'b0;

            // Enqueue one Z80 AY write edge
            if (wr_edge) begin
                if (fifo_count == 2'd0) begin
                    fifo0      <= new_op;
                    fifo_count <= 2'd1;
                end else if (fifo_count == 2'd1) begin
                    fifo1      <= new_op;
                    fifo_count <= 2'd2;
                end else begin
                    // FIFO full. This should not occur with normal Z80 AY write timing
                end
            end

            // Consume one queued operation on the PSG clock enable
            if (ce_ay) begin
                if (data_pending) begin
                    jt_wr_pulse  <= 1'b1;
                    data_pending <= 1'b0;
                end else if (fifo_count != 2'd0) begin
                    if (fifo0[8]) begin
                        jt_addr <= fifo0[3:0];
                    end else begin
                        jt_data      <= fifo0[7:0];
                        data_pending <= 1'b1;
                    end

                    fifo0 <= fifo1;

                    if (!(wr_edge && fifo_count == 2'd1))
                        fifo_count <= fifo_count - 2'd1;
                end
            end
        end
    end

endmodule