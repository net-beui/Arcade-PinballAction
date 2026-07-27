//============================================================================
// Pinball Action - Main CPU
//
// Thin wrapper around the T80s Z80-compatible CPU core
// The CPU runs from the 48 MHz system clock and is stepped with
// ce_cpu to achieve the original 4 MHz operating rate
//============================================================================

module pbaction_cpu (
    input  wire        clk_sys,
    input  wire        ce_cpu,     // 4 MHz clock enable
    input  wire        reset_n,    // active low reset

    output wire [15:0] addr,
    input  wire  [7:0] din,
    output wire  [7:0] dout,
    output wire        mreq_n,
    output wire        iorq_n,
    output wire        rd_n,
    output wire        wr_n,
    output wire        rfsh_n,
    output wire        m1_n,
    input  wire        int_n,
    input  wire        nmi_n,
    output wire        busak_n
);

T80s #(
    .Mode   (0),       // Z80 mode
    .T2Write(1),       // Z80-compatible write timing
    .IOWait (1)        // Enable standard I/O wait behavior
) u_cpu (
    .RESET_n (reset_n),
    .CLK     (clk_sys),
    .CEN     (ce_cpu),
    // Pinball Action does not use external wait states or bus requests
    .WAIT_n  (1'b1),
    .INT_n   (int_n),
    .NMI_n   (nmi_n),
    .BUSRQ_n (1'b1),
    .M1_n    (m1_n),
    .MREQ_n  (mreq_n),
    .IORQ_n  (iorq_n),
    .RD_n    (rd_n),
    .WR_n    (wr_n),
    .RFSH_n  (rfsh_n),
    .HALT_n  (),
    .BUSAK_n (busak_n),
    .A       (addr),
    .DI      (din),
    .DO      (dout)
);

endmodule
