// Pinball Action MiSTer - PLL
//
// Input:  50 MHz (CLK_50M from DE10-nano)
// Output: clk_sys = 48.000 MHz  (pixel clock = 48/8 = 6.000 MHz via ce_pix)
//         clk_vid = 48.000 MHz  (CLK_VIDEO, same domain)
//
// These outputs are the same frequency; CLK_VIDEO and clk_sys share a domain
// which is the simplest approach for a core that doesn't need SDRAM.
//
// PLL configuration for Cyclone V, Quartus 17.0:
//   VCO = 960 MHz  (50 * 96/5)
//   outclk_0: /20 = 48 MHz
//   outclk_1: /20 = 48 MHz  (video)
//
// Note: You must regenerate this PLL megafunction in Quartus 17.0 using
// the MegaWizard Plug-In Manager (ALTPLL) to get the actual .v with all
// the ALTPLL parameters filled in. The stub below documents the intended
// configuration so you can replicate it in the wizard.
//
// Wizard settings:
//   Which device speed grade: 7
//   Input clock: 50 MHz
//   Operation mode: Normal
//   outclk_0: 48 MHz, 0° phase, 50% duty cycle
//   outclk_1: 48 MHz, 0° phase, 50% duty cycle
//
// After generation, replace this file with the generated pll.v.

module pll (
    input  wire refclk,    // 50 MHz
    input  wire rst,
    output wire outclk_0,  // 48 MHz - clk_sys
    output wire outclk_1,  // 48 MHz - clk_vid
    output wire locked
);

    // ALTPLL stub - replace with Quartus-generated version
    // For simulation / placeholder use:
    //   50 MHz in -> 48 MHz out (ratio 24/25)
    //
    // Real implementation: use MegaWizard to generate altpll with:
    //   inclk0 = 50 MHz
    //   c0 = 48 MHz (M=96, N=5, C0=20 for Cyclone V VCO=960MHz)
    //   c1 = 48 MHz

    altera_pll #(
        .fractional_vco_multiplier("false"),
        .reference_clock_frequency("50.0 MHz"),
        .operation_mode("normal"),
        .number_of_clocks(2),
        .output_clock_frequency0("48.000000 MHz"),
        .phase_shift0("0 ps"),
        .duty_cycle0(50),
        .output_clock_frequency1("48.000000 MHz"),
        .phase_shift1("0 ps"),
        .duty_cycle1(50),
        .pll_type("General"),
        .pll_subtype("General")
    ) pll_inst (
        .rst(rst),
        .outclk({outclk_1, outclk_0}),
        .locked(locked),
        .fboutclk(),
        .fbclk(1'b0),
        .refclk(refclk)
    );

endmodule
