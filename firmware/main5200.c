static const int main_ram_size=16384;
#include "main.h" //!!!

#include "printf.h"
#include "joystick.h" 
#include "freeze.h"

int debug_pos;
int debug_adjust;
unsigned char volatile * baseaddr;

unsigned char toatarichar(int val)
{
	int inv = val>=128;
	if (inv)
	{
		val-=128;
	}
	if (val>='A' && val<='Z')
	{
		val+=-'A'+33;
	}
	else if (val>='a' && val<='z')
	{
		val+=-'a'+33+64;
	}
	else if (val>='0' && val<='9')
	{
		val+=-'0'+16;	
	}
	else if (val>=32 && val<=47)
	{
		val+=-32;
	}
	else if (val == ':')
	{
		val = 26;
	}
	else if (val == '<')
	{
		val = 28;
	}
	else if (val == '>')
	{
		val = 30;
	}
	else
	{
		val = 0;
	}
	if (inv)
	{
		val+=128;
	}
	return val;
} 

void clearscreen()
{
	unsigned volatile char * screen;
	for (screen=(unsigned volatile char *)(screen_address+atari_regbase); screen!=(unsigned volatile char *)(atari_regbase+screen_address+1024); ++screen)
		*screen = 0x00;
}

void char_out ( void* p, char c)
{
	unsigned char val = toatarichar(c);
	if (debug_pos>=0)
	{
		*(baseaddr+debug_pos) = val|debug_adjust;
		++debug_pos;
	}
}

int last_mount;

void loadromfile(struct SimpleFile * file, int size, size_t ram_address)
{
	void* absolute_ram_address = SDRAM_BASE + ram_address;
	int read = 0;
	file_read(file, absolute_ram_address, size, &read);
} 

void load_cartridge(int type)
{
	switch(type)
	{
	case 4: //32k
		loadromfile(files[4],0x8000,0x004000);
		break;
	case 6: // 16k two chip
		{
			unsigned char * src = (unsigned char *)(0x4000 + SDRAM_BASE);
			unsigned char * dest1 = (unsigned char *)(0x6000 + SDRAM_BASE);
			unsigned char * src2 = (unsigned char *)(0x8000 + SDRAM_BASE);
			unsigned char * dest2 = (unsigned char *)(0xa000+ SDRAM_BASE);
			int i = 0;
			//*atari_colbk = 0x68;
			//wait_us(5000000);

			loadromfile(files[4],0x2000,0x004000);
			loadromfile(files[4],0x2000,0x008000);
	
			for (i=0; i!=0x2000; ++i)
			{
				dest1[i] = src[i];
				dest2[i] = src2[i];
			}
		}
		break;
	case 16: // 16k one chip
		{
			loadromfile(files[4],0x4000,0x008000);
			unsigned char * src = (unsigned char *)(0x8000 + SDRAM_BASE);
			unsigned char * dest1 = (unsigned char *)(0x4000 + SDRAM_BASE);
			int i = 0;
			for (i=0; i!=0x4000; ++i)
			{
				dest1[i] = src[i];
			}
		}
		break;
	case 19: // 8k
		{
			//*atari_colbk = 0x58;
			//wait_us(4000000);
			loadromfile(files[4],0x2000,0x004000);
			unsigned char * src = (unsigned char *)(0x4000 + SDRAM_BASE);
			unsigned char * dest1 = (unsigned char *)(0x6000 + SDRAM_BASE);
			unsigned char * dest2 = (unsigned char *)(0x8000 + SDRAM_BASE);
			unsigned char * dest3 = (unsigned char *)(0xa000 + SDRAM_BASE);
			int i = 0;
			for (i=0; i!=0x2000; ++i)
			{
				dest1[i] = src[i];
				dest2[i] = src[i];
				dest3[i] = src[i];
			}
		}
		break;
	case 20: // 4k
		{
			//*atari_colbk = 0x58;
			//wait_us(4000000);
			loadromfile(files[4],0x1000,0x004000);
			unsigned char * src = (unsigned char *)(0x4000 + SDRAM_BASE);
			unsigned char * dest1 = (unsigned char *)(0x5000 + SDRAM_BASE);
			unsigned char * dest2 = (unsigned char *)(0x6000 + SDRAM_BASE);
			unsigned char * dest3 = (unsigned char *)(0x7000 + SDRAM_BASE);
			unsigned char * dest4 = (unsigned char *)(0x8000 + SDRAM_BASE);
			unsigned char * dest5 = (unsigned char *)(0x9000 + SDRAM_BASE);
			unsigned char * dest6 = (unsigned char *)(0xa000 + SDRAM_BASE);
			unsigned char * dest7 = (unsigned char *)(0xb000 + SDRAM_BASE);
			int i = 0;
			for (i=0; i!=0x1000; ++i)
			{
				dest1[i] = src[i];
				dest2[i] = src[i];
				dest3[i] = src[i];
				dest4[i] = src[i];
				dest5[i] = src[i];
				dest6[i] = src[i];
				dest7[i] = src[i];
			}
		}
		break;
	default:
		{
			clearscreen();
			debug_pos = 0;
			debug_adjust = 0;
			printf("Unknown type of cartridge!");
			wait_us(3000000);
		}
		break;
	}
}

int select_cartridge()
{
	// work out the type
	int type = -1;
	int size = file_size(files[4]);

	if (size == 32768) type = 4;
	else if (size == 16384)
	{
		struct joystick_status joy;
		joy.x_ = joy.y_ = joy.fire_ = joy.escape_ = 0;

		clearscreen();
		debug_pos = 0;
		debug_adjust = 0;
		printf("16k cart type");
		debug_pos = 80;
		printf("           PRESS            ");
		debug_pos = 120;
		printf("One chip <--   --> Two chips");

		while(type <0)
		{
			joystick_wait(&joy,WAIT_QUIET);
			joystick_wait(&joy,WAIT_EITHER);

			if (joy.x_<0) type = 16;
			if (joy.x_>0) type = 6;
		}
	}
	else if (size == 8192) type = 19;
	else if (size == 4096) type = 20;
	else if (file_type(files[4]) == 0)
	{
		char header[16];
		int read = 0;
		file_read(files[4],header,16,&read);
		type = header[7];
	}

	load_cartridge(type);
	return 1;
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
		
		set_pause_6502(1);
		freeze();

		set_sd_data_mode(1);
		struct SimpleFile *file = files[4];
		file->size = *zpu_in3;
		file->type = get_sd_filetype();
		file->is_readonly = get_sd_readonly();
		file->offset = 0;
		file_reset();

		select_cartridge();

		restore();
		reboot(1);	
	}
}

void mainmenu()
{
	memset8(SRAM_BASE+0x4000, 0, 32768);
	memset32(SDRAM_BASE+0x4000, 0, 32768/4);

	freeze_init((void*)FREEZE_MEM); // 128k
 
	debug_pos = -1;
	debug_adjust = 0;
	baseaddr = (unsigned char volatile *)(screen_address + atari_regbase);

	init_printf(0, char_out);
	
	last_mount = get_sd_mounted();
	file_reset();

	reboot(1);
	for (;;) actions();
}
