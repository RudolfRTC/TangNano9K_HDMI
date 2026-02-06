// Clock divider: divides 371.25 MHz serial clock by 5 to get 74.25 MHz pixel clock
// Generated for GW1NR-9C (TangNano 9K)

module Gowin_CLKDIV (
    output clkout,
    input  hclkin,
    input  resetn
);

    CLKDIV clkdiv_inst (
        .CLKOUT(clkout),
        .HCLKIN(hclkin),
        .RESETN(resetn),
        .CALIB(1'b1)
    );

    defparam clkdiv_inst.DIV_MODE = "5";
    defparam clkdiv_inst.GSREN    = "false";

endmodule
