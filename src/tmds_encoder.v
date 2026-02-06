// TMDS 8b/10b encoder for DVI/HDMI
// Implements the TMDS encoding algorithm per DVI 1.0 specification

module tmds_encoder (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] din,      // 8-bit pixel data
    input  wire [1:0] ctrl,     // 2-bit control (used during blanking)
    input  wire       de,       // data enable (active video)
    output reg  [9:0] dout      // 10-bit TMDS encoded output
);

    // Count number of 1s in input data
    wire [3:0] n1_din = din[0] + din[1] + din[2] + din[3] +
                         din[4] + din[5] + din[6] + din[7];

    // Choose XOR or XNOR encoding
    wire use_xnor = (n1_din > 4'd4) || (n1_din == 4'd4 && din[0] == 1'b0);

    // Stage 1: Transition-minimized encoding (q_m)
    wire [8:0] q_m;
    assign q_m[0] = din[0];
    assign q_m[1] = use_xnor ? ~(din[1] ^ q_m[0]) : (din[1] ^ q_m[0]);
    assign q_m[2] = use_xnor ? ~(din[2] ^ q_m[1]) : (din[2] ^ q_m[1]);
    assign q_m[3] = use_xnor ? ~(din[3] ^ q_m[2]) : (din[3] ^ q_m[2]);
    assign q_m[4] = use_xnor ? ~(din[4] ^ q_m[3]) : (din[4] ^ q_m[3]);
    assign q_m[5] = use_xnor ? ~(din[5] ^ q_m[4]) : (din[5] ^ q_m[4]);
    assign q_m[6] = use_xnor ? ~(din[6] ^ q_m[5]) : (din[6] ^ q_m[5]);
    assign q_m[7] = use_xnor ? ~(din[7] ^ q_m[6]) : (din[7] ^ q_m[6]);
    assign q_m[8] = ~use_xnor; // 1 = XOR was used, 0 = XNOR was used

    // Count number of 1s and 0s in q_m[7:0]
    wire [3:0] n1_qm = q_m[0] + q_m[1] + q_m[2] + q_m[3] +
                        q_m[4] + q_m[5] + q_m[6] + q_m[7];
    wire [3:0] n0_qm = 4'd8 - n1_qm;

    // DC balance counter (signed)
    reg signed [4:0] cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            dout <= 10'd0;
            cnt  <= 5'sd0;
        end else if (!de) begin
            // Blanking period: send control tokens
            cnt <= 5'sd0;
            case (ctrl)
                2'b00:   dout <= 10'b1101010100;
                2'b01:   dout <= 10'b0010101011;
                2'b10:   dout <= 10'b0101010100;
                default: dout <= 10'b1010101011;
            endcase
        end else begin
            // Active video: TMDS encode pixel data
            if (cnt == 5'sd0 || n1_qm == 4'd4) begin
                // Balanced case
                dout[9]   <= ~q_m[8];
                dout[8]   <= q_m[8];
                dout[7:0] <= q_m[8] ? q_m[7:0] : ~q_m[7:0];
                if (!q_m[8])
                    cnt <= cnt + $signed({1'b0, n0_qm}) - $signed({1'b0, n1_qm});
                else
                    cnt <= cnt + $signed({1'b0, n1_qm}) - $signed({1'b0, n0_qm});
            end else begin
                if ((!cnt[4] && n1_qm > 4'd4) || (cnt[4] && n1_qm < 4'd4)) begin
                    // Too many 1s: invert data bits
                    dout[9]   <= 1'b1;
                    dout[8]   <= q_m[8];
                    dout[7:0] <= ~q_m[7:0];
                    cnt <= cnt + $signed({3'b0, q_m[8], 1'b0})
                         + $signed({1'b0, n0_qm}) - $signed({1'b0, n1_qm});
                end else begin
                    // Too many 0s: keep data bits
                    dout[9]   <= 1'b0;
                    dout[8]   <= q_m[8];
                    dout[7:0] <= q_m[7:0];
                    cnt <= cnt - $signed({3'b0, ~q_m[8], 1'b0})
                         + $signed({1'b0, n1_qm}) - $signed({1'b0, n0_qm});
                end
            end
        end
    end

endmodule
