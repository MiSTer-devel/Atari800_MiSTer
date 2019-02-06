//============================================================================
//  Atari 800 replica
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
	inout  [44:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	input         TAPE_IN,

	// SD-SPI
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

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	input         OSD_STATUS
);

assign {UART_RTS, UART_TXD, UART_DTR} = 0;

assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign LED_USER  = vsd_sel & sd_act;
assign LED_DISK  = {1'b1, ~vsd_sel & sd_act};
assign LED_POWER = 0;

assign VIDEO_ARX = status[6] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[6] ? 8'd9  : 8'd3;

wire [5:0] CPU_SPEEDS[8] ='{6'd1,6'd2,6'd4,6'd8,6'd16,6'd0,6'd0,6'd0};

`include "build_id.v" 
localparam CONF_STR = {
	"ATARI800;;",
	"-;",
	"RG,Drives and Cart;",
	"S,VHD;",
	"-;",
	"O79,CPU Speed,1x,2x,4x,8x,16x;",
	"OAC,Drive Speed,Standard,Fast-6,Fast-5,Fast-4,Fast-3,Fast-2,Fast-1,Fast-0;",
	"-;",
	"ODF,RAM,64K,128K,320K(Compy),320K(Rambo),576K(Compy),576K(Rambo),1MB;",
	"-;",
	"O5,Video mode,PAL,NTSC;",
	"O6,Aspect ratio,4:3,16:9;",
	"OHJ,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"O34,Stereo mix,None,25%,50%,100%;",
	"-;",
	"R0,Reset;",
	"J,Fire 1,Fire 2,Fire 3,Paddle LT,Paddle RT,ROM Select;",
	"V,v1.22.",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire locked;
wire clk_sys;
wire clk_mem;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_mem),
	.outclk_1(SDRAM_CLK),
	.outclk_2(clk_sys),
	.locked(locked)
);

wire reset = RESET | status[0] | ~initReset_n | buttons[1] | img_mounted;

reg initReset_n = 0;
always @(posedge clk_sys) begin
	integer timeout = 0;
	
	if(timeout < 5000000) timeout <= timeout + 1;
	else initReset_n <= 1;
end

//////////////////   HPS I/O   ///////////////////
wire [15:0] joy_0;
wire [15:0] joy_1;
wire [15:0] joya_0;
wire [15:0] joya_1;
wire  [1:0] buttons;
wire [31:0] status;
wire [24:0] ps2_mouse;

wire PS2_CLK;
wire PS2_DAT;

wire forced_scandoubler;

wire [31:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;
wire        sd_ack_conf;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.joystick_0(joy_0),
	.joystick_1(joy_1),
	.joystick_analog_0(joya_0),
	.joystick_analog_1(joya_1),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),

	.ps2_kbd_clk_out(PS2_CLK),
	.ps2_kbd_data_out(PS2_DAT),
	
	.ps2_kbd_led_use(0),
	.ps2_kbd_led_status(0),

	.ps2_mouse(ps2_mouse),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_ack_conf(sd_ack_conf),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.ioctl_wait(0)
);

reg menu = 0;
always @(posedge clk_sys) begin
	integer timeout = 0;

	if(timeout) timeout <= timeout - 1;
	menu <= |timeout;
	
	if(status[16]) timeout <= 28000000;
end


wire [7:0] R,G,B;
wire HBlank,VBlank;
wire VSync, HSync;
wire ce_pix;

assign CLK_VIDEO = clk_sys;

wire cpu_halt;

wire [15:0] laudio, raudio;
assign AUDIO_R = {raudio[15],raudio[15:1]};
assign AUDIO_L = {laudio[15],laudio[15:1]};
assign AUDIO_S = 1;
assign AUDIO_MIX = status[4:3];

atari800top atari800top
(
	.CLK(clk_sys),
	.CLK_SDRAM(clk_mem),
	.RESET_N(~reset),

	.SDRAM_BA(SDRAM_BA),
	.SDRAM_nCS(SDRAM_nCS),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_nWE(SDRAM_nWE),
	.SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_DQML(SDRAM_DQML),
	.SDRAM_CKE(SDRAM_CKE),
	.SDRAM_A(SDRAM_A),
	.SDRAM_DQ(SDRAM_DQ),

	.PAL(~status[5]),
	.VGA_VS(VSync),
	.VGA_HS(HSync),
	.VGA_B(B),
	.VGA_G(G),
	.VGA_R(R),
	.VGA_PIXCE(ce_pix),
	.HBLANK(HBlank),
	.VBLANK(VBlank),

	.CPU_SPEED(CPU_SPEEDS[status[9:7]]),
	.RAM_SIZE(status[15:13]),
	.DRV_SPEED(status[12:10]),
	.MENU(menu),

	.AUDIO_L(laudio),
	.AUDIO_R(raudio),

	.SD_CLK(sdclk),
	.SD_DAT3(sdss),
	.SD_CMD(sdmosi),
	.SD_DAT0(sdmiso),

	.CPU_HALT(cpu_halt),

	.PS2_CLK(PS2_CLK),
	.PS2_DAT(PS2_DAT),

	.JOY1X(ax),
	.JOY1Y(ay),
	.JOY2X(joya_1[7:0]),
	.JOY2Y(joya_1[15:8]),

	.JOY1(j0),
	.JOY2(joy_1[9:0])
);

assign VGA_F1 = 0;
assign VGA_SL = scale ? scale[1:0] - 1'd1 : 2'd0;

wire [2:0] scale = status[19:17];

video_mixer video_mixer
(
	.*,
	.ce_pix_out(CE_PIXEL),

	.scanlines(0),
	.scandoubler(scale || forced_scandoubler),
	.hq2x(scale==1),
	.mono(0)
);


//////////////////   SD   ///////////////////

wire sdclk;
wire sdmosi;
wire sdmiso = vsd_sel ? vsdmiso : SD_MISO;
wire sdss;

reg vsd_sel = 0;
always @(posedge clk_sys) if(img_mounted) vsd_sel <= |img_size;

wire vsdmiso;
sd_card sd_card
(
	.*,
	.clk_spi(clk_sys),

	.sdhc(1),

	.sck(sdclk),
	.ss(~vsd_sel | sdss),
	.mosi(sdmosi),
	.miso(vsdmiso)
);

assign SD_CS   = vsd_sel | sdss;
assign SD_SCK  = sdclk & ~SD_CS;
assign SD_MOSI = sdmosi & ~SD_CS;

reg sd_act;

always @(posedge clk_sys) begin
	reg old_mosi, old_miso;
	integer timeout = 0;

	old_mosi <= sdmosi;
	old_miso <= sdmiso;

	sd_act <= 0;
	if(timeout < 1000000) begin
		timeout <= timeout + 1;
		sd_act <= 1;
	end

	if((old_mosi ^ sdmosi) || (old_miso ^ sdmiso)) timeout <= 0;
end


//////////////////   ANALOG AXIS   ///////////////////
reg        emu = 0;
wire [7:0] ax = emu ? mx[7:0] : joya_0[7:0];
wire [7:0] ay = emu ? my[7:0] : joya_0[15:8];
wire [9:0] j0 = {joy_0[9], emu ? ps2_mouse[1:0] : joy_0[8:7], joy_0[6:0]};

reg  signed [8:0] mx = 0;
wire signed [8:0] mdx = {ps2_mouse[4],ps2_mouse[4],ps2_mouse[15:9]};
wire signed [8:0] mdx2 = (mdx > 10) ? 9'd10 : (mdx < -10) ? -8'd10 : mdx;
wire signed [8:0] nmx = mx + mdx2;

reg  signed [8:0] my = 0;
wire signed [8:0] mdy = {ps2_mouse[5],ps2_mouse[5],ps2_mouse[23:17]};
wire signed [8:0] mdy2 = (mdy > 10) ? 9'd10 : (mdy < -10) ? -9'd10 : mdy;
wire signed [8:0] nmy = my + mdy2;

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
