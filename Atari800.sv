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

assign LED_USER  = file_download | drive_led;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = status[62] & interlace;

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
// X XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX   XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

//                                      1         1         1
// 6     7         8         9          0         1         2
// 45678901234567890123456789012345 67890123456789012345678901234567
//                                                                  


`include "build_id.v" 
localparam CONF_STR = {
	"ATARI800;;",
	"-;",
	"S6,ATRXEXXDFATX,Boot D1;",
	"S5,XEXCOMEXE,Load XEX;",
	"F8,CARROMBIN,Load Cart;",
	"-;",
	"S0,ATRXEXXFDATX,Mount D1;",
	"S1,ATRXEXXFDATX,Mount D2;",
	"S2,ATRXEXXFDATX,Mount D3;",
	"S3,ATRXEXXFDATX,Mount D4;",
	"S4,IMG,Mount HDD;",
	"-;",
	"F9,CARROMBIN,Second Cart;",
	"-;",
	"P1,Drives & Loader;",
	"P1-;",
	"P1O[16],SIO Connected to,Emu,USER I/O;",
	"P1-;",
	"d2P1O[45:44],D1 mode,OS/Stock,PBI,HSIO;",
	"d2P1O[47:46],D2 mode,OS/Stock,PBI,HSIO;",
	"d2P1O[49:48],D3 mode,OS/Stock,PBI,HSIO;",
	"d2P1O[51:50],D4 mode,OS/Stock,PBI,HSIO;",
	"P1-;",
	"P1O[12:10],SIO drive speed,Standard,Fast-6,Fast-5,Fast-4,Fast-3,Fast-2,Fast-1,Fast-0;",
	"P1O[38],ATX drive timing,1050,810;",
	"P1-;",
	"P1O[57],Mount read-only,Disabled,Enabled;",
	"P2,Hardware & OS;",
	"P2-;",
	"P2O[9:7],CPU speed,1x,2x,4x,8x,16x;",
	"P2-;",
	"P2O[2],Machine,XL/XE,400/800;",
	"H1P2O[15:13],RAM XL,64K,128K,320K(Compy),320K(Rambo),576K(Compy),576K(Rambo),1MB,4MB(Axlon);",
	"h1P2O[37:35],RAM 800,8K,16K,32K,48K,52K,4MB(Axlon);",
	"d5P2O[42],PBI BIOS,Disabled,Enabled;",
	"d2P2O[43],PBI splash,Disabled,Enabled;",
	"d2P2O[54:52],PBI boot drive,Default,APT,D1:,D2:,D3:,D4:,D5:,D6:;",
	"P2-;",
	"P2O[41],Use bootX.rom,Enabled,Disabled;",
	"P2-;",
	"P2FC4,ROMBIN,XL/XE OS;",
	"P2FC5,ROMBIN,Basic;",
	"P2FC6,ROMBIN,OS-A/B;",
	"P2FC3,ROMBIN,TurboFreezer;",
	"P3,Video;",
	"P3-;",
	"P3O[5],Video mode,PAL,NTSC;",
	"P3O[62:61],Interlace hack,Disabled,Weave,Bob;",
	"P3-;",
	"P3O[60:59],VBXE,Disabled,$D640,$D740;",
	"P3O[63],Fix VBXE NTSC bug,Disabled,Enabled;",
	"P3FC2,ACT,VBXE Palette;",
	"P3-;",
	"P3O[23:22],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P3O[19:17],Scandoubler FX,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"d3P3O[31],NTSC artifacting,No,Yes;",
	"d4P3O[55],Artifacting colors,Set 1,Set 2;",
	"d4P3O[58],Swap artif. colors,No,Yes;",
	"P3O[34],Clip sides,Disabled,Enabled;",
	"P3O[30:29],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"d0P3O[24],Vertical Crop,Disabled,216p(5x);",
	"d0P3O[28:25],Crop Offset,0,2,4,8,10,12,-12,-10,-8,-6,-4,-2;",
	"P4,Audio;",
	"P4-;",
	"P4O[20],Dual Pokey,Disabled,Enabled;",
	"P4O[4:3],Stereo mix,None,25%,50%,100%;",
	"P5,Input;",
	"P5-;",
	"P5O[21],Swap Joysticks 1&2,No,Yes;",
	"P5-;",
	"P5O[56],Mouse X,Normal,Inverted;",
	"P5O[6],Mouse Y,Normal,Inverted;",
	"-;",
	"R[39],Warm Reset (F9);",
	"R[40],Cold Reset (F10);",
	"R[0],Reset (Detach All);",
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

wire reset = RESET;

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
wire [127:0] status;
wire [24:0] ps2_mouse;
wire [10:0] ps2_key;
wire        forced_scandoubler;
wire [21:0] gamma_bus;

wire [26:0] ioctl_addr;
wire  [7:0] ioctl_dout;
reg   [7:0] ioctl_din;
wire        ioctl_wr;
wire        ioctl_rd;
wire        ioctl_download;
wire        ioctl_upload;
wire  [7:0] ioctl_index;
reg         ioctl_wait = 1;

wire [35:0] EXT_BUS;
wire  [7:0] cart1_select;
wire  [7:0] cart2_select;
wire        set_reset;
wire        set_pause;
wire        set_freezer;
wire        set_reset_rnmi;
wire        set_option_force;

wire  [7:0] hps_dma_data_in;
wire        sdram_ready;
wire        dma_ready;
reg         dma_req = 0;

wire  [4:0] uart_addr;
wire        uart_enable;
wire        uart_wr;
wire  [7:0] uart_data_write;
wire [15:0] uart_data_read;

wire [64:0] rtc;

wire file_download = ioctl_download && (ioctl_index != 99);

always @(posedge clk_sys) begin
	reg started = 0;
	if(sdram_ready && sdram_erased) begin
		if(!started) begin
			started <= 1;
			ioctl_wait <= 0;
		end
		if(ioctl_index[5:0] != 2 && (ioctl_download | ioctl_upload)) begin
			if(dma_ready) begin
				if(ioctl_upload)
					ioctl_din <= hps_dma_data_in;
				ioctl_wait <= 0;
				dma_req <= 0;
			end
			if((ioctl_wr & ioctl_download) | (ioctl_rd & ioctl_upload)) begin
				ioctl_wait <= 1;
				dma_req <= 1;
			end
		end
		else
			ioctl_wait <= 0;
	end
end

reg [16:0] sdram_erase_addr = 0;
wire sdram_erased = sdram_erase_addr[16];
reg sdram_erase_req = 0;

always @(posedge clk_sys) if(!sdram_erased && sdram_ready) begin
	if(dma_ready) begin
		sdram_erase_addr <= sdram_erase_addr + 1'd1;
		sdram_erase_req <= 0;
	end
	if(!sdram_erase_req)
		sdram_erase_req <= 1;
end

reg[2:0] vbxe_palette_rgb = 3'b001;
reg[7:0] vbxe_palette_index = 0;
wire[2:0] vbxe_palette_rgb_out;
assign vbxe_palette_rgb_out = vbxe_palette_rgb & 
	{ ioctl_wr & (ioctl_index[5:0] == 2), ioctl_wr & (ioctl_index[5:0] == 2), ioctl_wr & (ioctl_index[5:0] == 2)}; 
wire[6:0] vbxe_palette_color;
assign vbxe_palette_color = ioctl_dout[7:1];

// Translate the ACT RGB order into what we need
always @(posedge clk_sys) if(ioctl_wr & (ioctl_index[5:0] == 2)) begin
	if(vbxe_palette_rgb[2])
		vbxe_palette_index <= vbxe_palette_index + 1'd1;
	vbxe_palette_rgb <= {vbxe_palette_rgb[1:0], vbxe_palette_rgb[2]}; 
end

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
	.status_menumask({~status[2] & pbi_rom_loaded, status[31] & status[5], status[5] & ~status[59] & ~status[60], ~status[2] & status[42] & pbi_rom_loaded, status[2], en216p}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_wr(ioctl_wr),
	.ioctl_rd(ioctl_rd),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.RTC(rtc),
	.EXT_BUS(EXT_BUS)
);

hps_ext hps_ext
(
	.clk_sys(clk_sys),
	.EXT_BUS(EXT_BUS),

	.set_reset(set_reset),
	.set_pause(set_pause),
	.set_freezer(set_freezer),
	.set_reset_rnmi(set_reset_rnmi),
	.set_option_force(set_option_force),
	.set_drive_led(drive_led),
	.set_xex_loader_mode(xex_loader_mode),
	.cart1_select(cart1_select),
	.cart2_select(cart2_select),
	.atari_status1(atari_status1),
	.atari_status2(atari_status2),
	
	.uart_addr(uart_addr),
	.uart_enable(uart_enable),
	.uart_wr(uart_wr),
	.uart_data_write(uart_data_write),
	.uart_data_read(uart_data_read)
);

wire [7:0] R,G,B, Ro,Go,Bo;
wire HBlank,VBlank,HBlank_o,VBlank_o;
wire VSync, HSync, VSync_o, HSync_o;
wire ce_pix;
wire ce_pix_raw;

assign CLK_VIDEO = clk_vdo;

wire cpu_halt;

wire [15:0] laudio, raudio;
assign AUDIO_L = (cpu_halt | areset | reset) ? 16'b0000000000000000 : {laudio[15],laudio[15:1]};
assign AUDIO_R = (cpu_halt | areset | reset) ? 16'b0000000000000000 : (status[20] ? {raudio[15],raudio[15:1]} : AUDIO_L);
assign AUDIO_S = 1;
assign AUDIO_MIX = status[4:3];

wire areset;

assign SDRAM_CKE = 1;

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
	.SDRAM_nCS(SDRAM_nCS),
	.SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_DQML(SDRAM_DQML),

	.TURBOFREEZER_ROM_LOADED(turbofreezer_rom_loaded),
	.SDRAM_READY(sdram_ready),
	.OSD_PAUSE(file_download),
	.SET_RESET_IN(set_reset),
	.SET_PAUSE_IN(set_pause),
	.SET_FREEZER_IN(set_freezer),
	.SET_RESET_RNMI_IN(set_reset_rnmi),
	.SET_OPTION_FORCE_IN(set_option_force),
	.CART1_SELECT_IN(cart1_select),
	.CART2_SELECT_IN(cart2_select),
	.HOT_KEYS(atari_hotkeys),

	.UART_ADDR(uart_addr),
	.UART_ENABLE(uart_enable),
	.UART_WR(uart_wr),
	.UART_DATA_WRITE(uart_data_write),
	.UART_DATA_READ(uart_data_read),

	// TODO make a nice wire for this contraption?
	.HPS_DMA_ADDR(sdram_erased ? (ioctl_index == 99 ? ioctl_addr[25:0] : (cart_rom_index ? cart_upload_addr : rom_upload_addr)) : {10'h270, sdram_erase_addr[15:0]}),
	.HPS_DMA_REQ(sdram_erased ? dma_req : sdram_erase_req),
	.HPS_DMA_READ_ENABLE(ioctl_upload),
	.HPS_DMA_DATA_OUT(sdram_erased ? ioctl_dout : 8'hff),
	.HPS_DMA_DATA_IN(hps_dma_data_in),
	.HPS_DMA_READY(dma_ready),

	.PAL(pal_video),
	.CLIP_SIDES(status[34]),
	.VGA_VS(VSync_o),
	.VGA_HS(HSync_o),
	.VGA_B(Bo),
	.VGA_G(Go),
	.VGA_R(Ro),
	.VGA_PIXCE(ce_pix_raw),
	.interlace_enable(status[62] | status[61]),
	.interlace(interlace),
	.interlace_field(interlace_field),
	.HBLANK(HBlank_o),
	.VBLANK(VBlank_o),

	.CPU_SPEED(CPU_SPEEDS[status[9:7]]),
	.RAM_SIZE(ram_config),
	.OS_MODE_800(mode800),
	.PBI_MODE(modepbi),
	.XEX_LOADER_MODE(xex_loader_mode),
	.WARM_RESET_MENU(status[39]),
	.COLD_RESET_MENU(status[40] | buttons[1]),
	.RTC(rtc),
	.VBXE_MODE({status[63],status[60],status[59]}),
	.VBXE_PALETTE_RGB(vbxe_palette_rgb_out),
	.VBXE_PALETTE_INDEX(vbxe_palette_index),
	.VBXE_PALETTE_COLOR(vbxe_palette_color),

	.STEREO(status[20]),
	.AUDIO_L(laudio),
	.AUDIO_R(raudio),

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

wire interlace;
wire interlace_field;

assign VGA_F1 = interlace & interlace_field;
assign VGA_SL = (scale ? scale[1:0] - 1'd1 : 2'd0)&{~interlace,~interlace};

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
	
	.enable(status[5] & status[31] & ~status[59] & ~status[60]),
	.colorset(~status[55]),
	.colorswap(status[58]),

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
	.scandoubler(~interlace && (scale || forced_scandoubler)),
	.hq2x(scale==1),
	.freeze_sync(),
	.VGA_DE(vga_de)
);

////////////////   ROM   ////////////////////

// boot.rom or menu index 4 file
wire xl_rom_index = ioctl_index[7:0] == 0 || ioctl_index[5:0] == 4;
// boot1.rom or menu index 5 file
wire basic_rom_index = ioctl_index[7:0] == 8'b01000000 || ioctl_index[5:0] == 5;
// boot2.rom or menu index 6 file
wire osab_rom_index = ioctl_index[7:0] == 8'b10000000 || ioctl_index[5:0] == 6;
// boot3.rom (no menu index for this!)
wire pbi_rom_index = ioctl_index[7:0] == 8'b11000000;
wire turbofreezer_rom_index = ioctl_index[5:0] == 3;

wire[25:0] rom_upload_addr;
assign rom_upload_addr =
	xl_rom_index ? {10'h270, 2'b01, ioctl_addr[13:0]} :
	(osab_rom_index ? {10'h270, 2'b10, ioctl_addr[13:0]} + 14'h1800 :
	(basic_rom_index ? {10'h270, 3'b000, ioctl_addr[12:0]} :
	(pbi_rom_index ? {10'h270, 3'b001, ioctl_addr[12:0]} : 
	{10'h24A, ioctl_addr[15:0]}))); // Turbo Freezer

wire cart1_rom_index = ioctl_index[5:0] == 8;
wire cart2_rom_index = ioctl_index[5:0] == 9;
wire cart_rom_index = cart1_rom_index | cart2_rom_index;

wire[25:0] cart_upload_addr;
wire[25:0] cart1_upload_addr;
wire[25:0] cart2_upload_addr;

assign cart1_upload_addr = {3'b101, ioctl_addr[22:0]};
assign cart2_upload_addr = {6'b101001, ioctl_addr[19:0]};

assign cart_upload_addr = cart1_rom_index ? cart1_upload_addr : cart2_upload_addr;

reg mode800 = 0;
reg modepbi = 0;
wire xex_loader_mode;
reg splashpbi = 0;
reg [7:0] drivesmodepbi = 0;
reg [2:0] bootpbi = 0;
reg [2:0] ram_config = 0;
reg pal_video = 0;

wire [15:0] atari_status1;
wire [15:0] atari_status2;
wire [2:0] atari_hotkeys;
assign atari_status1 = {~status[38], 4'b0000, status[12:10], modepbi & ~xex_loader_mode, status[57], 1'b0, ~status[41], mode800, atari_hotkeys};
assign atari_status2 = {4'b0000, splashpbi, bootpbi, drivesmodepbi};

always @(posedge clk_sys) if(areset) begin
	mode800 <= status[2];
	modepbi <= ~status[2] & status[42] & pbi_rom_loaded;
	splashpbi <= status[43];
	bootpbi <= status[54:52];
	drivesmodepbi <= status[51:44];
	ram_config <= (status[2] ? status[37:35] : status[15:13]);
	pal_video <= ~status[5];
end

reg pbi_rom_loaded = 0;
reg turbofreezer_rom_loaded = 0;

always @(posedge clk_sys) if (ioctl_download) begin
	if(pbi_rom_index) pbi_rom_loaded <= 1;
	if(turbofreezer_rom_index) turbofreezer_rom_loaded <= 1;
end

//////////////////   ANALOG AXIS   ///////////////////
reg        emu = 0;
wire  [7:0] ax = emu ? mx[7:0] : joya_0[7:0];
wire  [7:0] ay = emu ? my[7:0] : joya_0[15:8];
wire [13:0] j0 = {joy_0[13:9], emu ? ps2_mouse[1:0] : joy_0[8:7], joy_0[6:0]};

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
