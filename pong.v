`timescale 1ns / 1ps
// ============================================================================
//  pong.v  --  Single-file two-player Pong for the Digilent Nexys 4 (Artix-7)
//
//  Video   : VGA 640x480 @ 60 Hz (25 MHz pixel enable derived from 100 MHz)
//  Controls:
//      BTNU  left  paddle up        BTNL  left  paddle down
//      BTNR  right paddle up        BTND  right paddle down
//      BTNC  serve the ball / start a new game after someone reaches 9
//      CPU RESET (red button)       hard reset
//  Extras  : scores are drawn on screen and mirrored on the 7-segment display
//            (left score on the left-most digit, right score on the right-most)
//
//  Everything runs in the single 100 MHz clock domain; the 25 MHz pixel rate
//  is a clock-enable, so no MMCM/PLL is needed.  Game state is updated once
//  per frame at the start of vertical blanking.
// ============================================================================
module pong (
    input  wire       CLK100MHZ,
    input  wire       CPU_RESETN,   // active-low reset button
    input  wire       BTNC,
    input  wire       BTNU,
    input  wire       BTNL,
    input  wire       BTNR,
    input  wire       BTND,
    output reg  [3:0] VGA_R,
    output reg  [3:0] VGA_G,
    output reg  [3:0] VGA_B,
    output reg        VGA_HS,
    output reg        VGA_VS,
    output reg  [6:0] SEG,          // {CG,CF,CE,CD,CC,CB,CA}, active low
    output wire       DP,           // decimal point, active low
    output reg  [7:0] AN            // digit anodes, active low
);

    // ------------------------------------------------------------------
    //  VGA 640x480 @ 60 Hz timing (negative sync polarity)
    // ------------------------------------------------------------------
    localparam H_VISIBLE = 640, H_FP = 16, H_SYNC = 96, H_BP = 48, H_TOTAL = 800;
    localparam V_VISIBLE = 480, V_FP = 10, V_SYNC =  2, V_BP = 33, V_TOTAL = 525;

    // ------------------------------------------------------------------
    //  Playfield geometry (pixels)
    // ------------------------------------------------------------------
    localparam WALL_T    = 4;                       // top/bottom wall thickness
    localparam FIELD_TOP = WALL_T;                  // first playable row
    localparam FIELD_BOT = V_VISIBLE - WALL_T;      // one past last playable row
    localparam PAD_W     = 8;
    localparam PAD_H     = 64;
    localparam PAD_SPEED = 4;                       // pixels per frame
    localparam PADL_X    = 16;
    localparam PADR_X    = H_VISIBLE - 16 - PAD_W;  // 616
    localparam PAD_Y0    = (V_VISIBLE - PAD_H) / 2; // 208
    localparam BALL_SZ   = 8;
    localparam BALL_X0   = (H_VISIBLE - BALL_SZ) / 2;
    localparam BALL_Y0   = (V_VISIBLE - BALL_SZ) / 2;
    localparam BALL_DX0  = 3;                       // serve speed
    localparam BALL_DXMAX= 6;                       // speed cap
    localparam WIN_SCORE = 9;
    localparam NET_X     = H_VISIBLE / 2 - 2;       // 4-pixel wide dashed net
    localparam DIGIT_W   = 24, DIGIT_H = 40;        // 3x5 font scaled by 8
    localparam DIGL_X    = H_VISIBLE / 2 - 40 - DIGIT_W;
    localparam DIGR_X    = H_VISIBLE / 2 + 40;
    localparam DIG_Y     = 24;

    wire clk = CLK100MHZ;

    // ------------------------------------------------------------------
    //  Reset and button synchronisers
    // ------------------------------------------------------------------
    reg [1:0] rst_sync = 2'b11;
    always @(posedge clk) rst_sync <= {rst_sync[0], ~CPU_RESETN};
    wire rst = rst_sync[1];

    reg [4:0] btn_s1 = 5'd0, btn_s2 = 5'd0;
    always @(posedge clk) begin
        btn_s1 <= {BTNC, BTNU, BTNL, BTNR, BTND};
        btn_s2 <= btn_s1;
    end
    wire b_serve = btn_s2[4];
    wire b_lup   = btn_s2[3];
    wire b_ldn   = btn_s2[2];
    wire b_rup   = btn_s2[1];
    wire b_rdn   = btn_s2[0];

    // free-running bit used to pick the serve direction "randomly"
    reg rnd = 1'b0;
    always @(posedge clk) rnd <= ~rnd;

    // ------------------------------------------------------------------
    //  25 MHz pixel enable and H/V counters
    // ------------------------------------------------------------------
    reg [1:0] pix_div = 2'd0;
    always @(posedge clk) pix_div <= pix_div + 2'd1;
    wire pix_en = (pix_div == 2'd3);

    reg [9:0] hc = 10'd0;
    reg [9:0] vc = 10'd0;
    always @(posedge clk) begin
        if (pix_en) begin
            if (hc == H_TOTAL - 1) begin
                hc <= 10'd0;
                vc <= (vc == V_TOTAL - 1) ? 10'd0 : vc + 10'd1;
            end else begin
                hc <= hc + 10'd1;
            end
        end
    end

    wire hs_n   = ~((hc >= H_VISIBLE + H_FP) && (hc < H_VISIBLE + H_FP + H_SYNC));
    wire vs_n   = ~((vc >= V_VISIBLE + V_FP) && (vc < V_VISIBLE + V_FP + V_SYNC));
    wire active = (hc < H_VISIBLE) && (vc < V_VISIBLE);

    // one pulse per frame, on the first line of vertical blanking
    wire frame_tick = pix_en && (hc == 10'd0) && (vc == V_VISIBLE);

    // ------------------------------------------------------------------
    //  Game state
    // ------------------------------------------------------------------
    reg [9:0] padl_y     = PAD_Y0;
    reg [9:0] padr_y     = PAD_Y0;
    reg [9:0] ball_x     = BALL_X0;
    reg [9:0] ball_y     = BALL_Y0;
    reg       ball_right = 1'b1;        // 1 = moving right
    reg       ball_down  = 1'b1;        // 1 = moving down
    reg [2:0] ball_dx    = BALL_DX0;    // horizontal speed (px/frame)
    reg [2:0] ball_dy    = 3'd1;        // vertical speed   (px/frame)
    reg [1:0] hit_cnt    = 2'd0;        // speed-up every 4 paddle hits
    reg [3:0] score_l    = 4'd0;
    reg [3:0] score_r    = 4'd0;
    reg       playing    = 1'b0;        // 0 = waiting for serve
    reg       serve_right= 1'b1;        // direction of the next serve
    reg       serve_prev = 1'b0;
    reg [5:0] frame_cnt  = 6'd0;        // for blinking the winner's score

    wire game_over  = (score_l == WIN_SCORE) || (score_r == WIN_SCORE);
    wire serve_edge = b_serve && !serve_prev;

    // ---------------- paddles ----------------
    always @(posedge clk) begin
        if (rst) begin
            padl_y <= PAD_Y0;
            padr_y <= PAD_Y0;
        end else if (frame_tick) begin
            if (b_lup && !b_ldn && padl_y >= FIELD_TOP + PAD_SPEED)
                padl_y <= padl_y - PAD_SPEED;
            else if (b_ldn && !b_lup && padl_y + PAD_H + PAD_SPEED <= FIELD_BOT)
                padl_y <= padl_y + PAD_SPEED;

            if (b_rup && !b_rdn && padr_y >= FIELD_TOP + PAD_SPEED)
                padr_y <= padr_y - PAD_SPEED;
            else if (b_rdn && !b_rup && padr_y + PAD_H + PAD_SPEED <= FIELD_BOT)
                padr_y <= padr_y + PAD_SPEED;
        end
    end

    // ---------------- ball: next-state (combinational) ----------------
    reg [10:0]        bx_n, by_n;
    reg               right_n, down_n;
    reg [2:0]         dx_n, dy_n;
    reg [1:0]         hitcnt_n;
    reg               hit_l, hit_r, score_l_ev, score_r_ev;
    reg signed [11:0] rel;              // ball centre relative to paddle top
    reg [9:0]         pad_hit_y;

    always @* begin
        bx_n       = {1'b0, ball_x};
        by_n       = {1'b0, ball_y};
        right_n    = ball_right;
        down_n     = ball_down;
        dx_n       = ball_dx;
        dy_n       = ball_dy;
        hitcnt_n   = hit_cnt;
        hit_l      = 1'b0;
        hit_r      = 1'b0;
        score_l_ev = 1'b0;
        score_r_ev = 1'b0;
        rel        = 12'sd0;
        pad_hit_y  = padl_y;

        // --- vertical motion, bounce off the walls ---
        if (ball_down) begin
            if (ball_y + BALL_SZ + ball_dy >= FIELD_BOT) begin
                by_n   = FIELD_BOT - BALL_SZ;
                down_n = 1'b0;
            end else begin
                by_n   = ball_y + ball_dy;
            end
        end else begin
            if (ball_y < FIELD_TOP + ball_dy) begin
                by_n   = FIELD_TOP;
                down_n = 1'b1;
            end else begin
                by_n   = ball_y - ball_dy;
            end
        end

        // --- horizontal motion, paddles and scoring ---
        if (ball_right) begin
            bx_n = ball_x + ball_dx;
            if (bx_n + BALL_SZ > H_VISIBLE) begin
                score_l_ev = 1'b1;                      // left player scores
            end else if ((ball_x + BALL_SZ <= PADR_X) &&  // was in front of paddle
                         (bx_n + BALL_SZ > PADR_X)   &&   // would cross its face
                         (ball_y + BALL_SZ > padr_y) &&
                         (ball_y < padr_y + PAD_H)) begin
                hit_r     = 1'b1;
                bx_n      = PADR_X - BALL_SZ;
                right_n   = 1'b0;
                pad_hit_y = padr_y;
            end
        end else begin
            if (ball_x < ball_dx) begin
                score_r_ev = 1'b1;                      // right player scores
            end else begin
                bx_n = ball_x - ball_dx;
                if ((ball_x >= PADL_X + PAD_W) &&
                    (bx_n < PADL_X + PAD_W)    &&
                    (ball_y + BALL_SZ > padl_y) &&
                    (ball_y < padl_y + PAD_H)) begin
                    hit_l     = 1'b1;
                    bx_n      = PADL_X + PAD_W;
                    right_n   = 1'b1;
                    pad_hit_y = padl_y;
                end
            end
        end

        // --- paddle hit: angle depends on where the ball struck ---
        if (hit_l || hit_r) begin
            rel = $signed({2'b00, ball_y}) + 12'sd4 - $signed({2'b00, pad_hit_y});
            if      (rel < 12'sd8)  begin dy_n = 3'd3; down_n = 1'b0; end
            else if (rel < 12'sd16) begin dy_n = 3'd2; down_n = 1'b0; end
            else if (rel < 12'sd24) begin dy_n = 3'd1; down_n = 1'b0; end
            else if (rel < 12'sd40) begin dy_n = ball_dy;             end // centre: keep angle
            else if (rel < 12'sd48) begin dy_n = 3'd1; down_n = 1'b1; end
            else if (rel < 12'sd56) begin dy_n = 3'd2; down_n = 1'b1; end
            else                    begin dy_n = 3'd3; down_n = 1'b1; end

            hitcnt_n = hit_cnt + 2'd1;
            if (hit_cnt == 2'd3 && ball_dx < BALL_DXMAX)
                dx_n = ball_dx + 3'd1;
        end
    end

    // ---------------- ball / score: registered update ----------------
    always @(posedge clk) begin
        if (rst) begin
            ball_x      <= BALL_X0;
            ball_y      <= BALL_Y0;
            ball_right  <= 1'b1;
            ball_down   <= 1'b1;
            ball_dx     <= BALL_DX0;
            ball_dy     <= 3'd1;
            hit_cnt     <= 2'd0;
            score_l     <= 4'd0;
            score_r     <= 4'd0;
            playing     <= 1'b0;
            serve_right <= 1'b1;
            serve_prev  <= 1'b0;
            frame_cnt   <= 6'd0;
        end else if (frame_tick) begin
            serve_prev <= b_serve;
            frame_cnt  <= frame_cnt + 6'd1;

            if (!playing) begin
                ball_x <= BALL_X0;
                ball_y <= BALL_Y0;
                if (serve_edge) begin
                    if (game_over) begin
                        score_l <= 4'd0;
                        score_r <= 4'd0;
                    end
                    playing    <= 1'b1;
                    ball_right <= serve_right;
                    ball_down  <= rnd;
                    ball_dx    <= BALL_DX0;
                    ball_dy    <= 3'd1;
                    hit_cnt    <= 2'd0;
                end
            end else begin
                ball_x     <= bx_n[9:0];
                ball_y     <= by_n[9:0];
                ball_right <= right_n;
                ball_down  <= down_n;
                ball_dx    <= dx_n;
                ball_dy    <= dy_n;
                hit_cnt    <= hitcnt_n;
                if (score_l_ev) begin
                    score_l     <= score_l + 4'd1;
                    playing     <= 1'b0;
                    serve_right <= 1'b1;        // serve toward the player who lost
                end
                if (score_r_ev) begin
                    score_r     <= score_r + 4'd1;
                    playing     <= 1'b0;
                    serve_right <= 1'b0;
                end
            end
        end
    end

    // ------------------------------------------------------------------
    //  Rendering
    // ------------------------------------------------------------------
    // 3x5 digit font, bit 14 = top-left, bit 0 = bottom-right
    function [14:0] font;
        input [3:0] d;
        begin
            case (d)
                4'd0: font = 15'b111_101_101_101_111;
                4'd1: font = 15'b010_110_010_010_111;
                4'd2: font = 15'b111_001_111_100_111;
                4'd3: font = 15'b111_001_111_001_111;
                4'd4: font = 15'b101_101_111_001_001;
                4'd5: font = 15'b111_100_111_001_111;
                4'd6: font = 15'b111_100_111_101_111;
                4'd7: font = 15'b111_001_001_001_001;
                4'd8: font = 15'b111_101_111_101_111;
                4'd9: font = 15'b111_101_111_001_111;
                default: font = 15'b000_000_000_000_000;
            endcase
        end
    endfunction

    wire [9:0] px = hc;
    wire [9:0] py = vc;

    wire in_wall = (py < WALL_T) || (py >= FIELD_BOT);
    wire in_net  = (px >= NET_X) && (px < NET_X + 4) && !py[4];   // 16 on / 16 off
    wire in_padl = (px >= PADL_X) && (px < PADL_X + PAD_W) &&
                   (py >= padl_y) && (py < padl_y + PAD_H);
    wire in_padr = (px >= PADR_X) && (px < PADR_X + PAD_W) &&
                   (py >= padr_y) && (py < padr_y + PAD_H);
    wire in_ball = (px >= ball_x) && (px < ball_x + BALL_SZ) &&
                   (py >= ball_y) && (py < ball_y + BALL_SZ);

    // score digits
    wire        dig_row_ok = (py >= DIG_Y) && (py < DIG_Y + DIGIT_H);
    wire [9:0]  dig_dy     = py - DIG_Y;
    wire [2:0]  dig_row    = dig_dy[5:3];             // 0..4
    wire        in_digl_box= dig_row_ok && (px >= DIGL_X) && (px < DIGL_X + DIGIT_W);
    wire        in_digr_box= dig_row_ok && (px >= DIGR_X) && (px < DIGR_X + DIGIT_W);
    wire [9:0]  digl_dx    = px - DIGL_X;
    wire [9:0]  digr_dx    = px - DIGR_X;
    wire [1:0]  digl_col   = digl_dx[4:3];            // 0..2
    wire [1:0]  digr_col   = digr_dx[4:3];
    wire [3:0]  digl_idx   = dig_row * 3 + digl_col;  // 0..14
    wire [3:0]  digr_idx   = dig_row * 3 + digr_col;
    wire [14:0] font_l     = font(score_l);
    wire [14:0] font_r     = font(score_r);
    wire        in_digl    = in_digl_box && font_l[4'd14 - digl_idx];
    wire        in_digr    = in_digr_box && font_r[4'd14 - digr_idx];

    // blink the winner's digit when the game is over
    wire blink     = frame_cnt[4];
    wire show_digl = in_digl && !(game_over && score_l == WIN_SCORE && blink);
    wire show_digr = in_digr && !(game_over && score_r == WIN_SCORE && blink);

    reg [11:0] rgb;
    always @* begin
        if      (in_ball)              rgb = 12'hFFF;   // white
        else if (in_padl)              rgb = 12'h4CF;   // light blue
        else if (in_padr)              rgb = 12'hF84;   // orange
        else if (show_digl)            rgb = 12'h4CF;
        else if (show_digr)            rgb = 12'hF84;
        else if (in_wall)              rgb = 12'hCCC;
        else if (in_net)               rgb = 12'h666;
        else                           rgb = 12'h000;
    end

    always @(posedge clk) begin
        if (pix_en) begin
            VGA_HS <= hs_n;
            VGA_VS <= vs_n;
            {VGA_R, VGA_G, VGA_B} <= active ? rgb : 12'h000;
        end
    end

    // ------------------------------------------------------------------
    //  7-segment display: left score on AN7, right score on AN0
    // ------------------------------------------------------------------
    function [6:0] seg7;                 // {g,f,e,d,c,b,a}, active low
        input [3:0] d;
        begin
            case (d)
                4'd0: seg7 = 7'b1000000;
                4'd1: seg7 = 7'b1111001;
                4'd2: seg7 = 7'b0100100;
                4'd3: seg7 = 7'b0110000;
                4'd4: seg7 = 7'b0011001;
                4'd5: seg7 = 7'b0010010;
                4'd6: seg7 = 7'b0000010;
                4'd7: seg7 = 7'b1111000;
                4'd8: seg7 = 7'b0000000;
                4'd9: seg7 = 7'b0010000;
                default: seg7 = 7'b1111111;
            endcase
        end
    endfunction

    reg [16:0] mux_cnt = 17'd0;
    always @(posedge clk) mux_cnt <= mux_cnt + 17'd1;
    wire mux_sel = mux_cnt[16];          // ~760 Hz per digit

    always @* begin
        AN  = mux_sel ? 8'b1111_1110 : 8'b0111_1111;
        SEG = seg7(mux_sel ? score_r : score_l);
    end
    assign DP = 1'b1;

endmodule
