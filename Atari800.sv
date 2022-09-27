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

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

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
// XXXXXX XXXXXXXXX XXXXXXXXXXXXXX

`include "build_id.v" 
localparam CONF_STR = {
	"ATARI800;;",
	"-;",
	"S0,ATRXEXXFDATX,Mount D1;",
	"S1,ATRXEXXFDATX,Mount D2;",
	"S2,CARROMBIN,Load Cart;",
	"-;",
	"OL,Swap Joysticks,No,Yes;",
	"-;",
	"O79,CPU Speed,1x,2x,4x,8x,16x;",
	"OAC,Drive Speed,Standard,Fast-6,Fast-5,Fast-4,Fast-3,Fast-2,Fast-1,Fast-0;",
	"-;",
	"O12,BIOS,XL+Basic,XL,OS-A,OS-B;",
	"ODF,RAM,64K,128K,320K(Compy),320K(Rambo),576K(Compy),576K(Rambo),1MB,4MB;",
	"-;",
	"O5,Video mode,PAL,NTSC;",
	"OMN,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"OHJ,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"d0OO,Vertical Crop,Disabled,216p(5x);",
	"d0OPS,Crop Offset,0,2,4,8,10,12,-12,-10,-8,-6,-4,-2;",
	"OTU,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"-;",
	"OK,Dual Pokey,No,Yes;",
	"O34,Stereo mix,None,25%,50%,100%;",
	"-;",
	"R0,Reset;",
	"J,Fire 1,Fire 2,Fire 3,Paddle LT,Paddle RT,Start,Select,Option,Reset(F9),Reset(F10);",
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
	.outclk_0(clk_sys),
	.outclk_1(clk_mem),
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
wire [63:0] status;
wire [24:0] ps2_mouse;
wire [10:0] ps2_key;
wire        forced_scandoubler;
wire [21:0] gamma_bus;

reg  [31:0] sd_lba;
reg   [2:0] sd_rd;
reg   [2:0] sd_wr;
wire  [2:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire  [2:0] img_mounted;
wire        img_readonly;
wire [63:0] img_size;
wire [13:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_wr;
wire        ioctl_download;
wire  [7:0] ioctl_index;

hps_io #(.CONF_STR(CONF_STR), .VDNUM(3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.joystick_0(joy_0),
	.joystick_1(joy_1),
	.joystick_l_analog_0(joya_0),
	.joystick_l_analog_1(joya_1),

	.buttons(buttons),
	.status(status),
	.status_menumask({en216p}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),

	.sd_lba('{sd_lba,sd_lba,sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din,sd_buff_din,sd_buff_din}),
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


wire [7:0] R,G,B;
wire HBlank,VBlank;
wire VSync, HSync;
wire ce_pix;

assign CLK_VIDEO = clk_sys;

wire cpu_halt;

wire [15:0] laudio, raudio;
assign AUDIO_L = {laudio[15],laudio[15:1]};
assign AUDIO_R = status[20] ? {raudio[15],raudio[15:1]} : AUDIO_L;
assign AUDIO_S = 1;
assign AUDIO_MIX = status[4:3];

wire  [7:0]	ZPU_IN2;
wire [31:0]	ZPU_OUT2;
wire [31:0]	ZPU_IN3;
wire [31:0]	ZPU_OUT3;
wire [15:0]	ZPU_RD;
wire [15:0]	ZPU_WR;

wire areset;

assign {SDRAM_DQMH,SDRAM_DQML} = SDRAM_A[12:11];
assign SDRAM_CKE = 1;
assign SDRAM_nCS = 0;

atari800top atari800top
(
	.CLK(clk_sys),
	.CLK_SDRAM(clk_mem),
	.RESET_N(~reset),
	.ARESET(areset),

	.SDRAM_BA(SDRAM_BA),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_nWE(SDRAM_nWE),
	.SDRAM_A(SDRAM_A),
	.SDRAM_DQ(SDRAM_DQ),

	.ROM_ADDR(rom_addr),
	.ROM_DO(rom_do),

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

	.STEREO(status[20]),
	.AUDIO_L(laudio),
	.AUDIO_R(raudio),

	.ZPU_IN2(ZPU_IN2),
	.ZPU_OUT2(ZPU_OUT2),
	.ZPU_IN3(ZPU_IN3),
	.ZPU_OUT3(ZPU_OUT3),
	.ZPU_RD(ZPU_RD),
	.ZPU_WR(ZPU_WR),
	
	.CPU_HALT(cpu_halt),

	.PS2_KEY(ps2_key),

	.JOY1X(status[21] ? joya_1[7:0]  : ax),
	.JOY1Y(status[21] ? joya_1[15:8] : ay),
	.JOY2X(status[21] ? ax : joya_1[7:0] ),
	.JOY2Y(status[21] ? ay : joya_1[15:8]),

	.JOY1(status[21] ? joy_1[13:0] : j0),
	.JOY2(status[21] ? j0 : joy_1[13:0])
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

reg hsync_o, vsync_o;
always @(posedge CLK_VIDEO) begin
	if(ce_pix) begin
		hsync_o <= HSync;
		if(~hsync_o & HSync) vsync_o <= VSync;
	end
end

video_mixer #(.GAMMA(1)) video_mixer
(
	.*,
	.HSync(hsync_o),
	.VSync(vsync_o),
	.scandoubler(scale || forced_scandoubler),
	.hq2x(scale==1),
	.freeze_sync(),
	.VGA_DE(vga_de)
);

////////////////   ROM   ////////////////////

wire [14:0] rom_addr;
wire  [7:0] xl_do, bas_do, osa_do, osb_do;

dpram #(14,8, "rtl/rom/ATARIXL.mif") romxl
(
	.clock(clk_sys),

	.address_a(ioctl_addr[13:0]),
	.data_a(ioctl_dout),
	.wren_a(ioctl_wr && ioctl_index[7:6] == 0),

	.address_b(rom_addr[13:0] - osrom_off),
	.q_b(xl_do)
);

reg [13:0] osrom_off = 0;
always @(posedge clk_sys) if(ioctl_wr && ioctl_index[7:6] == 0) osrom_off <= 14'h3FFF - ioctl_addr;

dpram #(13,8, "rtl/rom/ATARIBAS.mif") basic
(
	.clock(clk_sys),

	.address_a(ioctl_addr[12:0]),
	.data_a(ioctl_dout),
	.wren_a(ioctl_wr && ioctl_index[7:6] == 1),

	.address_b(rom_addr[12:0]),
	.q_b(bas_do)
);

spram #(14,8, "rtl/rom/ATARIOSA.mif") osa
(
	.clock(clk_sys),
	.address(rom_addr[13:0]),
	.q(osa_do)
);

spram #(14,8, "rtl/rom/ATARIOSB.mif") osb
(
	.clock(clk_sys),
	.address(rom_addr[13:0]),
	.q(osb_do)
);

reg [1:0] rom_sel = 0;
always @(posedge clk_sys) if(areset) rom_sel <= status[2:1];

wire [7:0] rom_do = (!rom_addr[14:13] && !rom_sel[1:0]) ? bas_do :
                    (rom_addr[14] && !rom_sel[1]) ? ((rom_addr[13:0] >= osrom_off) ? xl_do : 8'hFF) :
                    rom_addr[14] ? (rom_sel[0] ? osb_do : osa_do) :
						  8'hFF;

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

	if(|sd_ack) {sd_rd, sd_wr} <= 0;

	old_ack <= |sd_ack;
	if(old_ack & ~|sd_ack) zpu_io_done <= 1;

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
	
	if(reset) zpu_mounted <= 0;
end


//////////////////   ANALOG AXIS   ///////////////////
reg        emu = 0;
wire  [7:0] ax = emu ? mx[7:0] : joya_0[7:0];
wire  [7:0] ay = emu ? my[7:0] : joya_0[15:8];
wire [13:0] j0 = {joy_0[13:9], emu ? ps2_mouse[1:0] : joy_0[8:7], joy_0[6:0]};

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
