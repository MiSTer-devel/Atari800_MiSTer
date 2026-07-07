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
	`include "sys/emu_ports.vh"
);

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z; 

assign LED_USER  = file_download | tape_active | drive_led;
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
// X XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

//                                      1         1         1
// 6     7         8         9          0         1         2
// 45678901234567890123456789012345 67890123456789012345678901234567
// XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX                     


`include "build_id.v" 
localparam CONF_STR = {
	"ATARI800;;",
	"-;",
	"S6,ATRXEXXDFATX,Boot D1;",
	"S5,XEXCOMEXE,Load XEX;",
	"F8,CARROMBIN,Load Cart;",
	"S8,CAS,Boot Tape;",
	"-;",
	"S0,ATRXEXXFDATX,Mount D1;",
	"S1,ATRXEXXFDATX,Mount D2;",
	"S2,ATRXEXXFDATX,Mount D3;",
	"S3,ATRXEXXFDATX,Mount D4;",
	"S4,IMG,Mount HDD;",
	"-;",
	"S7,CAS,Load Tape;",
	"F9,CARROMBIN,Second Cart;",
	"-;",
	"P1,Drives Carts & Tape;",
	"P1-;",
	"P1O[16],SIO Connected to,Emu,User I/O;",
	"P1O[57],Mount images R/O,Disabled,Enabled;",
	"P1-;",
	"d2P1O[45:44],D1 mode,OS/Stock,PBI,HSIO;",
	"d2P1O[47:46],D2 mode,OS/Stock,PBI,HSIO;",
	"d2P1O[49:48],D3 mode,OS/Stock,PBI,HSIO;",
	"d2P1O[51:50],D4 mode,OS/Stock,PBI,HSIO;",
	"P1-;",
	"P1O[12:10],SIO drive speed,Standard,Fast-6,Fast-5,Fast-4,Fast-3,Fast-2,Fast-1,Fast-0;",
	"P1O[38],ATX drive timing,1050,810;",
	"P1-;",
	"P1O[68],On cart (u)mount,PwrReset,Nothing;",
	"P1O[69],Cart auto-save,Disabled,Enabled;",
	"P1R[70],Save cart(s);",
	"P1-;",
	"P1O[66:64],Tape turbo system,Standard,SIO/Cmd,Turbo-D,K.S.O.,K.S.O. 2,Blizzard,Rambit,T6000;",
	"P1O[67],Invert turbo PWM,Disabled,Enabled;",
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
	"P4O[4:3],Stereo mix (sys),None,25%,50%,100%;",
	"P4O[20],PokeyMax,Off/Mono,Enabled;",
	// Since there is no alternative for this really, Main loads this automatically
	// from a name fixed file
	//"P4FC7,ROMBIN,SID wave data;",
	"P4-;",
	"d6P4O[71],Mono detect,On,Off;",
	"P4O[32],Output Left Channel,On,Off;",
	"P4O[33],Output Right Channel,On,Off;",
	"P4O[73:72],Post-divide Left,4,8,1,2;",
	"P4O[75:74],Post-divide Right,4,8,1,2;",
	"P4O[77:76],GTIA mix-in,Left+Right,None,Left,Right;",
	"P4O[79:78],Tape volume,2x,4x,0x,1x;",
	"P4-;",
	"d6P4O[81:80],Number of Pokeys,4,1,2;",
	"P4O[82],Pokey volume,Saturated,Linear;",
	"P4O[83],Channel mode,Normal,Split;",
	"d6P4O[84],Multi IRQs,Off,On;",
	"P4-;",
	"d6P4O[85],SIDs,Enabled,Disabled;",
	"d7P4O[86],SID1 filter,8580,6581;",
	"d7P4O[87],SID2 filter,8580,6581;",
	"d7P4O[89:88],SID1 DFix/audio-in,DigiFix,None,Mixer LB;",
	"d7P4O[91:90],SID2 DFix/audio-in,DigiFix,None,Mixer LB;",
	"P4-;",
	"d6P4O[95],Covox/Sample,Enabled,Disabled;",
	"P4-;",
	"dAP4O[94:92],SID/CVX1+2 LB src,Pokey1+2,Pokey3+4,Covox,SID,PSG,GTIA,Tape;",
	"d8P4O[98:96],Covox3+4 LB src,Pokey3+4,Covox,SID,PSG,GTIA,Tape,Pokey1+2;",
	"P4-;",
	"d6P4O[99],PSGs,Enabled,Disabled;",
	"d9P4O[101:100],PSG clock,2MHz,1MHz,1.79MHz;",
	"d9P4O[103:102],PSG stereo,Polish,Czech,By chip,Mono;",
	"d9P4O[104],PSG envelope,32 steps,16 steps;",
	"d9P4O[106:105],PSG volume,YM,AY3,Log,Linear;",
	"P4-;",
	"P4-,      (Reset to apply);",
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
wire        set_start_force;
wire        set_space_force;

wire  [7:0] hps_dma_data_in;
wire        sdram_ready;
wire        dma_ready;
reg         dma_req = 0;

wire  [4:0] uart_addr;
wire        uart_enable;
wire        uart_wr;
wire  [7:0] uart_data_write;
wire [15:0] uart_data_read;

wire [31:0] tape_data;
wire        tape_data_wr;
wire        tape_reset;
wire        tape_active;
wire        tape_fifo_full;
wire        tape_fifo_empty;
wire        tape_slow = (status[66:64] == 3'b100) ? 1'b1 : 1'b0;

wire        emu_flash_request;
wire        emu_flash_slave;

wire [64:0] rtc;

wire       pokeymax_enable = status[20];
wire [1:0] pokeymax_channel_en = { ~status[33], ~status[32] };
wire       pokeymax_mono_detect = ~status[71];
wire [3:0] pokeymax_post_divide = { status[75:74] + 2'b10, status[73:72] + 2'b10 };
wire [1:0] pokeymax_gtia_mix = status[77:76] + 2'b11;
wire [1:0] pokeymax_adc_vol = status[79:78] + 2'b10;
wire [1:0] pokeymax_pokey_restrict = status[81:80] == 2'b00 ? 2'b11 : status[81:80] - 2'b01;
wire       pokeymax_volume = ~status[82];
wire       pokeymax_channel_mode = status[83];
wire       pokeymax_irqs = status[84];
wire       pokeymax_sid_restrict = ~status[85];
wire [2:0] pokeymax_sid1_filter = { status[89] ? status[89:88] : { 1'b0, ~status[88] }, status[86] };
wire [2:0] pokeymax_sid2_filter = { status[91] ? status[91:90] : { 1'b0, ~status[90] }, status[87] };
wire [2:0] pokeymax_mix_sel1 = status[94:92] < 3'b101 ? status[94:92] : status[94:92] + 3'b001;
wire [2:0] pokeymax_mix_sel2 = status[98:96] < 3'b100 ? status[98:96] + 3'b001 : status[98:96] + 3'b010;
wire       pokeymax_covox_restrict = ~status[95];
wire       pokeymax_psg_restrict = ~status[99];
wire [1:0] pokeymax_psg_freq = status[101:100];
wire [1:0] pokeymax_psg_stereo = status[103:102] + 2'b01;
wire       pokeymax_psg_envelope = status[104];
wire [1:0] pokeymax_psg_volume = status[106:105];

wire [38:0] pokeymax_config = {
	pokeymax_mix_sel2,			// 38:36
	pokeymax_mix_sel1,			// 35:33
	pokeymax_psg_stereo,		// 32:31
	pokeymax_psg_envelope,		// 30
	pokeymax_psg_volume,		// 29:28
	pokeymax_psg_freq,			// 27:26
	pokeymax_sid2_filter,		// 25:23
	pokeymax_sid1_filter,		// 22:20
	pokeymax_covox_restrict,	// 19
	pokeymax_psg_restrict,		// 18
	pokeymax_sid_restrict,		// 17
	pokeymax_pokey_restrict,	// 16:15
	pokeymax_irqs,				// 14
	pokeymax_volume,			// 13
	pokeymax_channel_mode,		// 12
	pokeymax_adc_vol,			// 11:10
	pokeymax_gtia_mix,			// 9:8
	pokeymax_post_divide,		// 7:4
	pokeymax_channel_en,		// 3:2
	pokeymax_mono_detect,		// 1
	pokeymax_enable				// 0
};

wire file_download = ioctl_download && (ioctl_index != 99);

always @(posedge clk_sys) begin
	reg started = 0;
	reg upload_prev = 0;

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
			if((ioctl_wr & ioctl_download) | ((ioctl_rd | ~upload_prev) & ioctl_upload)) begin
				ioctl_wait <= 1;
				dma_req <= 1;
			end
		end
		else
			ioctl_wait <= 0;
	end
	upload_prev <= ioctl_upload;
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
	.status_menumask({(~status[95] | ~status[85]) & status[20], ~status[99] & status[20],~status[95] & status[20],~status[85] & status[20],status[20],~status[2] & pbi_rom_loaded, status[31] & status[5], status[5] & ~status[59] & ~status[60], ~status[2] & status[42] & pbi_rom_loaded, status[2], en216p}),
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
	.set_start_force(set_start_force),
	.set_space_force(set_space_force),
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
	.uart_data_read(uart_data_read),
	.tape_data(tape_data),
	.tape_data_wr(tape_data_wr),
	.tape_reset(tape_reset),

	.emu_flash_request(emu_flash_request),
	.emu_flash_slave(emu_flash_slave),
	.emu_flash_autosave(status[69] & ~status[57]),
	.emu_flash_save(status[70]),
	.emu_cart_trigger(~status[68])
);

wire [7:0] R,G,B, Ro,Go,Bo;
wire HBlank,VBlank,HBlank_o,VBlank_o;
wire VSync, HSync, VSync_o, HSync_o;
wire ce_pix;
wire ce_pix_raw;

assign CLK_VIDEO = clk_vdo;

wire cpu_halt;

wire [15:0] laudio, raudio;
assign AUDIO_L = (cpu_halt | areset | reset) ? 16'b0000000000000000 : laudio;
assign AUDIO_R = (cpu_halt | areset | reset) ? 16'b0000000000000000 : raudio;
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
	//.OSD_PAUSE(file_download),
	.OSD_PAUSE(0),
	.SET_RESET_IN(set_reset),
	.SET_PAUSE_IN(set_pause),
	.SET_FREEZER_IN(set_freezer),
	.SET_RESET_RNMI_IN(set_reset_rnmi),
	.SET_OPTION_FORCE_IN(set_option_force),
	.SET_START_FORCE_IN(set_start_force),
	.SET_SPACE_FORCE_IN(set_space_force),
	.CART1_SELECT_IN(cart1_select),
	.CART2_SELECT_IN(cart2_select),
	.EMU_FLASH_REQUEST(emu_flash_request),
	.EMU_FLASH_SLAVE(emu_flash_slave),
	.HOT_KEYS(atari_hotkeys),

	.UART_ADDR(uart_addr),
	.UART_ENABLE(uart_enable),
	.UART_WR(uart_wr),
	.UART_DATA_WRITE(uart_data_write),
	.UART_DATA_READ(uart_data_read),

	.TAPE_DATA(tape_data),
	.TAPE_DATA_WR(tape_data_wr),
	.TAPE_FIFO_FULL(tape_fifo_full),
	.TAPE_FIFO_EMPTY(tape_fifo_empty),
	.TAPE_PWM_CONFIG(status[66:64]),
	.TAPE_PWM_INVERT(status[67]),
	.TAPE_RESET(tape_reset),
	.TAPE_ACTIVE(tape_active),

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

	.POKEYMAX_CONFIG(pokeymax_config),
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
// sid_data.bin
//wire siddata_rom_index = ioctl_index[5:0] == 7; // wire currently unused

wire[25:0] rom_upload_addr;
assign rom_upload_addr =
	xl_rom_index ? {10'h270, 2'b01, ioctl_addr[13:0]} :
	(osab_rom_index ? {10'h270, 2'b10, ioctl_addr[13:0]} + 14'h1800 :
	(basic_rom_index ? {10'h270, 3'b000, ioctl_addr[12:0]} :
	(pbi_rom_index ? {10'h270, 3'b001, ioctl_addr[12:0]} : 
	(turbofreezer_rom_index ? {10'h24A, ioctl_addr[15:0]} :
	{9'b100111101, ioctl_addr[16:0]})))); // SID data, 128K

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
assign atari_status2 = {tape_fifo_full, tape_fifo_empty, tape_active, tape_slow, splashpbi, bootpbi, drivesmodepbi};

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
