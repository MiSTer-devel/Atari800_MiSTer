//============================================================================
//  Atari 5200 replica
// 
//  Port to MiSTer
//  Copyright (C) 2017-2019 Sorgelig
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
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

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

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z; 

assign LED_USER  = file_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

wire [1:0] ar       = status[23:22];
wire       vcrop_en = status[24];
wire [3:0] vcopt    = status[28:25];
reg        en216p;
reg  [4:0] voff;
always @(posedge CLK_VIDEO) begin
	en216p <= ((HDMI_WIDTH == 1920) && (HDMI_HEIGHT == 1080) && !forced_scandoubler && !scale);
	voff <= (vcopt < 6) ? {vcopt,1'b0} : ({vcopt,1'b0} - 5'd24);
end

wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? 12'd4 : (ar - 1'd1)),
	.ARY((!ar) ? 12'd3 : 12'd0),
	.CROP_SIZE((en216p & vcrop_en) ? 10'd216 : 10'd0),
	.CROP_OFF(voff),
	.SCALE(status[30:29])
);

wire [5:0] CPU_SPEEDS[8] ='{6'd1,6'd2,6'd4,6'd8,6'd16,6'd0,6'd0,6'd0};

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// X  XXXXXXX       XXX  XXXXXXXXX    X     X               X

`include "build_id.v" 
localparam CONF_STR = {
	"ATARI5200;;",
	"-;",
	"F1,CARA52BINROM,Load Cart;",
	"-;",
	"O79,CPU Speed,1x,2x,4x,8x,16x;",
	"-;",
	"OMN,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"OHJ,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"o2,Clip Sides,Off,On;",
	"d0OO,Vertical Crop,Disabled,216p(5x);",
	"d0OPS,Crop Offset,0,2,4,8,10,12,-12,-10,-8,-6,-4,-2;",
	"OTU,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"-;",
	"O34,Stereo mix,None,25%,50%,100%;",
	"O5,Swap Joysticks 1&2,No,Yes;",
	"oO,Mouse X,Normal,Inverted;",
	"O6,Mouse Y,Normal,Inverted;",
	"-;",
	"r8,Cold Reset (F10);",
  	"R0,Reset (Detach Carts);",
	"J1,Fire 1,Fire 2,*,#,Start,Pause,Reset,0,1,2,3,4,5,6,7,8,9;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire locked;
wire clk_sys;
wire clk_mem;
wire clk_vdo;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(clk_mem),
	.outclk_2(clk_vdo),
	.locked(locked)
);

wire reset = RESET;

//////////////////   HPS I/O   ///////////////////
wire [20:0] joy_0;
wire [20:0] joy_1;
wire [20:0] joy_2;
wire [20:0] joy_3;
wire [15:0] joya_0;
wire [15:0] joya_1;
wire [15:0] joya_2;
wire [15:0] joya_3;
wire  [1:0] buttons;
wire [63:0] status;
wire [24:0] ps2_mouse;
wire [10:0] ps2_key;
wire        forced_scandoubler;
wire [21:0] gamma_bus;

wire  [7:0] ioctl_index;
wire [26:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
reg         ioctl_wait = 1;
wire        ioctl_wr;

wire [35:0] EXT_BUS;
wire  [7:0] cart_select;
wire        set_reset;
wire        set_pause;
wire        sdram_ready;
wire        dma_ready;
reg         dma_req = 0;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.joystick_0(joy_0),
	.joystick_1(joy_1),
	.joystick_2(joy_2),
	.joystick_3(joy_3),
	.joystick_l_analog_0(joya_0),
	.joystick_l_analog_1(joya_1),
	.joystick_l_analog_2(joya_2),
	.joystick_l_analog_3(joya_3),

	.buttons(buttons),
	.status(status),
	.status_menumask({en216p}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),

	.ioctl_index(ioctl_index),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_wait(ioctl_wait),
	.ioctl_wr(ioctl_wr),
	
	.EXT_BUS(EXT_BUS)
);

hps_ext hps_ext
(
	.clk_sys(clk_sys),
	.EXT_BUS(EXT_BUS),

	.set_reset(set_reset),
	.set_pause(set_pause),
	.cart1_select(cart_select),
	.atari_status1(atari_status1),

	.atari_status2(0),
	.uart_data_read(0)
);


wire [7:0] R,G,B;
wire HBlank,VBlank;
wire VSync, HSync;
wire ce_pix;
wire ce_pix_raw;

assign CLK_VIDEO = clk_vdo;

wire joy_d1ena = ~&joya_0;
wire joy_d2ena = ~&joya_1;
wire joy_d3ena = ~&joya_2;
wire joy_d4ena = ~&joya_3;

wire cpu_halt;

wire [15:0] laudio, raudio;
assign AUDIO_R = (cpu_halt | reset) ? 16'b0000000000000000 : {raudio[15],raudio[15:1]};
assign AUDIO_L = (cpu_halt | reset) ? 16'b0000000000000000 : {laudio[15],laudio[15:1]};
assign AUDIO_S = 1;
assign AUDIO_MIX = status[4:3];

assign SDRAM_CKE = 1;

atari5200top atari5200top
(
	.CLK(clk_sys),
	.CLK_SDRAM(clk_mem),
	.RESET_N(~reset),

	.SDRAM_BA(SDRAM_BA),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_nWE(SDRAM_nWE),
	.SDRAM_A(SDRAM_A),
	.SDRAM_DQ(SDRAM_DQ),
	.SDRAM_nCS(SDRAM_nCS),
	.SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_DQML(SDRAM_DQML),

	.ROM_ADDR(rom_addr),
	.ROM_DATA(rom_data),

	.SDRAM_READY(sdram_ready),
	.OSD_PAUSE(file_download),
	.SET_RESET_IN(set_reset),
	.SET_PAUSE_IN(set_pause),
	.CART_SELECT_IN(cart_select),
	.HOT_KEYS(atari_hotkeys),
	.COLD_RESET_MENU(status[40] | buttons[1]),
	.HPS_DMA_ADDR(ioctl_index == 0 ? {15'b100111000001000, ioctl_addr[10:0]} : ioctl_addr[25:0]),
	.HPS_DMA_REQ(dma_req),
	.HPS_DMA_DATA_OUT(ioctl_dout),
	.HPS_DMA_READY(dma_ready),

	.VGA_VS(VSync),
	.VGA_HS(HSync),
	.VGA_B(B),
	.VGA_G(G),
	.VGA_R(R),
	.VGA_PIXCE(ce_pix_raw),
	.HBLANK(HBlank),
	.VBLANK(VBlank),

	.CPU_SPEED(CPU_SPEEDS[status[9:7]]),

	.CLIP_SIDES(status[34]),
	.AUDIO_L(laudio),
	.AUDIO_R(raudio),

	.CPU_HALT(cpu_halt),

	.PS2_KEY(ps2_key),

	.JOY1X(status[5] ? joya_1[7:0] : ax),
	.JOY1Y(status[5] ? joya_1[15:8] : ay),
	.JOY2X(status[5] ? ax : joya_1[7:0]),
	.JOY2Y(status[5] ? ay : joya_1[15:8]),
	.JOY3X(joya_2[7:0]),
	.JOY3Y(joya_2[15:8]),
	.JOY4X(joya_3[7:0]),
	.JOY4Y(joya_3[15:8]),

	.JOY1((status[5] ? joy_1 : j0) & {17'b11111111111111111, {4{joy_d1ena}}}),
	.JOY2((status[5] ? j0 : joy_1) & {17'b11111111111111111, {4{joy_d2ena}}}),
	.JOY3(joy_2 & {17'b11111111111111111, {4{joy_d3ena}}}),
	.JOY4(joy_3 & {17'b11111111111111111, {4{joy_d4ena}}})
);

altddio_out
#(
	.extend_oe_disable("OFF"),
	.intended_device_family("Cyclone V"),
	.invert_output("OFF"),
	.lpm_hint("UNUSED"),
	.lpm_type("altddio_out"),
	.oe_reg("UNREGISTERED"),
	.power_up_high("OFF"),
	.width(1)
)
sdramclk_ddr
(
	.datain_h(1'b0),
	.datain_l(1'b1),
	.outclock(clk_mem),
	.dataout(SDRAM_CLK),
	.aclr(1'b0),
	.aset(1'b0),
	.oe(1'b1),
	.outclocken(1'b1),
	.sclr(1'b0),
	.sset(1'b0)
); 

assign VGA_F1 = 0;
assign VGA_SL = scale ? scale[1:0] - 1'd1 : 2'd0;

wire [2:0] scale = status[19:17];

reg ce_pix_raw_old = 0;
assign ce_pix = ce_pix_raw & ~ce_pix_raw_old;

always @(posedge CLK_VIDEO) begin
	ce_pix_raw_old <= ce_pix_raw;
end

video_mixer #(.GAMMA(1)) video_mixer
(
	.*,
	.scandoubler(scale || forced_scandoubler),
	.hq2x(scale==1),
	.freeze_sync(),
	.VGA_DE(vga_de)
);

//////////////////   ROM   ///////////////////

wire  [7:0] rom_data;
wire [10:0] rom_addr;

dpram #(11, 8, "rtl/rom/5200.mif") bios_5200
(
	.clock(clk_sys),

	.address_a(ioctl_addr[10:0]),
	.data_a(ioctl_dout),
	.wren_a(ioctl_wr && (ioctl_index == 0)), // boot.rom download from the main

	.address_b(rom_addr),
	.q_b(rom_data)
);

//////////////////   IO   ///////////////////

wire  [2:0] atari_hotkeys;
wire file_download = ioctl_download && ioctl_index != 99;

wire [15:0] atari_status1;
assign atari_status1 = {13'b0000000000000, atari_hotkeys};

always @(posedge clk_sys) begin

	reg started = 0;

	if(sdram_ready) begin
		if(!started) begin
			started <= 1;
			ioctl_wait <= 0;
		end
		if(ioctl_index != 0 && ioctl_download) begin
			if(dma_ready) begin
				ioctl_wait <= 0;
				dma_req <= 0;
			end
			if(ioctl_wr) begin
				ioctl_wait <= 1;
				dma_req <= 1;
			end
		end
		else
			ioctl_wait <= 0;
	end
end

//////////////////   ANALOG AXIS   ///////////////////
reg         emu = 0;
wire  [7:0] ax = emu ? mx[7:0] : joya_0[7:0];
wire  [7:0] ay = emu ? my[7:0] : joya_0[15:8];
wire [20:0] j0 = emu ? {joy_0[20:6], ps2_mouse[1:0], joy_0[3:0]} : joy_0;

reg  signed [8:0] mx = 0;
wire signed [8:0] mdx = {ps2_mouse[4],ps2_mouse[4],ps2_mouse[15:9]};
wire signed [8:0] mdx2 = (mdx > 10) ? 9'd10 : (mdx < -10) ? -8'd10 : mdx;
wire signed [8:0] nmx = status[56] ? (mx - mdx2) : (mx + mdx2);

reg  signed [8:0] my = 0;
wire signed [8:0] mdy = {ps2_mouse[5],ps2_mouse[5],ps2_mouse[23:17]};
wire signed [8:0] mdy2 = (mdy > 10) ? 9'd10 : (mdy < -10) ? -9'd10 : mdy;
wire signed [8:0] nmy = status[6] ? (my - mdy2) : (my + mdy2);

always @(posedge clk_sys) begin
	reg old_stb = 0;
	
	old_stb <= ps2_mouse[24];
	if(old_stb != ps2_mouse[24]) begin
		emu <= 1;
		mx <= (nmx < -128) ? -9'd128 : (nmx > 127) ? 9'd127 : nmx;
		my <= (nmy < -128) ? -9'd128 : (nmy > 127) ? 9'd127 : nmy;
	end

	if(joya_0 || cpu_halt) begin
		emu <= 0;
		mx <= 0;
		my <= 0;
	end
end

endmodule
