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
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z; 

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign VIDEO_ARX = status[6] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[6] ? 8'd9  : 8'd3;

wire [5:0] CPU_SPEEDS[8] ='{6'd1,6'd2,6'd4,6'd8,6'd16,6'd0,6'd0,6'd0};

`include "build_id.v" 
localparam CONF_STR = {
	"ATARI800;;",
	"S0,ATRXEXXFD,Mount Drive 1;",
	"S1,ATRXEXXFD,Mount Drive 2;",
	"S2,CARROM,Load Cart;",
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
	"V,v",`BUILD_DATE
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

wire reset = RESET | status[0] | ~initReset_n | buttons[1];

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

reg  [31:0] sd_lba;
reg   [2:0] sd_rd;
reg   [2:0] sd_wr;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire  [2:0] img_mounted;
wire        img_readonly;
wire [63:0] img_size;
wire        sd_ack_conf;

wire [13:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_wr;
wire        ioctl_download;
wire  [7:0] ioctl_index;

hps_io #(.STRLEN($size(CONF_STR)>>3), .VDNUM(3)) hps_io
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

	.ioctl_download(ioctl_download),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_index(ioctl_index)
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

wire  [7:0]	ZPU_IN2;
wire [31:0]	ZPU_OUT2;
wire [31:0]	ZPU_IN3;
wire [31:0]	ZPU_OUT3;
wire [15:0]	ZPU_RD;
wire [15:0]	ZPU_WR;

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

	.ZPU_IN2(ZPU_IN2),
	.ZPU_OUT2(ZPU_OUT2),
	.ZPU_IN3(ZPU_IN3),
	.ZPU_OUT3(ZPU_OUT3),
	.ZPU_RD(ZPU_RD),
	.ZPU_WR(ZPU_WR),
	
	.CPU_HALT(cpu_halt),

	.PS2_CLK(PS2_CLK),
	.PS2_DAT(PS2_DAT),

	.OSROM_ADDR(osrom_addr),
	.OSROM_DATA(ioctl_dout),
	.OSROM_WR(osrom_wr),

	.BASROM_ADDR(ioctl_addr[12:0]),
	.BASROM_DATA(ioctl_dout),
	.BASROM_WR(ioctl_wr && ioctl_index[7:6] == 1),

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

reg [13:0] osrom_addr;
reg        osrom_wr;
always @(posedge clk_sys) begin
	osrom_wr <= 0;
	if(osrom_wr) osrom_addr <= osrom_addr + 1'd1;
	if(ioctl_wr) begin
		if(ioctl_index[7:6] == 0) begin
			osrom_addr <= ioctl_addr;
			osrom_wr <= ioctl_wr;
		end
	end
end

//////////////////   SD   ///////////////////

dpram #(9,8) sdbuf
(
	.clock(clk_sys),

	.address_a(sd_buff_addr),
	.data_a(sd_buff_dout),
	.wren_a(sd_buff_wr),
	.q_a(sd_buff_din),

	.address_b(zpu_buff_addr),
	.data_b(ZPU_OUT3[7:0]),
	.wren_b(zpu_buf_wr),
	.q_b(zpu_buf_q)
);

wire[7:0] zpu_buf_q;

assign ZPU_IN2[0]   = zpu_io_done;
assign ZPU_IN2[1]   = zpu_mounted;
assign ZPU_IN2[4:2] = zpu_fileno;
assign ZPU_IN2[6:5] = zpu_filetype;
assign ZPU_IN2[7]   = zpu_readonly;

assign ZPU_IN3 = zpu_lba ? zpu_filesize : zpu_buf_q;

reg [8:0] zpu_buff_addr;
reg       zpu_buf_wr;
reg       zpu_io_done;
reg       zpu_mounted = 0;
reg [2:0] zpu_fileno;
reg [1:0] zpu_filetype;
reg       zpu_readonly;
reg[31:0] zpu_filesize;

wire      zpu_lba      = ZPU_OUT2[0];
wire      zpu_block_rd = ZPU_OUT2[1];
wire      zpu_block_wr = ZPU_OUT2[2];
wire[2:0] zpu_drv_num  = ZPU_OUT2[5:3];
wire      zpu_io_wr    = ZPU_WR[5];
wire      zpu_data_wr  = ZPU_WR[6];
wire      zpu_data_rd  = ZPU_RD[2];

always @(posedge clk_sys) begin
	reg old_wr, old_wr2, old_rd, old_lba;
	reg old_blrd, old_blwr, old_ack;
	reg old_mounted;

	zpu_buf_wr <= 0;
	if(zpu_buf_wr) zpu_buff_addr <= zpu_buff_addr + 1'd1;

	old_wr <= zpu_data_wr;
	old_wr2 <= old_wr;
	if(~old_wr2 & old_wr) begin
		if(zpu_lba) sd_lba <= ZPU_OUT3;
		else zpu_buf_wr <= 1;
	end

	old_rd <= zpu_data_rd;
	if(old_rd & ~zpu_data_rd) zpu_buff_addr <= zpu_buff_addr + 1'd1;

	if(zpu_io_wr) zpu_buff_addr <= 0;

	old_blrd <= zpu_block_rd;
	if(~old_blrd & zpu_block_rd) {zpu_io_done,sd_rd[{zpu_drv_num[2], zpu_drv_num[0]}]} <= 1;

	old_blwr <= zpu_block_wr;
	if(~old_blwr & zpu_block_wr) {zpu_io_done,sd_wr[{zpu_drv_num[2], zpu_drv_num[0]}]} <= 1;

	if(sd_ack) {sd_rd, sd_wr} <= 0;

	old_ack <= sd_ack;
	if(old_ack & ~sd_ack) zpu_io_done <= 1;

	old_mounted <= |img_mounted;
	if(~old_mounted && |img_mounted) begin
		if(img_mounted[0]) zpu_fileno <= 0;
		if(img_mounted[1]) zpu_fileno <= 1;
		if(img_mounted[2]) zpu_fileno <= 4;

		zpu_filetype <= ioctl_index[7:6];
		zpu_readonly <= img_readonly | img_mounted[2];
		zpu_mounted  <= ~zpu_mounted;
		zpu_filesize <= img_size[31:0];
	end
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
