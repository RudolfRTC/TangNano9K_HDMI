// TangNano 9K HDMI 720p60 Color Bar Test Pattern
// Target: Gowin GW1NR-9C
// Input clock: 27 MHz
// Output: 1280x720 @ 60Hz via HDMI (DVI mode)

module top (
    input  wire       clk,          // 27 MHz system clock
    input  wire       sys_resetn,   // active-low reset button
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire [2:0] tmds_d_p,
    output wire [2:0] tmds_d_n
);

    // =========================================================================
    // Clock generation
    // =========================================================================

    wire clk_serial;  // 371.25 MHz (5x pixel clock)
    wire clk_pixel;   // 74.25 MHz
    wire pll_lock;

    // PLL: 27 MHz -> 371.25 MHz
    Gowin_rPLL pll_inst (
        .clkout(clk_serial),
        .lock(pll_lock),
        .clkin(clk)
    );

    // Clock divider: 371.25 MHz / 5 = 74.25 MHz
    Gowin_CLKDIV clkdiv_inst (
        .clkout(clk_pixel),
        .hclkin(clk_serial),
        .resetn(pll_lock)
    );

    // =========================================================================
    // Reset synchronizer
    // =========================================================================

    reg [3:0] rst_cnt = 4'd0;
    wire rst_n = rst_cnt[3];

    always @(posedge clk_pixel or negedge pll_lock) begin
        if (!pll_lock)
            rst_cnt <= 4'd0;
        else if (!rst_cnt[3])
            rst_cnt <= rst_cnt + 1'd1;
    end

    // =========================================================================
    // Video timing generator
    // =========================================================================

    wire [10:0] hcnt;
    wire [9:0]  vcnt;
    wire        de, hsync, vsync;

    video_timing timing_inst (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .hcnt(hcnt),
        .vcnt(vcnt),
        .de(de),
        .hsync(hsync),
        .vsync(vsync)
    );

    // =========================================================================
    // Color bar test pattern (8 vertical bars)
    // =========================================================================

    reg [7:0] r, g, b;

    always @(posedge clk_pixel) begin
        case (hcnt[10:7])  // divide 1280 pixels into 8 regions (each 160px)
            4'd0: begin r <= 8'hFF; g <= 8'hFF; b <= 8'hFF; end  // White
            4'd1: begin r <= 8'hFF; g <= 8'hFF; b <= 8'h00; end  // Yellow
            4'd2: begin r <= 8'h00; g <= 8'hFF; b <= 8'hFF; end  // Cyan
            4'd3: begin r <= 8'h00; g <= 8'hFF; b <= 8'h00; end  // Green
            4'd4: begin r <= 8'hFF; g <= 8'h00; b <= 8'hFF; end  // Magenta
            4'd5: begin r <= 8'hFF; g <= 8'h00; b <= 8'h00; end  // Red
            4'd6: begin r <= 8'h00; g <= 8'h00; b <= 8'hFF; end  // Blue
            4'd7: begin r <= 8'h00; g <= 8'h00; b <= 8'h00; end  // Black
            default: begin r <= 8'h00; g <= 8'h00; b <= 8'h00; end
        endcase
    end

    // Delay sync/de by one clock to match pattern pipeline
    reg de_d, hsync_d, vsync_d;
    always @(posedge clk_pixel) begin
        de_d    <= de;
        hsync_d <= hsync;
        vsync_d <= vsync;
    end

    // =========================================================================
    // TMDS encoding (3 channels)
    // =========================================================================

    wire [9:0] tmds_r, tmds_g, tmds_b;

    // Channel 0: Blue + HSYNC/VSYNC
    tmds_encoder enc_b (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .din(b),
        .ctrl({vsync_d, hsync_d}),
        .de(de_d),
        .dout(tmds_b)
    );

    // Channel 1: Green + CTL0/CTL1
    tmds_encoder enc_g (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .din(g),
        .ctrl(2'b00),
        .de(de_d),
        .dout(tmds_g)
    );

    // Channel 2: Red + CTL2/CTL3
    tmds_encoder enc_r (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .din(r),
        .ctrl(2'b00),
        .de(de_d),
        .dout(tmds_r)
    );

    // =========================================================================
    // TMDS serialization (OSER10) and LVDS output (ELVDS_OBUF)
    // =========================================================================

    // --- Channel 0 (Blue) ---
    wire serial_b;
    OSER10 #(.GSREN("false"), .LSREN("true")) ser_b (
        .Q(serial_b),
        .D0(tmds_b[0]), .D1(tmds_b[1]), .D2(tmds_b[2]), .D3(tmds_b[3]),
        .D4(tmds_b[4]), .D5(tmds_b[5]), .D6(tmds_b[6]), .D7(tmds_b[7]),
        .D8(tmds_b[8]), .D9(tmds_b[9]),
        .FCLK(clk_serial),
        .PCLK(clk_pixel),
        .RESET(~rst_n)
    );
    ELVDS_OBUF obuf_b (.O(tmds_d_p[0]), .OB(tmds_d_n[0]), .I(serial_b));

    // --- Channel 1 (Green) ---
    wire serial_g;
    OSER10 #(.GSREN("false"), .LSREN("true")) ser_g (
        .Q(serial_g),
        .D0(tmds_g[0]), .D1(tmds_g[1]), .D2(tmds_g[2]), .D3(tmds_g[3]),
        .D4(tmds_g[4]), .D5(tmds_g[5]), .D6(tmds_g[6]), .D7(tmds_g[7]),
        .D8(tmds_g[8]), .D9(tmds_g[9]),
        .FCLK(clk_serial),
        .PCLK(clk_pixel),
        .RESET(~rst_n)
    );
    ELVDS_OBUF obuf_g (.O(tmds_d_p[1]), .OB(tmds_d_n[1]), .I(serial_g));

    // --- Channel 2 (Red) ---
    wire serial_r;
    OSER10 #(.GSREN("false"), .LSREN("true")) ser_r (
        .Q(serial_r),
        .D0(tmds_r[0]), .D1(tmds_r[1]), .D2(tmds_r[2]), .D3(tmds_r[3]),
        .D4(tmds_r[4]), .D5(tmds_r[5]), .D6(tmds_r[6]), .D7(tmds_r[7]),
        .D8(tmds_r[8]), .D9(tmds_r[9]),
        .FCLK(clk_serial),
        .PCLK(clk_pixel),
        .RESET(~rst_n)
    );
    ELVDS_OBUF obuf_r (.O(tmds_d_p[2]), .OB(tmds_d_n[2]), .I(serial_r));

    // --- TMDS Clock (fixed 1111100000 pattern) ---
    wire serial_clk;
    OSER10 #(.GSREN("false"), .LSREN("true")) ser_clk (
        .Q(serial_clk),
        .D0(1'b1), .D1(1'b1), .D2(1'b1), .D3(1'b1), .D4(1'b1),
        .D5(1'b0), .D6(1'b0), .D7(1'b0), .D8(1'b0), .D9(1'b0),
        .FCLK(clk_serial),
        .PCLK(clk_pixel),
        .RESET(~rst_n)
    );
    ELVDS_OBUF obuf_clk (.O(tmds_clk_p), .OB(tmds_clk_n), .I(serial_clk));

endmodule
