///----------------------------------------------------------------------------
//
//  Arcade: Donkey kong 3 by gaz68 (https://github.com/gaz68)
//
//  July 2020
//
//  Based on the original Donkey Kong core by Katsumi Degawa.
//
//  Original Donkey Kong port to MiSTer
//  Copyright (C) 2017 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//----------------------------------------------------------------------------

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output [11:0] VIDEO_ARX,
	output [11:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	// Use framebuffer from DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of 16 bytes.
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,    // 1 - signed audio samples, 0 - unsigned

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT
);


assign VGA_F1 = 0;
assign VGA_SCALER= 0;

assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign {FB_PAL_CLK, FB_FORCE_BLANK, FB_PAL_ADDR, FB_PAL_DOUT, FB_PAL_WR} = '0;

wire [1:0] ar = status[20:19];

assign VIDEO_ARX = (!ar) ? (status[2]  ? 8'd4 : 8'd3) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? (status[2]  ? 8'd3 : 8'd4) : 12'd0;


`include "build_id.v" 
localparam CONF_STR = {
   "A.DKONG3;;",
   "-;",
   "H0OJK,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
   "O2,Orientation,Vert,Horz;",
   "O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
   "O7,Flip Screen,Off,On;",
   "OOS,Analog Video H-Pos,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31;",
   "OTV,Analog Video V-Pos,0,1,2,3,4,5,6,7;",
   "-;",
   "DIP;",
   "-;",

   "R0,Reset;",
   "J1,Jump,Start 1P,Start 2P,Coin,Test;",
   "jn,A,Start,Select,R,;",
   "jn,B,Start,Select,R,;",
   "V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys;
wire clk_main;
wire clk_sub;

pll pll
(
   .refclk(CLK_50M),
   .rst(0),
   .outclk_0(clk_sys),  // 24.576Mhz
   .outclk_1(clk_sub),  // 21.477Mhz
   .outclk_2(clk_main)  // 4Mhz
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_index;


wire [15:0] joy_0, joy_1;
wire [21:0] gamma_bus;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
   .clk_sys(clk_sys),
   .HPS_BUS(HPS_BUS),
   .EXT_BUS(),

   .conf_str(CONF_STR),

   .buttons(buttons),
   .status(status),
   .forced_scandoubler(forced_scandoubler),
   .gamma_bus(gamma_bus),
   .direct_video(direct_video),
   .status_menumask(direct_video),

   .ioctl_download(ioctl_download),
   .ioctl_wr(ioctl_wr),
   .ioctl_addr(ioctl_addr),
   .ioctl_dout(ioctl_dout),
   .ioctl_index(ioctl_index),

   .joystick_0(joy_0),
   .joystick_1(joy_1)
);


wire m_up,m_down,m_left,m_right;
joy8way joy1
(
   clk_sys,
   {
       joy_0[3],
       joy_0[2],
       joy_0[1],
       joy_0[0]
   },
   {m_up,m_down,m_left,m_right}
);

wire m_up_2,m_down_2,m_left_2,m_right_2;
joy8way joy2
(
   clk_sys,
   {
       joy_1[3],
       joy_1[2],
       joy_1[1],
       joy_1[0]
   },
   {m_up_2,m_down_2,m_left_2,m_right_2}
);

wire m_fire   = joy_0[4];
wire m_fire_2 = joy_1[4];

wire m_start1 =  joy_0[5];
wire m_start2 =  joy_0[6] | joy_1[5];
wire m_coin   = joy_0[7] | joy_1[7];

wire m_test = joy_0[8] | joy_1[8];

wire coinpulse;
shortpulse coin
(
   clk_sys,
   m_coin,
   coinpulse
);

wire [7:0]m_sw1={~m_test,~{m_start2},~{m_start1},~m_fire,~m_down,~m_up,~m_left,~m_right};
wire [7:0]m_sw2={1'b1,1'b1,~coinpulse,~m_fire_2,~m_down_2,~m_up_2,~m_left_2,~m_right_2};


reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;


wire hblank, vblank;
wire hs, vs;
wire [3:0] r,g,b;
wire rotate_ccw = 0;
wire no_rotate = status[2] | direct_video  ;
screen_rotate screen_rotate (.*);

arcade_video#(256,12) arcade_video
(
   .*,

   .clk_video(clk_sys),
   .ce_pix(ce_vid),

   .RGB_in({r,g,b}),
   .HBlank(hblank),
   .VBlank(vblank),
   .HSync(~hs),
   .VSync(~vs),

   .fx(status[5:3])
);


assign AUDIO_S   = 1'b1;
assign AUDIO_L   = muted ? 16'd0 : sample_signed[15:0];
assign AUDIO_R   = AUDIO_L;

wire signed [15:0] sample_signed;

reg muted = 1'b1;
reg [20:0] mute_cnt = 21'h1FFFFF;

// Pause audio to avoid loud "POP"
//always_ff @(posedge clk_sub) begin
always_ff @(posedge clk_sys) begin
   if (reset)
      mute_cnt <= 21'h1FFFFF;
   else if (|mute_cnt)
      mute_cnt <= mute_cnt - 1'b1;
end

// Pause audio to avoid loud "POP"
always_ff @(posedge clk_sys) begin
//always_ff @(posedge clk_sub) begin
   if (mute_cnt=='d0)
		muted=1'b0;
end

assign hblank = hbl[8];

reg  ce_vid;
wire clk_pix;
wire hbl0;
reg [8:0] hbl;
always @(posedge clk_sys) begin
   reg old_pix;
   old_pix <= clk_pix;
   ce_vid <= 0;
   if(~old_pix & clk_pix) begin
      ce_vid <= 1;
      hbl <= (hbl<<1)|hbl0;
   end
end

reg reset;
always @(posedge clk_sys)
  reset = RESET | status[0] | buttons[1];

dkong3_top dkong3 
(
   .I_CLK_24M(clk_sys),
   .I_CLK_4M(clk_main),
   .I_SUBCLK(clk_sub),
   .I_RESETn(~reset),

   .I_SW1(m_sw1),
   .I_SW2(m_sw2),
   .I_DIP_SW1(sw[0]),
   .I_DIP_SW2(sw[1]),

   .dn_addr(ioctl_addr),
   .dn_data(ioctl_dout),
   .dn_wr(ioctl_wr && ioctl_index==0),

   .O_VGA_R(r),
   .O_VGA_G(g),
   .O_VGA_B(b),
   .O_VGA_HSYNCn(hs),
   .O_VGA_VSYNCn(vs),
   .O_HBLANK(hbl0),
   .O_VBLANK(vblank),

   .flip_screen(status[7]),
   .H_OFFSET(status[28:24]),
   .V_OFFSET(status[31:29]),

   .O_PIX(clk_pix),
   .O_SOUND_DAT(sample_signed)
);

endmodule

// Handle the case where Up and Down are pressed simultaneously
// and the same for Left and Right i.e. when using a keyboard.
module joy8way
(
   input        clk,
   input  [3:0] indir,
   output [3:0] outdir
);

reg   [3:0] out = 0;
reg   [3:0] in1,in2;
wire  [3:0] innew = in1 & ~in2;
reg   [1:0] last_h,last_v;

assign outdir = out;

always @(posedge clk) begin

   in1 <= indir;
   in2 <= in1;

   if(innew[0]) last_h <= 2'b01; // R
   if(innew[1]) last_h <= 2'b10; // L
   if(innew[2]) last_v <= 2'b01; // D
   if(innew[3]) last_v <= 2'b10; // U

   out[1:0] <= in1[1:0] == 2'b11 ? last_h : in1[1:0]; 
   out[3:2] <= in1[3:2] == 2'b11 ? last_v : in1[3:2]; 
end

endmodule

// Generates a short pulse at the 
// end of the input signal.
module shortpulse
(
   input    clk,
   input    inp,
   output   pulse
);

reg        out;
reg [19:0] pulse_cnt = 0;

always_ff @(posedge clk) begin

   reg old_inp;
   out <= 1'b0;

   if (|pulse_cnt) begin
      pulse_cnt <= pulse_cnt - 1'b1;
      out <= 1'b1;
   end else begin
      old_inp <= inp;
      if (old_inp && !inp) pulse_cnt <= 20'hFFFFF;
   end

end

assign pulse = out;

endmodule
