static const int main_ram_size=16384;
#include "main.h" //!!!

unsigned char freezer_rom_present = 0;

void actions();

#ifdef USB
#include "usb.h"
#endif

void loadosrom()
{
	int j=0;
	if (file_size(files[5]) == 0x0800)
	{
		int i=0;
		unsigned char * src = (unsigned char *)(ROM_OFS + 0x4000 + SDRAM_BASE);
		unsigned char * dest1 = (unsigned char *)(ROM_OFS + 0x4800 + SDRAM_BASE);
		loadromfile(files[5],0x0800, ROM_OFS + 0x4000);

		for (i=0; i!=0x800; ++i)
		{
			dest1[i] = src[i];
		}
	}
}

#ifdef USB
struct usb_host usb_porta;
#endif
#ifdef USB2
struct usb_host usb_portb;
#endif

void mainmenu()
{
#ifdef USB
	usb_init(&usb_porta,0);
#endif
#ifdef USB2
	usb_init(&usb_portb,1);
#endif
	memset8(SRAM_BASE+0x4000, 0, 32768);
	memset32(SDRAM_BASE+0x4000, 0, 32768/4);

	if (SimpleFile_OK == dir_init((void *)DIR_INIT_MEM, DIR_INIT_MEMSIZE))
	{
		#ifdef USB
			usb_log_init(files[7]);
		#endif
		struct SimpleDirEntry * entries = dir_entries(ROM_DIR);

		if (SimpleFile_OK == file_open_name_in_dir(entries, "5200.rom", files[5]))
		{
			loadosrom();
		}
	}
	else
	{
		//printf("DIR init failed\n");
	}
	reboot(1);
	for (;;) actions();
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

int filter_5200(struct SimpleDirEntry * entry)
{
	if (dir_is_subdir(entry)) return 1;
	char const * f = dir_filename(entry);
	int res = (compare_ext(f,"A52") || compare_ext(f,"CAR") || compare_ext(f,"BIN"));
	//printf("filter_disks:%s:%d\n",f,res);
	return res;
}

int select_cartridge()
{
	filter = filter_5200; // .a52, .car and .bin
	if(!file_selector(files[4])) return 0;

	// work out the type
	char const * name = file_name(files[4]);
	int type = -1;
	if (compare_ext(name,"CAR"))
	{
		char header[16];
		int read = 0;
		file_read(files[4],&header,16,&read);
		type = header[7];
	}
	else
	{
		int size = file_size(files[4]);

		if (size == 32768) type = 4;
		if (size == 16384) // uff!
		{
			struct joystick_status joy;
			joy.x_ = joy.y_ = joy.fire_ = joy.escape_ = 0;

			clearscreen();
			debug_pos = 0;
			debug_adjust = 0;
			printf("16k cart type");
			debug_pos = 80;
			printf("Left for one chip");
			debug_pos = 120;
			printf("Right for two chip");

			while(type <0)
			{
				joystick_wait(&joy,WAIT_QUIET);
				joystick_wait(&joy,WAIT_EITHER);

				if (joy.x_<0) type = 16;
				if (joy.x_>0) type = 6;
			}
		}
		
		if (size == 8192) type = 19;
		if (size == 4096) type = 20;
	}

	load_cartridge(type);
	return 1;
}

int settings()
{
	struct joystick_status joy;
	joy.x_ = joy.y_ = joy.fire_ = joy.escape_ = 0;

	int row = 0;

	int done = 0;
	for (;!done;)
	{
		// Render
		clearscreen();
		debug_pos = 0;
		debug_adjust = 0;
		printf("Se");
		debug_adjust = 128;
		printf("ttings");
		debug_pos = 80;
		debug_adjust = row==0 ? 128 : 0;
		printf("Turbo:%dx", get_turbo_6502());
		debug_pos = 120;
		debug_adjust = row==1 ? 128 : 0;
		{
			printf("Rom:%s", file_name(files[5]));
		}
		int i;

		debug_pos = 160;
		debug_adjust = row==2 ? 128 : 0;
		printf("Cart:%s", file_name(files[4]) ? file_name(files[4]) : "NONE");

#ifdef USBSETTINGS
		debug_pos = 240;
		debug_adjust = row==3 ? 128 : 0;
		printf("Rotate USB joysticks");

		debug_pos = 320;
		debug_adjust = row==4 ? 128 : 0;
		printf("Exit");

		debug_adjust = 0;

		usb_devices(400);
#else
		debug_pos = 240;
		debug_adjust = row==3 ? 128 : 0;
		printf("Aspect Ratio: %s", get_ratio() ? "4:3" : "16:9");
		debug_pos = 320;
		debug_adjust = row==4 ? 128 : 0;
		printf("Exit");
#endif

/*
while (1)
{
	*atari_consol = 4;
	*atari_potgo = 0xff;

	wait_us(1000000/25);

	unsigned char pot0 = *atari_pot0;
	unsigned char pot1 = *atari_pot1;
		debug_pos = 320;
		printf("                         ");
		debug_pos = 320;
		printf("pot0:%d pot1:%d",pot0,pot1);
}*/

		// Slow it down a bit
		wait_us(100000);

		// move
		joystick_wait(&joy,WAIT_QUIET);
		joystick_wait(&joy,WAIT_EITHER);
		if (joy.escape_) break;

		row+=joy.y_;
		if (row<0) row = 4;
		if (row>4) row = 0;

		switch (row)
		{
		case 0:
			{
				int turbo = get_turbo_6502();
				if (joy.x_==1) turbo<<=1;
				if (joy.x_==-1) turbo>>=1;
				if (turbo>16) turbo = 16;
				if (turbo<1) turbo = 1;
				set_turbo_6502(turbo);
			}
			break;
		case 1:
			{
				if (joy.x_ || joy.fire_)
				{
					fil_type = fil_type_rom;
					filter = filter_specified;
					file_selector(files[5]);
					loadosrom();
				}
			}
			break;
		case 2:
			{
				if (joy.x_ || joy.fire_)
				{
					return select_cartridge();
				}
			}
			break;
#ifdef USBSETTINGS
		case 3:
			if (joy.fire_)
			{
				rotate_usb_sticks();
			}
			break;
#else
		case 3:
			if (joy.x_)
			{
				set_ratio(get_ratio()^1);
			}
			break;
#endif
		case 4:
			if (joy.fire_)
			{
				done = 1;
			}
			break;
		}
	}

	return 0;
}

void actions()
{
	struct joystick_status joy;
	joy.x_ = joy.y_ = joy.fire_ = joy.escape_ = 0;

#ifdef LINUX_BUILD
	check_keys();
#endif
#ifdef USB
	usb_poll(&usb_porta);
#endif
#ifdef USB2
	usb_poll(&usb_portb);
#endif
	// Show some activity!
	//*atari_colbk = *atari_random;
	
	// Hot keys
	if (get_hotkey_softboot())
	{
		reboot(0);	
	}
	else if (get_hotkey_coldboot())
	{
		reboot(1);	
	}
	else if (get_hotkey_settings())
	{
		set_pause_6502(1);
		freeze();
		debug_pos = 0;	
		int do_reboot = settings();
		joystick_wait(&joy,WAIT_QUIET); 
		debug_pos = -1;
		restore();
		if (do_reboot)
			reboot(1);
		else
			set_pause_6502(0);
	}
	else if (get_hotkey_fileselect())
	{
		set_pause_6502(1);
		freeze();
		int res = select_cartridge();
		joystick_wait(&joy,WAIT_QUIET); 
		restore();
		if(res) reboot(1);
	}
}
