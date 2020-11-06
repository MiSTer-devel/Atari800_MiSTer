static const int main_ram_size=65536;

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
#define TC_MODE_OSS             0x04           // 16k OSS cart, M091 banking

#define TC_MODE_SDX64           0x08           // SDX 64k cart, $D5Ex banking
#define TC_MODE_DIAMOND64       0x09           // Diamond GOS 64k cart, $D5Dx banking
#define TC_MODE_EXPRESS64       0x0A           // Express 64k cart, $D57x banking

#define TC_MODE_ATRAX128        0x0C           // Atrax 128k cart
#define TC_MODE_WILLIAMS64      0x0D           // Williams 64k cart

// 16k modes (0x8000-$BFFF)
//#define TC_MODE_FLEXI           0x20           // flexi mode
#define TC_MODE_16K             0x21           // 16k banks at $8000-$BFFF
#define TC_MODE_MEGAMAX16       0x22           // MegaMax 16k mode (up to 2MB)
#define TC_MODE_BLIZZARD        0x23           // Blizzard 16k
#define TC_MODE_SIC             0x24           // Sic!Cart 512k

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

#define TC_MODE_SXEGS_32        0x38           // switchable XEGS carts
#define TC_MODE_SXEGS_64        0x39
#define TC_MODE_SXEGS_128       0x3A
#define TC_MODE_SXEGS_256       0x3B
#define TC_MODE_SXEGS_512       0x3C
#define TC_MODE_SXEGS_1024      0x3D

static struct CartDef cartdef[] =
{
	{ 1,  "Standard 8K    \x00", TC_MODE_8K,          8 },
	{ 2,  "Standard 16K   \x00", TC_MODE_16K,        16 },
	{ 8,  "Williams 64K   \x00", TC_MODE_WILLIAMS64, 64 },
	{ 9,  "Express 64K    \x00", TC_MODE_EXPRESS64,  64 },
	{ 10, "Diamond 64K    \x00", TC_MODE_DIAMOND64,  64 },
	{ 11, "SpartaDOS X 64K\x00", TC_MODE_SDX64,      64 },
	{ 12, "XEGS 32K       \x00", TC_MODE_XEGS_32,    32 },
	{ 13, "XEGS 64K       \x00", TC_MODE_XEGS_64,    64 },
	{ 14, "XEGS 128K      \x00", TC_MODE_XEGS_128,  128 },
	{ 15, "OSS 1 Chip 16K \x00", TC_MODE_OSS,        16 },
	{ 17, "Atrax 128K     \x00", TC_MODE_ATRAX128,  128 },
	{ 23, "XEGS 256K      \x00", TC_MODE_XEGS_256,  256 },
	{ 24, "XEGS 512K      \x00", TC_MODE_XEGS_512,  512 },
	{ 26, "MegaCart 16K   \x00", TC_MODE_MEGA_16,    16 },
	{ 27, "MegaCart 32K   \x00", TC_MODE_MEGA_32,    32 },
	{ 28, "MegaCart 64K   \x00", TC_MODE_MEGA_64,    64 },
	{ 29, "MegaCart 128K  \x00", TC_MODE_MEGA_128,  128 },
	{ 30, "MegaCart 256K  \x00", TC_MODE_MEGA_256,  256 },
	{ 31, "MegaCart 512K  \x00", TC_MODE_MEGA_512,  512 },
	{ 33, "S.XEGS 32K     \x00", TC_MODE_SXEGS_32,   32 },
	{ 34, "S.XEGS 64K     \x00", TC_MODE_SXEGS_64,   64 },
	{ 35, "S.XEGS 128K    \x00", TC_MODE_SXEGS_128, 128 },
	{ 36, "S.XEGS 256K    \x00", TC_MODE_SXEGS_256, 256 },
	{ 37, "S.XEGS 512K    \x00", TC_MODE_SXEGS_512, 512 },
	{ 40, "Blizzard 16K   \x00", TC_MODE_BLIZZARD,   16 },
	{ 41, "Atarimax 128K  \x00", TC_MODE_ATARIMAX1, 128 },
	{ 42, "Atarimax 1024K \x00", TC_MODE_ATARIMAX8,1024 },
	{ 56, "SIC 512K       \x00", TC_MODE_SIC,       512 },
	{ 0, "", 0, 0 }
};

char comp[sizeof(cartdef)/sizeof(cartdef[0])];

int load_car(struct SimpleFile* file)
{
	if (CARTRIDGE_MEM == 0)
	{
		//LOG("no cartridge memory\n");
		return 0;
	}

	struct joystick_status joy;
	joy.x_ = joy.y_ = joy.fire_ = joy.escape_ = 0;

	enum SimpleFileStatus ok;
	unsigned char mode = TC_MODE_OFF;
	int len;
	
	unsigned int byte_len = file_size(file);
	if(!(byte_len & 0x3FF))
	{
		int i, sel, n = 0;
		unsigned int sz = (byte_len>>10);
		
		for(i=0;i<sizeof(cartdef)/sizeof(cartdef[0]); i++) if(sz == cartdef[i].size)
		{
			comp[n++] = i;
			mode = cartdef[i].mode;
		}
		
		if(!n) return 0;

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
		unsigned char carttype = header[7];

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

	ok = file_read(file, CARTRIDGE_MEM, byte_len, &len);
	if (ok != SimpleFile_OK || len != byte_len)
	{
		//LOG("cannot read cart data\n");
		return 0;
	}

	//LOG("cart type: %d size: %dk\n", def->mode, def->size);
	return mode;
}


void mainloop()
{
	init_drive_emulator();

	reboot(1);
	run_drive_emulator();
}

void actions()
{
	int mounted = get_sd_mounted();

	if (get_hotkey_softboot())
	{
		reboot(0);	
	}
	else if (get_hotkey_coldboot())
	{
		reboot(1);	
	}
	
	if (last_mount != mounted)
	{
		last_mount = mounted;
		
		set_sd_data_mode(1);
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
			set_drive_status(num,file->size ? file : 0);
		}
		else
		{
			set_pause_6502(1);
			freeze();

			set_drive_status(0,0);
			set_drive_status(1,0);
			set_drive_status(3,0);
			set_drive_status(4,0);
			if(!file->size)
			{
				set_cart_select(0);
			}
			else
			{
				int type = load_car(file);
				set_cart_select(type);
				if(!type)
				{
					clearscreen();
					debug_pos = 0;
					debug_adjust = 0;
					printf("Unknown cart type!");
					wait_us(2000000);
				}
			}

			restore();
			reboot(1);
		}
	}

	//pause as WIN is held down
	set_pause_6502(get_mod_win() ? 1 : 0);
}
