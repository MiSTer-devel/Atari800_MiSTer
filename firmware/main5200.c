static const int main_ram_size=16384;
#include "main.h" //!!!

void loadromfile(int size, size_t ram_address)
{
	void* absolute_ram_address = SDRAM_BASE + ram_address;
	int read = 0;
	file_read(&files[4], absolute_ram_address, size, &read);
} 

void load_cartridge(int type)
{
	switch(type)
	{
	case 4: //32k
		loadromfile(0x8000,0x004000);
		break;
	case 6: // 16k two chip
		{
			unsigned char *src = (unsigned char *)(0x4000 + SDRAM_BASE);
			unsigned char *dest1 = (unsigned char *)(0x6000 + SDRAM_BASE);
			unsigned char *src2 = (unsigned char *)(0x8000 + SDRAM_BASE);
			unsigned char *dest2 = (unsigned char *)(0xa000+ SDRAM_BASE);
			int i = 0;
			//*atari_colbk = 0x68;
			//wait_us(5000000);

			loadromfile(0x2000,0x004000);
			loadromfile(0x2000,0x008000);
	
			for (i=0; i!=0x2000; ++i)
			{
				dest1[i] = src[i];
				dest2[i] = src2[i];
			}
		}
		break;
	case 7:
		{
			unsigned char *src  = (unsigned char *)(0x8000 + SDRAM_BASE);
			unsigned char *dest = (unsigned char *)(0xA000 + SDRAM_BASE);
			unsigned char *dest2 = (unsigned char *)(0x4000 + SDRAM_BASE);

			int i;
			loadromfile(0x2000,0x008000);
			if(*src == 0x2F)
			{
				for (i=0; i!=0x2000; ++i) dest2[i] = src[i];
				loadromfile(0x2000,0x006000);
				loadromfile(0x4000,0x00C000);
				loadromfile(0x2000,0x008000);
			}
			else
			{
				loadromfile(0x4000,0x004000);
				loadromfile(0x4000,0x00C000);
			}
	
			for (i=0; i!=0x2000; ++i) dest[i] = src[i];

			*(unsigned char *)(0x100000 + SDRAM_BASE) = 0;
		}
		break;
	case 16: // 16k one chip
		{
			loadromfile(0x4000,0x008000);
			unsigned char *src = (unsigned char *)(0x8000 + SDRAM_BASE);
			unsigned char *dest1 = (unsigned char *)(0x4000 + SDRAM_BASE);
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
			loadromfile(0x2000,0x004000);
			unsigned char *src = (unsigned char *)(0x4000 + SDRAM_BASE);
			unsigned char *dest1 = (unsigned char *)(0x6000 + SDRAM_BASE);
			unsigned char *dest2 = (unsigned char *)(0x8000 + SDRAM_BASE);
			unsigned char *dest3 = (unsigned char *)(0xa000 + SDRAM_BASE);
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
			loadromfile(0x1000,0x004000);
			unsigned char *src = (unsigned char *)(0x4000 + SDRAM_BASE);
			unsigned char *dest1 = (unsigned char *)(0x5000 + SDRAM_BASE);
			unsigned char *dest2 = (unsigned char *)(0x6000 + SDRAM_BASE);
			unsigned char *dest3 = (unsigned char *)(0x7000 + SDRAM_BASE);
			unsigned char *dest4 = (unsigned char *)(0x8000 + SDRAM_BASE);
			unsigned char *dest5 = (unsigned char *)(0x9000 + SDRAM_BASE);
			unsigned char *dest6 = (unsigned char *)(0xa000 + SDRAM_BASE);
			unsigned char *dest7 = (unsigned char *)(0xb000 + SDRAM_BASE);
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
	case 71: case 72: case 73: case 74:
		{
			int fsize = files[4].size & 0xFFFF0000;
			int i, j;
			loadromfile(fsize, 0x4000);
			unsigned char *src = (unsigned char *)(0x4000 + SDRAM_BASE);
			for(i=0; i != (0x80000 / fsize - 1); i++)
			{
				unsigned char *dest = (unsigned char *)(0x4000 + (i+1)*fsize + SDRAM_BASE);
				for(j=0; j != fsize; j++) dest[j] = src[j];
			}
			*(unsigned char *)(0x200000 + SDRAM_BASE) = 0;
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
	int size = files[4].size;

	if (size == 0x10000) type = 71;
	else if (size == 0x20000) type = 72;
	else if (size == 0x40000) type = 73;
	else if (size == 0x80000) type = 74;
	else if (size == 40960) type = 7;
	else if (size == 32768) type = 4;
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
	else if (size & 0x3FF) // has header
	{
		char header[16];
		int read = 0;
		file_read(&files[4],header,16,&read);
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
		reboot(0, 0);
	}
	else if (get_hotkey_coldboot())
	{
		reboot(1, 0);
	}
	
	if (last_mount != mounted)
	{
		last_mount = mounted;
		
		set_pause_6502(1);
		freeze();

		set_sd_data_mode_on();
		files[4].size = *zpu_in3;
		files[4].type = get_sd_filetype();
		files[4].is_readonly = get_sd_readonly();
		files[4].offset = 0;
		file_reset();

		select_cartridge();

		restore();
		reboot(1, 0);	
	}
}

void mainloop()
{
	memset32(SDRAM_BASE+0x4000, 0, 32768/4);

	reboot(1, 0);
	for (;;) actions();
}
