// TangNano 9K HDMI 720p60 Digital Clock Display
// Target: Gowin GW1NR-9C
// Input clock: 27 MHz
// Output: 1280x720 @ 60Hz via HDMI (DVI mode)
// Displays HH:MM:SS clock with 7-segment style digits

module top (
    input  wire       clk,          // 27 MHz system clock
    input  wire       btn_hour_n,   // S1 button: increment hours (active-low)
    input  wire       btn_min_n,    // S2 button: increment minutes (active-low)
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
    // Button debounce, edge detection and auto-repeat
    // =========================================================================

    // --- Hour button (S1) ---
    reg [19:0] deb_cnt_h;
    reg        btn_h_stable;
    reg        btn_h_prev;

    always @(posedge clk_pixel) begin
        if (!rst_n) begin
            deb_cnt_h   <= 20'd0;
            btn_h_stable <= 1'b1;
        end else begin
            if (btn_hour_n != btn_h_stable) begin
                if (deb_cnt_h == 20'hFFFFF)     // ~14ms debounce
                    btn_h_stable <= btn_hour_n;
                else
                    deb_cnt_h <= deb_cnt_h + 20'd1;
            end else begin
                deb_cnt_h <= 20'd0;
            end
        end
    end

    always @(posedge clk_pixel) btn_h_prev <= btn_h_stable;
    wire btn_h_press = btn_h_prev & ~btn_h_stable;  // falling edge = press

    // Auto-repeat: 700ms initial, then every 200ms
    reg [25:0] rep_cnt_h;
    reg        rep_active_h;
    reg        rep_pulse_h;

    always @(posedge clk_pixel) begin
        rep_pulse_h <= 1'b0;
        if (!rst_n || btn_h_stable) begin   // released
            rep_cnt_h   <= 26'd0;
            rep_active_h <= 1'b0;
        end else begin                       // held down
            rep_cnt_h <= rep_cnt_h + 26'd1;
            if (!rep_active_h) begin
                if (rep_cnt_h == 26'd51_975_000) begin  // ~700ms
                    rep_active_h <= 1'b1;
                    rep_cnt_h    <= 26'd0;
                    rep_pulse_h  <= 1'b1;
                end
            end else begin
                if (rep_cnt_h == 26'd14_850_000) begin  // ~200ms
                    rep_cnt_h   <= 26'd0;
                    rep_pulse_h <= 1'b1;
                end
            end
        end
    end

    wire inc_hour = btn_h_press | rep_pulse_h;

    // --- Minute button (S2) ---
    reg [19:0] deb_cnt_m;
    reg        btn_m_stable;
    reg        btn_m_prev;

    always @(posedge clk_pixel) begin
        if (!rst_n) begin
            deb_cnt_m    <= 20'd0;
            btn_m_stable <= 1'b1;
        end else begin
            if (btn_min_n != btn_m_stable) begin
                if (deb_cnt_m == 20'hFFFFF)
                    btn_m_stable <= btn_min_n;
                else
                    deb_cnt_m <= deb_cnt_m + 20'd1;
            end else begin
                deb_cnt_m <= 20'd0;
            end
        end
    end

    always @(posedge clk_pixel) btn_m_prev <= btn_m_stable;
    wire btn_m_press = btn_m_prev & ~btn_m_stable;

    reg [25:0] rep_cnt_m;
    reg        rep_active_m;
    reg        rep_pulse_m;

    always @(posedge clk_pixel) begin
        rep_pulse_m <= 1'b0;
        if (!rst_n || btn_m_stable) begin
            rep_cnt_m    <= 26'd0;
            rep_active_m <= 1'b0;
        end else begin
            rep_cnt_m <= rep_cnt_m + 26'd1;
            if (!rep_active_m) begin
                if (rep_cnt_m == 26'd51_975_000) begin
                    rep_active_m <= 1'b1;
                    rep_cnt_m    <= 26'd0;
                    rep_pulse_m  <= 1'b1;
                end
            end else begin
                if (rep_cnt_m == 26'd14_850_000) begin
                    rep_cnt_m   <= 26'd0;
                    rep_pulse_m <= 1'b1;
                end
            end
        end
    end

    wire inc_min = btn_m_press | rep_pulse_m;

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
    // Clock display
    // =========================================================================

    wire clock_pixel_on;

    clock_display clock_inst (
        .clk(clk_pixel),
        .rst(~rst_n),
        .hcnt(hcnt),
        .vcnt(vcnt),
        .inc_hour(inc_hour),
        .inc_min(inc_min),
        .pixel_on(clock_pixel_on)
    );

    // RGB output: green digits on dark background
    reg [7:0] r, g, b;

    always @(posedge clk_pixel) begin
        if (clock_pixel_on) begin
            r <= 8'h00;  // bright green clock digits
            g <= 8'hFF;
            b <= 8'h00;
        end else begin
            r <= 8'h05;  // near-black background
            g <= 8'h05;
            b <= 8'h10;
        end
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
