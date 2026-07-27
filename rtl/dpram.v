//============================================================================
// Generic dual-port RAM
//
// Synchronous write, synchronous read
// Optional address-pattern initialization for diagnostics
//============================================================================

module dpram #(
    parameter AW = 16,
    parameter DW = 8,
    parameter INIT_PATTERN = 0   // 0 = disabled, 1 = address pattern
) (
    input  wire             clk,

    input  wire [AW-1:0]    waddr,
    input  wire [DW-1:0]    wdata,
    input  wire             we,

    input  wire [AW-1:0]    raddr,
    output reg  [DW-1:0]    rdata
);

    // Inferred block RAM
    reg [DW-1:0] mem [0:(2**AW)-1] /* synthesis ramstyle = "M10K" */;

    // Optional address-pattern initialization
    integer i;
    initial begin
        if (INIT_PATTERN == 1) begin
            for (i = 0; i < (2**AW); i = i + 1)
                mem[i] = i[DW-1:0];
        end
    end

//================================================================
// Read/write port
//================================================================
    always @(posedge clk) begin
        if (we)
        mem[waddr] <= wdata;
        rdata <= mem[raddr];
    end

endmodule