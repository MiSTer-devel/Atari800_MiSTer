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
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z; 

assign LED_USER  = drive_led | ioctl_download;
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
// XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX XXXXXXXXXXXXXXXXXXXX

`include "build_id.v" 
localparam CONF_STR = {
	"ATARI800;;",
	"-;",
	"S6,ATRXEXXDFATX,Boot D1;",
	"-;",
	"S0,ATRXEXXFDATX,Mount D1;",
	"S1,ATRXEXXFDATX,Mount D2;",
	"S2,ATRXEXXFDIMG,Mount D3;",
	"S3,ATRXEXXFDIMG,Mount D4;",
	"-;",
	"S5,XEXCOMEXE,Load XEX;",
	"-;",
	"S4,CARROMBIN,Load Cart;",
	"S7,CARROMBIN,Stack Cart;",
	"-;",
	"P1,Drives & Loader;",
	"P1-;",
	"P1OG,SIO Connected to,Emu,USER I/O;",
	"P1-;",
	"d2P1oCD,D1 mode,OS/Stock,PBI,HSIO;",
	"d2P1oEF,D2 mode,OS/Stock,PBI,HSIO;",
	"d2P1oGH,D3 mode,OS/Stock,PBI,HSIO;",
	"d2P1oIJ,D4 mode,OS/Stock,PBI,HSIO;",
	"P1-;",
	"P1OAC,SIO drive speed,Standard,Fast-6,Fast-5,Fast-4,Fast-3,Fast-2,Fast-1,Fast-0;",
	"P1o6,ATX drive timing,1050,810;",
	"P1-;",
	"P1o0,XEX loader,Standard,Stack;",
	"P2,Hardware & OS;",
	"P2-;",
	"P2O79,CPU speed,1x,2x,4x,8x,16x;",
	"P2-;",
	"P2O12,Machine/BIOS,XL+Basic,XL,800/OS-A,800/OS-B;",
	"H1P2ODF,RAM XL,64K,128K,320K(Compy),320K(Rambo),576K(Compy),576K(Rambo),1MB,4MB(Axlon);",
	"h1P2o35,RAM 800,8K,16K,32K,48K,52K,4MB(Axlon);",
	"D1P2oA,PBI BIOS,Disabled,Enabled;",
	"d2P2oB,PBI splash,Disabled,Enabled;",
	"d2P2oKM,PBI boot drive,Default,APT,D1:,D2:,D3:,D4:,D5:,D6:;",
	"P2-;",
	"P2o9,Use bootX.rom,Enabled,Disabled;",
	"P2-;",
	"P2FC4,ROMBIN,Set XL OS;",
	"P2FC5,ROMBIN,Set Basic;",
	"P2FC6,ROMBIN,Set OS-A;",
	"P2FC7,ROMBIN,Set OS-B;",
	"P3,Video;",
	"P3-;",
	"P3O5,Video mode,PAL,NTSC;",
	"P3o1,Hi-Res ANTIC,Disabled,Enabled;",
	"P3-;",
	"P3OMN,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P3OHJ,Scandoubler FX,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P3OV,NTSC/PAL artifacting,No,Yes;",
	"P3o2,Clip sides,Disabled,Enabled;",
	"P3OTU,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"d0P3OO,Vertical Crop,Disabled,216p(5x);",
	"d0P3OPS,Crop Offset,0,2,4,8,10,12,-12,-10,-8,-6,-4,-2;",
	"P4,Audio;",
	"P4-;",
	"P4OK,Dual Pokey,Disabled,Enabled;",
	"P4O34,Stereo mix,None,25%,50%,100%;",
	"P5,Input;",
	"P5-;",
	"P5OL,Swap Joysticks 1&2,No,Yes;",
	"P5O6,Mouse Y,Normal,Inverted;",
	"-;",
	"r7,Warm Reset (F9);",
	"r8,Cold Reset (F10);",
	"R0,Core Reset;",
	"J,Fire 1,Fire 2,Fire 3,Paddle LT,Paddle RT,Start,Select,Option,Reset(F9),Reset(F10);",
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

wire reset = RESET | status[0] | ~initReset_n | buttons[1];

reg initReset_n = 0;
always @(posedge clk_sys) begin
	integer timeout = 0;
	
	if(timeout < 2500000) timeout <= timeout + 1;
	else initReset_n <= 1;
end

//////////////////   HPS I/O   ///////////////////
wire [15:0] joy_0;
wire [15:0] joy_1;
wire [15:0] joy_2;
wire [15:0] joy_3;
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

reg  [31:0] sd_lba;
reg   [7:0] sd_rd;
reg   [7:0] sd_wr;
wire  [7:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire  [7:0] img_mounted;
wire        img_readonly;
wire [63:0] img_size;
wire [13:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_wr;
wire        ioctl_download;
wire  [7:0] ioctl_index;

wire [64:0] rtc;

hps_io #(.CONF_STR(CONF_STR), .VDNUM(8)) hps_io
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
	.status_menumask({~status[2] & status[42], status[2],en216p}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),

	.sd_lba('{sd_lba,sd_lba,sd_lba,sd_lba,sd_lba,sd_lba,sd_lba,sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din,sd_buff_din,sd_buff_din,sd_buff_din,sd_buff_din,sd_buff_din,sd_buff_din,sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.ioctl_download(ioctl_download),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_index(ioctl_index),

	.RTC(rtc)
);


wire [7:0] R,G,B, Ro,Go,Bo;
wire HBlank,VBlank,HBlank_o,VBlank_o;
wire VSync, HSync, VSync_o, HSync_o;
wire ce_pix;
wire ce_pix_raw;

assign CLK_VIDEO = clk_vdo;

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

wire SIO_MODE = status[16];
wire SIO_IN,SIO_OUT, SIO_CLKOUT, SIO_CLKIN, SIO_CMD, SIO_PROC, SIO_MOTOR, SIO_IRQ;

wire drive_led;

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
	.EXT_ANTIC(status[33]),
	.CLIP_SIDES(status[34]),
	.VGA_VS(VSync_o),
	.VGA_HS(HSync_o),
	.VGA_B(Bo),
	.VGA_G(Go),
	.VGA_R(Ro),
	.VGA_PIXCE(ce_pix_raw),
	.HBLANK(HBlank_o),
	.VBLANK(VBlank_o),

	.CPU_SPEED(CPU_SPEEDS[status[9:7]]),
	.RAM_SIZE(ram_config), 
	.DRV_SPEED(status[12:10]),
	.XEX_LOC(status[32]),
	.OS_MODE_800(mode800),
	.PBI_MODE(modepbi),
	.PBI_SPLASH(splashpbi),
	.PBI_DRIVES_MODE(drivesmodepbi),
	.PBI_BOOT(bootpbi),
	.ATX_MODE(~status[38]),
	.DRIVE_LED(drive_led),
	.WARM_RESET_MENU(status[39]),
	.COLD_RESET_MENU(status[40] | load_reset),
	.RTC(rtc),

	.STEREO(status[20]),
	.AUDIO_L(laudio),
	.AUDIO_R(raudio),

	.ZPU_IN2(ZPU_IN2),
	.ZPU_OUT2(ZPU_OUT2),
	.ZPU_IN3(ZPU_IN3),
	.ZPU_OUT3(ZPU_OUT3),
	.ZPU_RD(ZPU_RD),
	.ZPU_WR(ZPU_WR),

	.SIO_MODE(SIO_MODE),
	.SIO_IN(SIO_IN),
	.SIO_OUT(SIO_OUT),
	//.SIO_CLKOUT(SIO_CLKOUT),
	.SIO_CLKIN(SIO_CLKIN),
	.SIO_CMD(SIO_CMD),
	.SIO_PROC(SIO_PROC),
	.SIO_MOTOR(SIO_MOTOR),
	.SIO_IRQ(SIO_IRQ),
	
	.CPU_HALT(cpu_halt),

	.PS2_KEY(ps2_key),

	.JOY1X(status[21] ? joya_1[7:0]  : ax),
	.JOY1Y(status[21] ? joya_1[15:8] : ay),
	.JOY2X(status[21] ? ax : joya_1[7:0] ),
	.JOY2Y(status[21] ? ay : joya_1[15:8]),
	.JOY3X(joya_2[7:0]),
	.JOY3Y(joya_2[15:8]),
	.JOY4X(joya_3[7:0]),
	.JOY4Y(joya_3[15:8]),

	.JOY1(status[21] ? joy_1[13:0] : j0),
	.JOY2(status[21] ? j0 : joy_1[13:0]),
	.JOY3(joy_2[13:0]),
	.JOY4(joy_3[13:0])
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

reg hsync_o, vsync_o;
always @(posedge CLK_VIDEO) begin
	if(ce_pix) begin
		hsync_o <= HSync_o;
		if(~hsync_o & HSync_o) vsync_o <= VSync_o;
	end
end

articolor articolor
(
	.clk(CLK_VIDEO),
	.ce_pix(ce_pix),
	
	.enable(status[31]),
	.pal(~status[5]),

	.r_in(Ro),
	.g_in(Go),
	.b_in(Bo),
	.hbl_in(HBlank_o),
	.vbl_in(VBlank_o),
	.hs_in(hsync_o),
	.vs_in(vsync_o),

	.r_out(R),
	.g_out(G),
	.b_out(B),
	.hbl_out(HBlank),
	.vbl_out(VBlank),
	.hs_out(HSync),
	.vs_out(VSync)
);

video_mixer #(.GAMMA(1)) video_mixer
(
	.*,
	.scandoubler(scale || forced_scandoubler),
	.hq2x(scale==1),
	.freeze_sync(),
	.VGA_DE(vga_de)
);

////////////////   ROM   ////////////////////

wire [14:0] rom_addr;
wire  [7:0] xl_do, bas_do, osa_do, osb_do, pbirom_do;

reg [13:0] osrom_off = 0;
reg [13:0] osrom2_off = 0;
reg [13:0] osrom3_off = 0;
wire xl_rom_index = (~status[41] && ioctl_index[7:0] == 0) || ioctl_index[5:0] == 4;
wire basic_rom_index = (~status[41] && ioctl_index[7:0] == 8'b01000000) || ioctl_index[5:0] == 5;
wire osa_rom_index = (~status[41] && ioctl_index[7:0] == 8'b10000000) || ioctl_index[5:0] == 6;
wire osb_rom_index = (~status[41] && ioctl_index[7:0] == 8'b11000000) || ioctl_index[5:0] == 7;
wire load_sys_rom = ioctl_index[5:2] == 4'b0001;
always @(posedge clk_sys) if(ioctl_wr && xl_rom_index) osrom_off <= 14'h3FFF - ioctl_addr;
always @(posedge clk_sys) if(ioctl_wr && osa_rom_index) osrom2_off <= 14'h3FFF - ioctl_addr;
always @(posedge clk_sys) if(ioctl_wr && osb_rom_index) osrom3_off <= 14'h3FFF - ioctl_addr;

dpram #(14,8, "rtl/rom/ATARIXL.mif") romxl
(
	.clock(clk_sys),

	.address_a(ioctl_addr[13:0]),
	.data_a(ioctl_dout),
	.wren_a(ioctl_wr && xl_rom_index),

	.address_b(rom_addr[13:0] - osrom_off),
	.q_b(xl_do)
);

dpram #(13,8, "rtl/rom/ATARIBAS.mif") basic
(
	.clock(clk_sys),

	.address_a(ioctl_addr[12:0]),
	.data_a(ioctl_dout),
	.wren_a(ioctl_wr && basic_rom_index),

	.address_b(rom_addr[12:0]),
	.q_b(bas_do)
);

dpram #(14,8, "rtl/rom/ATARIOSA.mif") osa
(
	.clock(clk_sys),

	.address_a(ioctl_addr[13:0]),
	.data_a(ioctl_dout),
	.wren_a(ioctl_wr && osa_rom_index),

	.address_b(rom_addr[13:0] - osrom2_off),
	.q_b(osa_do)
);

dpram #(14,8, "rtl/rom/ATARIOSB.mif") osb
(
	.clock(clk_sys),

	.address_a(ioctl_addr[13:0]),
	.data_a(ioctl_dout),
	.wren_a(ioctl_wr && osb_rom_index),

	.address_b(rom_addr[13:0] - osrom3_off),
	.q_b(osb_do)
);

spram #(13,8, "firmware/PBIBIOS.mif") pbirom
(
	.clock(clk_sys),
	.address(rom_addr[12:0]),
	.q(pbirom_do)
);

reg [1:0] rom_sel = 0;
reg mode800 = 0;
reg modepbi = 0;
reg splashpbi = 0;
reg [7:0] drivesmodepbi = 0;
reg [2:0] bootpbi = 0;
reg [2:0] ram_config = 0;

always @(posedge clk_sys) if(areset) begin
	rom_sel <= status[2:1];
	mode800 <= status[2];
	modepbi <= ~status[2] & status[42];
	splashpbi <= status[43];
	bootpbi <= status[54:52];
	drivesmodepbi <= status[51:44];
	ram_config <= (status[2] ? status[37:35] : status[15:13]);
end

wire [7:0] xl_pad_do = (rom_addr[13:0] >= osrom_off) ? xl_do : 8'hFF;
wire [7:0] osa_pad_do = (rom_addr[13:0] >= osrom2_off) ? osa_do : 8'hFF;
wire [7:0] osb_pad_do = (rom_addr[13:0] >= osrom3_off) ? osb_do : 8'hFF;

wire [7:0] rom_do = (!rom_addr[14:13] && !rom_sel[1:0]) ? bas_do :
                    (rom_addr[14] && !rom_sel[1]) ? xl_pad_do :
                     rom_addr[14] ? (rom_sel[0] ? osb_pad_do : osa_pad_do) : 
                     ((!rom_addr[14] && rom_addr[13]) ? pbirom_do : 8'hFF);

reg load_reset = 0;
always @(posedge clk_sys) begin
	integer load_reset_timeout = 0;
	reg old_download = 0;
	reg load_reset_required = 0;

	if (old_download && !ioctl_download)
	begin
		load_reset <= load_reset_required;
		load_reset_required <= 0;
		load_reset_timeout <= 0;
	end
	else if(load_reset_timeout < 1000)
		load_reset_timeout <= load_reset_timeout + 1;
	else
		load_reset <= 0;

	if (ioctl_download)
		load_reset_required <= (ioctl_index[5:0] == 4 && (!status[2] || !rom_sel[1])) || (ioctl_index[5:0] == 5 && (!status[2:1] || !rom_sel[1:0])) || ((status[2] || rom_sel[1]) && ((ioctl_index[5:0] == 6 && (!status[1] || !rom_sel[0])) || (ioctl_index[5:0] == 7 && (status[1] || rom_sel[0]))));

	old_download <= ioctl_download & load_sys_rom;
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
	if(~old_blrd & zpu_block_rd) {zpu_io_done,sd_rd[zpu_drv_num[2:0]]} <= 1;

	old_blwr <= zpu_block_wr;
	if(~old_blwr & zpu_block_wr) {zpu_io_done,sd_wr[zpu_drv_num[2:0]]} <= 1;

	if(|sd_ack) {sd_rd, sd_wr} <= 0;

	old_ack <= |sd_ack;
	if(old_ack & ~|sd_ack) zpu_io_done <= 1;

	old_mounted <= |img_mounted;
	if(~old_mounted && |img_mounted) begin
		if(img_mounted[0]) zpu_fileno <= 0;
		if(img_mounted[1]) zpu_fileno <= 1;
		if(img_mounted[2]) zpu_fileno <= 2;
		if(img_mounted[3]) zpu_fileno <= 3;
		if(img_mounted[4]) zpu_fileno <= 4;
		if(img_mounted[5]) zpu_fileno <= 5;
		if(img_mounted[6]) zpu_fileno <= 6;
		if(img_mounted == 128) zpu_fileno <= 7;

		zpu_filetype <= ioctl_index[7:6];
		zpu_readonly <= img_readonly | img_mounted[4] | img_mounted[5];
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

//////////////////   USER I/O   ///////////////////

//
// Pin | USB Name |   |Signal
// ----+----------+---+-------------
// 0   | D+       | I |SIO_IN
// 1   | D-       | O |SIO_OUT
// 2   | TX-      | O |SIO_CMD
// 3   | GND_d    | I |SIO_CLKIN
// 4   | RX+      | I |SIO_PROC
// 5   | RX-      | I |SIO_IRQ
// 6   | TX+      | O |SIO_MOTOR
//

assign USER_OUT  = SIO_MODE ? {SIO_MOTOR, 1'b1, 1'b1, 1'b1, SIO_CMD, SIO_OUT, 1'b1} : 7'b1111111;

assign SIO_IN    = ~SIO_MODE | USER_IN[0];
assign SIO_CLKIN = ~SIO_MODE | USER_IN[3];
assign SIO_PROC  = ~SIO_MODE | USER_IN[4];
assign SIO_IRQ   = ~SIO_MODE | USER_IN[5];


endmodule
