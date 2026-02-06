// 720p60 video timing generator
// CEA-861 720p @ 60Hz timing:
//   Pixel clock: 74.25 MHz
//   H: 1280 active, 110 front, 40 sync, 220 back = 1650 total
//   V: 720 active, 5 front, 5 sync, 20 back = 750 total
//   HSYNC/VSYNC: positive polarity

module video_timing (
    input  wire        clk,       // pixel clock (74.25 MHz)
    input  wire        rst_n,
    output reg  [10:0] hcnt,      // horizontal pixel counter
    output reg  [9:0]  vcnt,      // vertical line counter
    output wire        de,        // data enable (active video)
    output wire        hsync,
    output wire        vsync
);

    // 720p60 timing parameters
    localparam H_ACTIVE = 11'd1280;
    localparam H_FRONT  = 11'd110;
    localparam H_SYNC   = 11'd40;
    localparam H_BACK   = 11'd220;
    localparam H_TOTAL  = 11'd1650;

    localparam V_ACTIVE = 10'd720;
    localparam V_FRONT  = 10'd5;
    localparam V_SYNC   = 10'd5;
    localparam V_BACK   = 10'd20;
    localparam V_TOTAL  = 10'd750;

    // Horizontal counter
    always @(posedge clk) begin
        if (!rst_n)
            hcnt <= 11'd0;
        else if (hcnt == H_TOTAL - 1'd1)
            hcnt <= 11'd0;
        else
            hcnt <= hcnt + 1'd1;
    end

    // Vertical counter
    always @(posedge clk) begin
        if (!rst_n)
            vcnt <= 10'd0;
        else if (hcnt == H_TOTAL - 1'd1) begin
            if (vcnt == V_TOTAL - 1'd1)
                vcnt <= 10'd0;
            else
                vcnt <= vcnt + 1'd1;
        end
    end

    // Sync signals (active during sync period, after active + front porch)
    assign hsync = (hcnt >= H_ACTIVE + H_FRONT) &&
                   (hcnt <  H_ACTIVE + H_FRONT + H_SYNC);

    assign vsync = (vcnt >= V_ACTIVE + V_FRONT) &&
                   (vcnt <  V_ACTIVE + V_FRONT + V_SYNC);

    // Data enable (active video area)
    assign de = (hcnt < H_ACTIVE) && (vcnt < V_ACTIVE);

endmodule
