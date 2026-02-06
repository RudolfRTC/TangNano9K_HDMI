// Digital clock display with 7-segment style digits
// Displays HH:MM:SS on screen using the pixel clock as time base
// Designed for 1280x720 @ 60Hz (74.25 MHz pixel clock)

module clock_display (
    input  wire        clk,       // pixel clock (74.25 MHz)
    input  wire        rst,       // active high reset
    input  wire [10:0] hcnt,      // horizontal pixel counter
    input  wire [9:0]  vcnt,      // vertical line counter
    input  wire        inc_hour,  // pulse: increment hours by 1
    input  wire        inc_min,   // pulse: increment minutes by 1 (resets seconds)
    output wire        pixel_on   // 1 = clock digit pixel, 0 = background
);

    // =========================================================================
    // Display layout parameters
    // =========================================================================

    // Digit size
    localparam DIG_W = 80;   // digit width
    localparam DIG_H = 140;  // digit height
    localparam SEG_T = 14;   // segment thickness

    // Colon size
    localparam COL_W = 28;   // colon width
    localparam DOT_SZ = 14;  // colon dot size

    // Spacing
    localparam GAP = 12;     // gap between elements

    // Total width: 6*80 + 2*28 + 7*12 = 480 + 56 + 84 = 620
    localparam TOTAL_W = 6 * DIG_W + 2 * COL_W + 7 * GAP;

    // Clock area position (centered on 1280x720)
    localparam X_START = (1280 - TOTAL_W) / 2;  // = 330
    localparam Y_START = (720 - DIG_H) / 2;     // = 290

    // Element X positions (relative to X_START)
    localparam X0 = 0;                                              // h_tens
    localparam X1 = X0 + DIG_W + GAP;                               // h_ones
    localparam X2 = X1 + DIG_W + GAP;                               // colon1
    localparam X3 = X2 + COL_W + GAP;                               // m_tens
    localparam X4 = X3 + DIG_W + GAP;                               // m_ones
    localparam X5 = X4 + DIG_W + GAP;                               // colon2
    localparam X6 = X5 + COL_W + GAP;                               // s_tens
    localparam X7 = X6 + DIG_W + GAP;                               // s_ones

    // =========================================================================
    // Time counter (BCD, counts from 00:00:00)
    // =========================================================================

    reg [26:0] sec_cnt;    // counts to 74,250,000 - 1
    reg [3:0] s_ones, s_tens;
    reg [3:0] m_ones, m_tens;
    reg [3:0] h_ones, h_tens;
    reg       blink;       // toggles every second for colon blink

    wire one_second = (sec_cnt == 27'd74_249_999);

    always @(posedge clk) begin
        if (rst) begin
            sec_cnt <= 27'd0;
            s_ones <= 4'd0; s_tens <= 4'd0;
            m_ones <= 4'd0; m_tens <= 4'd0;
            h_ones <= 4'd0; h_tens <= 4'd0;
            blink  <= 1'b1;
        end else begin
            // Default: advance sub-second counter
            sec_cnt <= sec_cnt + 27'd1;

            // Button presses have priority over normal tick
            if (inc_min) begin
                // Increment minutes, reset seconds to :00
                sec_cnt <= 27'd0;
                s_ones <= 4'd0;
                s_tens <= 4'd0;
                if (m_ones == 4'd9) begin
                    m_ones <= 4'd0;
                    if (m_tens == 4'd5)
                        m_tens <= 4'd0;
                    else
                        m_tens <= m_tens + 4'd1;
                end else begin
                    m_ones <= m_ones + 4'd1;
                end
            end else if (inc_hour) begin
                // Increment hours (23 -> 0)
                if (h_tens == 4'd2 && h_ones == 4'd3) begin
                    h_ones <= 4'd0;
                    h_tens <= 4'd0;
                end else if (h_ones == 4'd9) begin
                    h_ones <= 4'd0;
                    h_tens <= h_tens + 4'd1;
                end else begin
                    h_ones <= h_ones + 4'd1;
                end
            end else if (one_second) begin
                // Normal tick: increment seconds
                sec_cnt <= 27'd0;
                blink <= ~blink;
                if (s_ones == 4'd9) begin
                    s_ones <= 4'd0;
                    if (s_tens == 4'd5) begin
                        s_tens <= 4'd0;
                        if (m_ones == 4'd9) begin
                            m_ones <= 4'd0;
                            if (m_tens == 4'd5) begin
                                m_tens <= 4'd0;
                                if (h_tens == 4'd2 && h_ones == 4'd3) begin
                                    h_ones <= 4'd0;
                                    h_tens <= 4'd0;
                                end else if (h_ones == 4'd9) begin
                                    h_ones <= 4'd0;
                                    h_tens <= h_tens + 4'd1;
                                end else begin
                                    h_ones <= h_ones + 4'd1;
                                end
                            end else begin
                                m_tens <= m_tens + 4'd1;
                            end
                        end else begin
                            m_ones <= m_ones + 4'd1;
                        end
                    end else begin
                        s_tens <= s_tens + 4'd1;
                    end
                end else begin
                    s_ones <= s_ones + 4'd1;
                end
            end
        end
    end

    // =========================================================================
    // 7-segment lookup table
    // Bit order: [6]=g [5]=f [4]=e [3]=d [2]=c [1]=b [0]=a
    // =========================================================================

    function [6:0] seg_lut;
        input [3:0] digit;
        begin
            case (digit)
                4'd0: seg_lut = 7'b0111111;  // a,b,c,d,e,f
                4'd1: seg_lut = 7'b0000110;  // b,c
                4'd2: seg_lut = 7'b1011011;  // a,b,d,e,g
                4'd3: seg_lut = 7'b1001111;  // a,b,c,d,g
                4'd4: seg_lut = 7'b1100110;  // b,c,f,g
                4'd5: seg_lut = 7'b1101101;  // a,c,d,f,g
                4'd6: seg_lut = 7'b1111101;  // a,c,d,e,f,g
                4'd7: seg_lut = 7'b0000111;  // a,b,c
                4'd8: seg_lut = 7'b1111111;  // a,b,c,d,e,f,g
                4'd9: seg_lut = 7'b1101111;  // a,b,c,d,f,g
                default: seg_lut = 7'b0000000;
            endcase
        end
    endfunction

    // =========================================================================
    // Segment geometry check
    // Given local coordinates (lx, ly) within a digit bounding box,
    // returns which segments are hit as a 7-bit mask
    // =========================================================================

    // Segment boundaries
    localparam S_H2 = (DIG_H - SEG_T) / 2;  // = 63, start of middle segment
    localparam S_H2E = (DIG_H + SEG_T) / 2;  // = 77, end of middle segment + 1

    function [6:0] seg_hit;
        input [10:0] lx;
        input [10:0] ly;
        begin
            seg_hit = 7'b0000000;
            // Segment a (top horizontal)
            if (lx >= SEG_T && lx < DIG_W - SEG_T && ly < SEG_T)
                seg_hit[0] = 1'b1;
            // Segment b (top-right vertical)
            if (lx >= DIG_W - SEG_T && ly >= SEG_T && ly < S_H2)
                seg_hit[1] = 1'b1;
            // Segment c (bottom-right vertical)
            if (lx >= DIG_W - SEG_T && ly >= S_H2E && ly < DIG_H - SEG_T)
                seg_hit[2] = 1'b1;
            // Segment d (bottom horizontal)
            if (lx >= SEG_T && lx < DIG_W - SEG_T && ly >= DIG_H - SEG_T)
                seg_hit[3] = 1'b1;
            // Segment e (bottom-left vertical)
            if (lx < SEG_T && ly >= S_H2E && ly < DIG_H - SEG_T)
                seg_hit[4] = 1'b1;
            // Segment f (top-left vertical)
            if (lx < SEG_T && ly >= SEG_T && ly < S_H2)
                seg_hit[5] = 1'b1;
            // Segment g (middle horizontal)
            if (lx >= SEG_T && lx < DIG_W - SEG_T && ly >= S_H2 && ly < S_H2E)
                seg_hit[6] = 1'b1;
        end
    endfunction

    // =========================================================================
    // Colon check: two square dots
    // =========================================================================

    function colon_hit;
        input [10:0] lx;
        input [10:0] ly;
        reg in_top_dot, in_bot_dot;
        begin
            // Center dots horizontally, place at 1/3 and 2/3 height
            in_top_dot = (lx >= (COL_W - DOT_SZ) / 2) && (lx < (COL_W + DOT_SZ) / 2) &&
                         (ly >= DIG_H / 3 - DOT_SZ / 2) && (ly < DIG_H / 3 + DOT_SZ / 2);
            in_bot_dot = (lx >= (COL_W - DOT_SZ) / 2) && (lx < (COL_W + DOT_SZ) / 2) &&
                         (ly >= 2 * DIG_H / 3 - DOT_SZ / 2) && (ly < 2 * DIG_H / 3 + DOT_SZ / 2);
            colon_hit = in_top_dot || in_bot_dot;
        end
    endfunction

    // =========================================================================
    // Pixel rendering logic
    // =========================================================================

    // Local coordinates relative to clock area
    wire [10:0] lx = hcnt - X_START;
    wire [10:0] ly = vcnt - Y_START;

    // Check if we're inside the clock area vertically
    wire in_y_range = (vcnt >= Y_START) && (vcnt < Y_START + DIG_H);

    // For each element, check if the pixel is inside and determine if it should be on
    reg px_on_comb;

    always @(*) begin
        px_on_comb = 1'b0;

        if (in_y_range) begin
            // Element 0: h_tens digit
            if (hcnt >= X_START + X0 && hcnt < X_START + X0 + DIG_W) begin
                if ((seg_hit(hcnt - (X_START + X0), ly) & seg_lut(h_tens)) != 7'd0)
                    px_on_comb = 1'b1;
            end
            // Element 1: h_ones digit
            else if (hcnt >= X_START + X1 && hcnt < X_START + X1 + DIG_W) begin
                if ((seg_hit(hcnt - (X_START + X1), ly) & seg_lut(h_ones)) != 7'd0)
                    px_on_comb = 1'b1;
            end
            // Element 2: colon1
            else if (hcnt >= X_START + X2 && hcnt < X_START + X2 + COL_W) begin
                if (colon_hit(hcnt - (X_START + X2), ly) && blink)
                    px_on_comb = 1'b1;
            end
            // Element 3: m_tens digit
            else if (hcnt >= X_START + X3 && hcnt < X_START + X3 + DIG_W) begin
                if ((seg_hit(hcnt - (X_START + X3), ly) & seg_lut(m_tens)) != 7'd0)
                    px_on_comb = 1'b1;
            end
            // Element 4: m_ones digit
            else if (hcnt >= X_START + X4 && hcnt < X_START + X4 + DIG_W) begin
                if ((seg_hit(hcnt - (X_START + X4), ly) & seg_lut(m_ones)) != 7'd0)
                    px_on_comb = 1'b1;
            end
            // Element 5: colon2
            else if (hcnt >= X_START + X5 && hcnt < X_START + X5 + COL_W) begin
                if (colon_hit(hcnt - (X_START + X5), ly) && blink)
                    px_on_comb = 1'b1;
            end
            // Element 6: s_tens digit
            else if (hcnt >= X_START + X6 && hcnt < X_START + X6 + DIG_W) begin
                if ((seg_hit(hcnt - (X_START + X6), ly) & seg_lut(s_tens)) != 7'd0)
                    px_on_comb = 1'b1;
            end
            // Element 7: s_ones digit
            else if (hcnt >= X_START + X7 && hcnt < X_START + X7 + DIG_W) begin
                if ((seg_hit(hcnt - (X_START + X7), ly) & seg_lut(s_ones)) != 7'd0)
                    px_on_comb = 1'b1;
            end
        end
    end

    // Combinational output - registered in top.v along with RGB
    assign pixel_on = px_on_comb;

endmodule
