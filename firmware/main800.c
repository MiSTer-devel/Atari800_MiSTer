static const int main_ram_size=65536;

#define XEX_LOADER_LOC 7 // XEX Loader is at $x00 by default

#include "main.h" //!!!
#include "atari_drive_emulator.h"

struct CartDef {
	unsigned char carttype;	// type from CAR header
	unsigned char name[16]; // name of type
	unsigned char mode;		// mode used in cartridge emulation
	unsigned short size;	// size in k
};

// 8k modes (0xA000-$BFFF)
#define TC_MODE_OFF             0x00           // cart disabled
#define TC_MODE_8K              0x01           // 8k banks at $A000
#define TC_MODE_ATARIMAX1       0x02           // 8k using Atarimax 1MBit compatible banking
#define TC_MODE_ATARIMAX8       0x03           // 8k using Atarimax 8MBit compatible banking
#define TC_MODE_ATARIMAX8_2     0x10           // 8k using Atarimax 8MBit compatible banking (new type)
#define TC_MODE_DCART           0x11           // 512K DCart
#define TC_MODE_OSS_16          0x04           // 16k OSS cart, M091 banking
#define TC_MODE_OSS_8           0x05           // 8k OSS cart, M091 banking
#define TC_MODE_OSS_043M        0x06           // 16k OSS cart, 043M banking

#define TC_MODE_SDX64           0x08           // SDX 64k cart, $D5Ex banking
#define TC_MODE_SDX128          0x09           // SDX 128k cart, $D5Ex banking
#define TC_MODE_DIAMOND64       0x0A           // Diamond GOS 64k cart, $D5Dx banking
#define TC_MODE_EXPRESS64       0x0B           // Express 64k cart, $D57x banking

#define TC_MODE_ATRAX128        0x0C           // Atrax 128k cart
#define TC_MODE_WILLIAMS64      0x0D           // Williams 64k cart
#define TC_MODE_WILLIAMS32      0x0E           // Williams 32k cart
#define TC_MODE_WILLIAMS16      0x0F           // Williams 16k cart

// 16k modes (0x8000-$BFFF)
//#define TC_MODE_FLEXI           0x20           // flexi mode
#define TC_MODE_16K             0x21           // 16k banks at $8000-$BFFF
#define TC_MODE_MEGAMAX16       0x22           // MegaMax 16k mode (up to 2MB)
#define TC_MODE_BLIZZARD        0x23           // Blizzard 16k
#define TC_MODE_SIC_128         0x24           // Sic!Cart 128k
#define TC_MODE_SIC_256         0x25           // Sic!Cart 256k
#define TC_MODE_SIC_512         0x26           // Sic!Cart 512k
#define TC_MODE_SIC_1024        0x27           // Sic!Cart+ 1024k

#define TC_MODE_BLIZZARD_4      0x12           // Blizzard 4k
#define TC_MODE_BLIZZARD_32     0x13           // Blizzard 32k
#define TC_MODE_RIGHT_8K	0x14
#define TC_MODE_RIGHT_4K	0x15
#define TC_MODE_2K		0x16
#define TC_MODE_4K		0x17

// J(atari)Cart versions
#define TC_MODE_JATARI_8	0x18
#define TC_MODE_JATARI_16	0x19
#define TC_MODE_JATARI_32	0x1A
#define TC_MODE_JATARI_64	0x1B
#define TC_MODE_JATARI_128	0x1C
#define TC_MODE_JATARI_256	0x1D
#define TC_MODE_JATARI_512	0x1E
#define TC_MODE_JATARI_1024	0x1F

#define TC_MODE_MEGA_16         0x28           // switchable MegaCarts
#define TC_MODE_MEGA_32         0x29
#define TC_MODE_MEGA_64         0x2A
#define TC_MODE_MEGA_128        0x2B
#define TC_MODE_MEGA_256        0x2C
#define TC_MODE_MEGA_512        0x2D
#define TC_MODE_MEGA_1024       0x2E
#define TC_MODE_MEGA_2048       0x2F

#define TC_MODE_XEGS_32         0x30           // non-switchable XEGS carts
#define TC_MODE_XEGS_64         0x31
#define TC_MODE_XEGS_128        0x32
#define TC_MODE_XEGS_256        0x33
#define TC_MODE_XEGS_512        0x34
#define TC_MODE_XEGS_1024       0x35
#define TC_MODE_XEGS_64_2       0x36

#define TC_MODE_SXEGS_32        0x38           // switchable XEGS carts
#define TC_MODE_SXEGS_64        0x39
#define TC_MODE_SXEGS_128       0x3A
#define TC_MODE_SXEGS_256       0x3B
#define TC_MODE_SXEGS_512       0x3C
#define TC_MODE_SXEGS_1024      0x3D

// XE Multicart versions
#define TC_MODE_XEMULTI_8	0x68
#define TC_MODE_XEMULTI_16	0x69
#define TC_MODE_XEMULTI_32	0x6A
#define TC_MODE_XEMULTI_64	0x6B
#define TC_MODE_XEMULTI_128	0x6C
#define TC_MODE_XEMULTI_256	0x6D
#define TC_MODE_XEMULTI_512	0x6E
#define TC_MODE_XEMULTI_1024	0x6F

#define TC_MODE_PHOENIX		0x40
#define TC_MODE_AST_32		0x41
#define TC_MODE_ATRAX_INT128	0x42
#define TC_MODE_ATRAX_SDX64	0x43
#define TC_MODE_ATRAX_SDX128	0x44
#define TC_MODE_TSOFT_64	0x45
#define TC_MODE_TSOFT_128	0x46
#define TC_MODE_ULTRA_32	0x47
#define TC_MODE_DAWLI_32	0x48
#define TC_MODE_DAWLI_64	0x49
#define TC_MODE_JRC_LIN_64	0x4A
#define TC_MODE_JRC_INT_64	0x4B
#define TC_MODE_SDX_SIDE2	0x4C
#define TC_MODE_SDX_U1MB	0x4D
#define TC_MODE_DB_32		0x70
#define TC_MODE_CORINA_512	0x71
#define TC_MODE_CORINA_1024	0x72
#define TC_MODE_BOUNTY_40	0x73

static struct CartDef cartdef[] =
{
	{ 1,  "Standard 8K    \x00", TC_MODE_8K,          8 },
	{ 2,  "Standard 16K   \x00", TC_MODE_16K,        16 },
	// This below is intentional, for 034M carts we fix them
	// (we also need to add 2 extra fake AND-ed banks for 
	// both 043M and 034M)
	{ 3,  "OSS 2 Chip 034M\x00", TC_MODE_OSS_043M,   16 },
	{ 5,  "DB 32K         \x00", TC_MODE_DB_32,      32 },
	{ 8,  "Williams 64K   \x00", TC_MODE_WILLIAMS64, 64 },
	{ 9,  "Express 64K    \x00", TC_MODE_EXPRESS64,  64 },
	{ 10, "Diamond 64K    \x00", TC_MODE_DIAMOND64,  64 },
	{ 11, "SpartaDOSX 64K \x00", TC_MODE_SDX64,      64 },
	{ 12, "XEGS 32K       \x00", TC_MODE_XEGS_32,    32 },
	{ 13, "XEGS 64K (0-7) \x00", TC_MODE_XEGS_64,    64 },
	{ 14, "XEGS 128K      \x00", TC_MODE_XEGS_128,  128 },
	{ 15, "OSS 1 Chip 16K \x00", TC_MODE_OSS_16,     16 },
	{ 17, "Atrax DEC 128K \x00", TC_MODE_ATRAX128,  128 },
	{ 18, "Bounty Bob     \x00", TC_MODE_BOUNTY_40,  40 },
	{ 21, "Right 8K       \x00", TC_MODE_RIGHT_8K,    8 },
	{ 22, "Williams 32K   \x00", TC_MODE_WILLIAMS32, 32 },
	{ 23, "XEGS 256K      \x00", TC_MODE_XEGS_256,  256 },
	{ 24, "XEGS 512K      \x00", TC_MODE_XEGS_512,  512 },
	{ 25, "XEGS 1024K     \x00", TC_MODE_XEGS_1024,1024 },
	{ 26, "MegaCart 16K   \x00", TC_MODE_MEGA_16,    16 },
	{ 27, "MegaCart 32K   \x00", TC_MODE_MEGA_32,    32 },
	{ 28, "MegaCart 64K   \x00", TC_MODE_MEGA_64,    64 },
	{ 29, "MegaCart 128K  \x00", TC_MODE_MEGA_128,  128 },
	{ 30, "MegaCart 256K  \x00", TC_MODE_MEGA_256,  256 },
	{ 31, "MegaCart 512K  \x00", TC_MODE_MEGA_512,  512 },
	{ 32, "MegaCart 1024K \x00", TC_MODE_MEGA_1024,1024 },
	{ 33, "S.XEGS 32K     \x00", TC_MODE_SXEGS_32,   32 },
	{ 34, "S.XEGS 64K     \x00", TC_MODE_SXEGS_64,   64 },
	{ 35, "S.XEGS 128K    \x00", TC_MODE_SXEGS_128, 128 },
	{ 36, "S.XEGS 256K    \x00", TC_MODE_SXEGS_256, 256 },
	{ 37, "S.XEGS 512K    \x00", TC_MODE_SXEGS_512, 512 },
	{ 38, "S.XEGS 1024K   \x00", TC_MODE_SXEGS_1024,1024 },
	{ 39, "Phoenix 8K     \x00", TC_MODE_PHOENIX,     8 },
	{ 40, "Blizzard 16K   \x00", TC_MODE_BLIZZARD,   16 },
	{ 41, "Atarimax 128K  \x00", TC_MODE_ATARIMAX1, 128 },
	{ 42, "Atarimax 1MB   \x00", TC_MODE_ATARIMAX8,1024 },
	{ 43, "SpartaDOSX 128K\x00", TC_MODE_SDX128,    128 },
	{ 44, "OSS 1 Chip 8K  \x00", TC_MODE_OSS_8,       8 },
	{ 45, "OSS 2 Chip 043M\x00", TC_MODE_OSS_043M,   16 },
	{ 46, "Blizzard 4K    \x00", TC_MODE_BLIZZARD_4,  4 },
	{ 47, "AST 32K        \x00", TC_MODE_AST_32,     32 },
	{ 48, "Atrax SDX 64K  \x00", TC_MODE_ATRAX_SDX64,64 },
	{ 49, "Atrax SDX 128K \x00", TC_MODE_ATRAX_SDX128,128 },
	{ 50, "TurboSoft 64K  \x00", TC_MODE_TSOFT_64,   64 },
	{ 51, "TurboSoft 128K \x00", TC_MODE_TSOFT_128, 128 },
	{ 52, "UltraCart 32K  \x00", TC_MODE_ULTRA_32,   32 },
	{ 53, "Low Bank XL 8K \x00", TC_MODE_RIGHT_8K,    8 },
	{ 54, "SIC 128K       \x00", TC_MODE_SIC_128,   128 },
	{ 55, "SIC 256K       \x00", TC_MODE_SIC_256,   256 },
	{ 56, "SIC 512K       \x00", TC_MODE_SIC_512,   512 },
	{ 57, "Standard 2K    \x00", TC_MODE_2K,          2 },
	{ 58, "Standard 4K    \x00", TC_MODE_4K,          4 },
	{ 59, "Right 4K       \x00", TC_MODE_RIGHT_4K,    4 },
	{ 60, "Blizzard 32K   \x00", TC_MODE_BLIZZARD_32,32 },
	{ 61, "MegaMax 2048K  \x00", TC_MODE_MEGAMAX16,2048 },
	{ 64, "MegaCart 2048K \x00", TC_MODE_MEGA_2048,2048 },
	{ 67, "XEGS 64K (8-15)\x00", TC_MODE_XEGS_64_2,  64 },
	{ 68, "Atrax ENC 128K \x00", TC_MODE_ATRAX_INT128, 128 },
	{ 69, "aDawliah 32K   \x00", TC_MODE_DAWLI_32,   32 },
	{ 70, "aDawliah 64K   \x00", TC_MODE_DAWLI_64,   64 },
	{ 75, "Atarimax 1MB NT\x00", TC_MODE_ATARIMAX8_2,1024 },
	{ 76, "Williams 16K   \x00", TC_MODE_WILLIAMS16, 16 },
	{ 80, "JRC 64K (LIN)  \x00", TC_MODE_JRC_LIN_64, 64 },
	{ 83, "SIC+ 1024K     \x00", TC_MODE_SIC_1024,  1024 },
	{ 84, "Corina 1MB     \x00", TC_MODE_CORINA_1024, 1032 },
	{ 85, "Corina 512K    \x00", TC_MODE_CORINA_512, 520 },
	{ 86, "XE Multi 8K    \x00", TC_MODE_XEMULTI_8,   8 },
	{ 87, "XE Multi 16K   \x00", TC_MODE_XEMULTI_16, 16 },
	{ 88, "XE Multi 32K   \x00", TC_MODE_XEMULTI_32, 32 },
	{ 89, "XE Multi 64K   \x00", TC_MODE_XEMULTI_64, 64 },
	{ 90, "XE Multi 128K  \x00", TC_MODE_XEMULTI_128,128 },
	{ 91, "XE Multi 256K  \x00", TC_MODE_XEMULTI_256,256 },
	{ 92, "XE Multi 512K  \x00", TC_MODE_XEMULTI_512,512 },
	{ 93, "XE Multi 1MB   \x00", TC_MODE_XEMULTI_1024,1024 },
	{104, "J(atari) 8K    \x00", TC_MODE_JATARI_8,   8 },
	{105, "J(atari) 16K   \x00", TC_MODE_JATARI_16,  16 },
	{106, "J(atari) 32K   \x00", TC_MODE_JATARI_32,  32 },
	{107, "J(atari) 64K   \x00", TC_MODE_JATARI_64,  64 },
	{108, "J(atari) 128K  \x00", TC_MODE_JATARI_128,128 },
	{109, "J(atari) 256K  \x00", TC_MODE_JATARI_256,256 },
	{110, "J(atari) 512K  \x00", TC_MODE_JATARI_512,512 },
	{111, "J(atari) 1MB   \x00", TC_MODE_JATARI_1024,1024 },
	{112, "DCART 512K     \x00", TC_MODE_DCART,     512 },
	{160, "JRC 64K (INT)  \x00", TC_MODE_JRC_INT_64, 64 },
	{ 0, "", 0, 0 }
};

char comp[sizeof(cartdef)/sizeof(cartdef[0])];

int load_car(struct SimpleFile* file, u08 stacked)
{
	int i;
	if (CARTRIDGE_MEM == 0)
	{
		//LOG("no cartridge memory\n");
		return 0;
	}

	struct joystick_status joy;
	joy.x_ = joy.y_ = joy.fire_ = joy.escape_ = 0;

	enum SimpleFileStatus ok;
	unsigned char mode = TC_MODE_OFF;
	unsigned char carttype = 0;
	int len;
	
	unsigned int byte_len = file->size;
	if(!(byte_len & 0x3FF))
	{
		int sel, n = 0;
		unsigned int sz = (byte_len>>10);
		
		for(i=0;i<sizeof(cartdef)/sizeof(cartdef[0]); i++) if(sz == cartdef[i].size)
		{
			comp[n++] = i;
			mode = cartdef[i].mode;
			carttype = cartdef[i].carttype;
		}
		
		if(n != 1)
		{
			if(!n && stacked) return 0;
			unsigned char *one_block = (unsigned char *)(CARTRIDGE_MEM + 0x1FE000);
			ok = file_read(file, one_block, 0x2000, &len);
			file_seek(file, 0);
			if(ok == SimpleFile_OK && len == 0x2000 && one_block[0] == 'S' && one_block[1] == 'D' && one_block[2] == 'X' && (one_block[0x1FF3] == 0xE0 || one_block[0x1FF3] == 0xE1))
			{
				mode = (one_block[0x1FF3] == 0xE1) ? TC_MODE_SDX_SIDE2 : TC_MODE_SDX_U1MB;
				n = 1;
			}
			if(!n)
			{
				return 0;
			}
		}
		sel = 0;
		if(n > 1)
		{
			clearscreen();
			debug_pos = 0;
			debug_adjust = 0;
			printf("Select cart type");
			debug_pos = 80;
			printf("Fire 1 -> Select, Fire 2 -> Cancel");

			while(1)
			{
				int pos = 160;
				for(i=0;i<n;i++)
				{
					debug_adjust = (i==sel) ? 128 : 0;
					debug_pos = pos;
					printf(cartdef[comp[i]].name);
					pos += 40;
				}
				
				wait_us(100000);
				joystick_wait(&joy,WAIT_QUIET);
				joystick_wait(&joy,WAIT_EITHER);
				if (joy.escape_) return 0;
				
				if (joy.fire_)
				{
					mode = cartdef[comp[sel]].mode;
					carttype = cartdef[comp[sel]].carttype;
					break;
				}
				
				if(joy.y_ < 0 && sel > 0  ) sel--;
				if(joy.y_ > 0 && sel < n-1) sel++;
			}
		}
	}
	else
	{
		unsigned char header[16];
		ok = file_read(file, header, 16, &len);
		if (ok != SimpleFile_OK || len != 16)
		{
			//LOG("cannot read cart header\n");
			return 0;
		}
		carttype = header[7];

		// search for cartridge definition
		struct CartDef* def = cartdef;
		while (def->carttype && def->carttype != carttype) {
			def++;
		}
		if (def->carttype == 0)
		{
			//LOG("illegal cart type %d\n", carttype);
			return 0;
		}
		byte_len = (unsigned int) def->size << 10;
		mode = def->mode;
	}
	if(stacked && (byte_len > 0x100000 || carttype == 85))
	{
		return 0;
	}

	ok = file_read(file, CARTRIDGE_MEM + (stacked ? 0x100000 : 0), byte_len, &len);
	if (ok != SimpleFile_OK || len != byte_len)
	{
		//LOG("cannot read cart data\n");
		return 0;
	}

	// OSS 034M -> fix the broken bank layout to make it 043M
	if(carttype == 3)
	{
		memcp8((unsigned char *)(CARTRIDGE_MEM + (stacked ? 0x100000 : 0)+0x1000), (unsigned char *)(CARTRIDGE_MEM + (stacked ? 0x100000 : 0)+0x4000), 0, 0x1000);
		memcp8((unsigned char *)(CARTRIDGE_MEM + (stacked ? 0x100000 : 0)+0x2000), (unsigned char *)(CARTRIDGE_MEM + (stacked ? 0x100000 : 0)+0x1000), 0, 0x1000);
		memcp8((unsigned char *)(CARTRIDGE_MEM + (stacked ? 0x100000 : 0)+0x4000), (unsigned char *)(CARTRIDGE_MEM + (stacked ? 0x100000 : 0)+0x2000), 0, 0x1000);
		carttype = 45;
	}
	
	// OSS 043M -> we fake two AND blocks here, there is probably no SW 
	// that relies on this, but this is what the spec says
	if(carttype == 45)
	{
		for(i=0; i < 0x1000; i++)
		{
			*((unsigned char *)(CARTRIDGE_MEM + (stacked ? 0x100000 : 0)+0x4000+i)) = *((unsigned char *)(CARTRIDGE_MEM + (stacked ? 0x100000 : 0)+0x2000+i)) & *((unsigned char *)(CARTRIDGE_MEM + (stacked ? 0x100000 : 0)+0x0000+i));
			*((unsigned char *)(CARTRIDGE_MEM + (stacked ? 0x100000 : 0)+0x5000+i)) = *((unsigned char *)(CARTRIDGE_MEM + (stacked ? 0x100000 : 0)+0x2000+i)) & *((unsigned char *)(CARTRIDGE_MEM + (stacked ? 0x100000 : 0)+0x1000+i));
		}
	}
	// Corina 512K cart, move the last 8K EEPROM data to the 1024K boundary
	// clean the SRAM part
	if(carttype == 85)
	{
		memcp8((unsigned char *)(CARTRIDGE_MEM+0x80000), (unsigned char *)(CARTRIDGE_MEM+0x100000), 0, 0x2000);
		memset32((unsigned char *)(CARTRIDGE_MEM+0x80000), 0, 0x20000);
	}
	//LOG("cart type: %d size: %dk\n", def->mode, def->size);
	return mode;
}

#include "xex_loader.h"

void mainloop()
{
	init_drive_emulator();

	reboot(1, 0);
	while (1)
	{
		processCommand();
	}

}

unsigned char volatile *xex_loader_base;
int xex_file_first_block;
unsigned char xex_reloc;
unsigned char pbi_drives_config[4];

void actions()
{
	int mounted = get_sd_mounted();

	if (get_hotkey_softboot())
	{
		reboot(0, 0);	
	}
	else if (get_hotkey_coldboot())
	{
		reboot(1, 0);	
	}
	
	if (last_mount != mounted)
	{
		last_mount = mounted;
		
		set_sd_data_mode_on();
		int num = get_sd_fileno();
		struct SimpleFile *file = &files[num];
		file->size = *zpu_in3;
		file->type = get_sd_filetype();
		file->is_readonly = get_sd_readonly();
		file->offset = 0;
		file_reset();

		if(num<4)
		{
			//set_cart_select(0);
			set_drive_status(num, file->size ? file : 0);
		}
		else if(num == 6)
		{
			set_pause_6502(1);
			set_cart_select(0);
			// TODO Unmount all the other drives?
			set_drive_status(0, file->size ? file : 0);
			reboot(1, 0);
			// Important: if you set Option key before reset it will be cleared by reset
			set_option_force_on();
			set_option_force_off();
		}
		else if(num == 5)
		{
			if(file->size)
			{
				xex_file = file;
				xex_file_first_block = 1;

				set_pause_6502(1);
				set_cart_select(0);

				// Clean reboot, but hold it for now
				reboot(1, 1);
				// Reinitialize the whole memory to 0 rather than the DRAM pattern
				memset8(SDRAM_BASE, 0x00, main_ram_size);

				xex_reloc = get_xexloc() ? 1 : XEX_LOADER_LOC;

				xex_loader_base = (unsigned char volatile *)(atari_regbase + xex_reloc*0x100);
				memcp8(xex_loader, (unsigned char *)(atari_regbase + (XEX_LOADER_LOC << 8)), 0, XEX_LOADER_SIZE);
				if(xex_reloc != XEX_LOADER_LOC)
				{
					((unsigned char volatile *)(atari_regbase+(XEX_LOADER_LOC << 8)))[XEX_STACK_FLAG] = xex_reloc;
				}

				*atari_coldst = 0;
				*atari_basicf = 1;
				*atari_gintlk = 0;
				if(!get_mode800())
				{
					*atari_pupbt1 = 0x5C;
					*atari_pupbt2 = 0x93;
					*atari_pupbt3 = 0x25;
				}
				*atari_bootflag = 2;
				*atari_casinil = XEX_INIT1;  
				*atari_casinih = 0x07;
				*atari_dosvecl = 0x71;
				*atari_dosvech = 0xE4;

				set_pause_6502(0);
			}
		}
		else if(num == 4 || num == 7)
		{
			u08 stacked = (num == 7) ? 1 : 0;
			set_pause_6502(1);
			freeze();

			if(!file->size)
			{
				if(stacked)
				{
					set_cart2_select(0);	
				}
				else
				{
					set_cart_select(0);
				}
			}
			else
			{
				int type = load_car(file, stacked);

				if(stacked)
				{
					set_cart2_select(0);	
				}
				else
				{
					set_cart_select(0);					
				}
				if(!type)
				{
					clearscreen();
					debug_pos = 0;
					debug_adjust = 0;
					printf("Unknown cart type!");
					wait_us(2000000);
				}
				else
				{
					if(stacked)
					{
						set_cart2_select(type);	
					}
					else
					{
						if(type != TC_MODE_SDX64 && type != TC_MODE_SDX128 &&
							type != TC_MODE_ATRAX_SDX64 && type != TC_MODE_ATRAX_SDX128 && 
							type != TC_MODE_SDX_U1MB && type != TC_MODE_SDX_SIDE2)
						{
							for(mounted = 0; mounted < 4; mounted ++)
							{
								set_drive_status(mounted, 0);
							}
						}
						set_cart_select(type);
					}
				}
			}

			restore();
			if(!stacked || get_mode800())
			{
				reboot(1, 0);
			}
		}
	}

	if(xex_file)
	{
		// Is loader ready?
		if(xex_loader_base[0] == 0x60)
		{
			if(!xex_loader_base[XEX_READ_STATUS])
			{
				unsigned char len_buf[2];
				enum SimpleFileStatus ok;
				int read_offset, to_read;

				len_buf[0] = 0xFF;
				len_buf[1] = 0xFF;

				// Point to rts
				*atari_initadl = 0;  
				*atari_initadh = xex_reloc;
				
				// NOTE! purposely reusing the "mounted" variable
				while(len_buf[0] == 0xFF && len_buf[1] == 0xFF)
				{					
					ok = file_read(xex_file, len_buf, 2, &mounted);
					if(ok != SimpleFile_OK || mounted != 2)
						goto xex_eof;
				}
				read_offset = (len_buf[0] & 0xFF) | ((len_buf[1] << 8) & 0xFF00);
				if(xex_file_first_block)
				{
					xex_file_first_block = 0;					
					*atari_runadl = len_buf[0];
					*atari_runadh = len_buf[1];
				}
				
				ok = file_read(xex_file, len_buf, 2, &mounted);
				if(ok != SimpleFile_OK || mounted != 2)
					goto xex_eof;
				
				to_read = ((len_buf[0] & 0xFF) | ((len_buf[1] << 8) & 0xFF00)) + 1 - read_offset;
				if(to_read < 1)
					goto xex_eof;

				ok = file_read(xex_file, (unsigned char *)(atari_regbase + read_offset), to_read, &mounted);

				if(ok != SimpleFile_OK || mounted != to_read)
					goto xex_eof;

				xex_loader_base[XEX_READ_STATUS] = 1;
			}
		}
		// Is loader done?
		else if(xex_loader_base[0] == 0x5F)
xex_eof:
		{
			xex_loader_base[XEX_READ_STATUS] = 0xFF;
			xex_file = 0;
		}
	}

	volatile unsigned char *pbi_ram_base = (volatile unsigned char *)(atari_regbase+0xD100);

	if(get_modepbi() && pbi_ram_base[0] == 0xa5 && pbi_ram_base[1] == 0xa5)
	{
		if(pbi_ram_base[2] == 0x01)
		{
			
			pbi_drives_config[0] = (*zpu_in2 >> 16) & 0x3;
			pbi_drives_config[1] = (*zpu_in2 >> 18) & 0x3;
			pbi_drives_config[2] = (*zpu_in2 >> 20) & 0x3;
			pbi_drives_config[3] = (*zpu_in2 >> 22) & 0x3;
			pbi_ram_base[3] = get_splashpbi();
			memcp8(pbi_drives_config, &pbi_ram_base[0x0C], 0, 4);
			unsigned char boot_drv = get_bootpbi();
			pbi_ram_base[0x0B] = boot_drv;
			if(boot_drv == 1 && drive_infos[MAX_DRIVES].file)
			{
				// APT
				*((volatile unsigned char *)(atari_regbase+0x0301)) = drive_infos[MAX_DRIVES].info & 0xF;
			}
			else if(boot_drv)
			{
				*((volatile unsigned char *)(atari_regbase+0x0301)) = (boot_drv-1);
			}
			pbi_ram_base[2] = 0;
		}
		else if(pbi_ram_base[4] == 0x01)
		{
			pbi_ram_base[5] = processCommandPBI(pbi_drives_config);
			pbi_ram_base[4] = 0;
		}
	}

	//pause as WIN is held down
	set_pause_6502(get_mod_win() ? 1 : 0);
}
