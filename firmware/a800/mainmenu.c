static const int main_ram_size=65536;
#include "main.h" //!!!
#include "atari_drive_emulator.h"
#include "log.h"
#include "utils.h"

unsigned char freezer_rom_present;

void loadosrom()
{
	if (file_size(files[5]) == 0x4000)
	{
		loadromfile(files[5],0x4000, ROM_OFS + 0x4000);
	}
	else if (file_size(files[5]) ==0x2800)
	{
		loadromfile(files[5],0x2800, ROM_OFS + 0x5800);
	}
}

void mainmenu()
{
	freezer_rom_present = 0;
	if (SimpleFile_OK == dir_init((void *)DIR_INIT_MEM, DIR_INIT_MEMSIZE))
	{
		init_drive_emulator();
		
		struct SimpleDirEntry * entries = dir_entries(ROM_DIR);
		
		//loadrom_indir(entries,"atarixl.rom",0x4000, (void *)0x704000);

		/*loadrom_indir(entries,"xlhias.rom",0x4000, (void *)0x708000);
		loadrom_indir(entries,"ultimon.rom",0x4000, (void *)0x70c000);
		loadrom_indir(entries,"osbhias.rom",0x4000, (void *)0x710000);
		loadrom_indir(entries,"osborig.rom",0x2800, (void *)0x715800);
		loadrom_indir(entries,"osaorig.rom",0x2800, (void *)0x719800);*/

		loadrom_indir(entries,"ataribas.rom",0x2000,ROM_OFS);
		if (SimpleFile_OK == file_open_name_in_dir(entries, "atarixl.rom", files[5]))
		{
			loadosrom();
		}
		else if (SimpleFile_OK == file_open_name_in_dir(entries, "atariosb.rom", files[5]))
		{
			loadosrom();
		}


#ifdef HAVE_FREEZER_ROM_MEM
		if (SimpleFile_OK == file_open_name_in_dir(entries, "freezer.rom", files[6]))
		{
			enum SimpleFileStatus ok;
			int len;
			ok = file_read(files[6], FREEZER_ROM_MEM, 0x10000, &len);
			if (ok == SimpleFile_OK && len == 0x10000) {
				LOG("freezer rom loaded\n");
				freezer_rom_present = 1;
			} else {
				LOG("loading freezer rom failed\n");
				freezer_rom_present = 0;
			}
		} else {
			LOG("freezer.rom not found\n");
		}
#endif
		set_freezer_enable(freezer_rom_present);

		//ROM = xlorig.rom,0x4000, (void *)0x704000
		//ROM = xlhias.rom,0x4000, (void *)0x708000
		//ROM = ultimon.rom,0x4000, (void *)0x70c000
		//ROM = osbhias.rom,0x4000, (void *)0x710000
		//ROM = osborig.rom,0x2800, (void *)0x715800
		//ROM = osaorig.rom,0x2800, (void *)0x719800
		//
		//ROM = ataribas.rom,0x2000,(void *)0x700000

		//--SDRAM_BASIC_ROM_ADDR <= "111"&"000000"   &"00000000000000";
		//--SDRAM_OS_ROM_ADDR    <= "111"&rom_select &"00000000000000";
		reboot(1);
		run_drive_emulator();
	}
	else
	{
		//printf("DIR init failed\n");
	}
	reboot(1);
	for (;;) actions(1);
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
		debug_pos = 200;
		debug_adjust = row==0 ? 128 : 0;
		{
			printf("Rom:%s", file_name(files[5]));
		}
		debug_pos = 280;
		int i;
		for (i=1;i!=5;++i)
		{
			int temp = debug_pos;
			debug_adjust = row==i+0 ? 128 : 0;
			char buffer[20];
			describe_disk(i-1,&buffer[0]);
			printf("Drive %d:%s %s", i, file_name(files[i-1]), &buffer[0]);
			debug_pos = temp+40;
		}

		debug_pos = 440;
		debug_adjust = row==5 ? 128 : 0;
		printf("Cart: %s", get_cart_select() ? file_name(files[4]) : "NONE");

		debug_pos = 640;
		debug_adjust = row==6 ? 128 : 0;
		printf("Exit");

		// Slow it down a bit
		wait_us(100000);

		// move
		while(get_hotkey_settings());
		joystick_wait(&joy,WAIT_QUIET);
		joystick_wait(&joy,WAIT_EITHER);
		if (joy.escape_) break;

		row+=joy.y_;

		if (row<0) row = 6;
		if (row>6) row = 0;

		switch (row)
		{
		case 0:
			if (joy.x_ || joy.fire_)
			{
				fil_type = fil_type_rom;
				filter = filter_specified;
				file_selector(files[5]);
				loadosrom();
			}
			break;
		case 1:
		case 2:
		case 3:
		case 4:
			if (joy.x_>0)
			{
				// Choose new disk
				filter = filter_disks;
				file_selector(files[row-1]);
				set_drive_status(row-1,files[row-1]);
			}
			else if(joy.x_<0)
			{
				// Remove disk
				file_init(files[row-1]);
				set_drive_status(row-1,0);
			}
			else if (joy.fire_)
			{
				{
					// Swap files
					struct SimpleFile * temp = files[row-1];
					files[row-1] = files[0];
					files[0] = temp;
				}

				{
					// Swap disks
					struct SimpleFile * temp = get_drive_status(row-1);
					set_drive_status(row-1, get_drive_status(0));
					set_drive_status(0,temp);
				}
			}
			break;
		case 5:
			if (joy.x_>0) {
				fil_type = fil_type_car;
				filter = filter_specified;
				file_selector(files[4]);
				unsigned char mode = load_car(files[4]);
				set_cart_select(mode);
				if (mode) {
					return 1;
				}
			}
			else if (joy.x_<0) {
				file_init(files[4]);
				set_cart_select(0);
			}
			break;
		case 6:
			if (joy.fire_)
			{
				done = 1;
			}
			break;
		}
	}

	return 0;
}

void memcpy(char *to, char *from, int len)
{
	while (len--) *to++ = *from++;
}

void actions()
{
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
		struct joystick_status joy;
		joy.x_ = joy.y_ = joy.fire_ = joy.escape_ = 0;

		set_pause_6502(1);
		set_freezer_enable(0);
		freeze();
		debug_pos = 0;	
		int do_reboot = settings();
		joystick_wait(&joy,WAIT_QUIET);
		while(get_hotkey_settings());
		debug_pos = -1;
		restore();
		if (do_reboot)
			reboot(1);
		else {
			set_freezer_enable(freezer_rom_present);
			set_pause_6502(0);
		}
	}
	else if (get_hotkey_fileselect())
	{
		set_pause_6502(1);
		set_freezer_enable(0);
		freeze();
		filter = filter_disks_and_carts;
		int res = 0;
		while(1)
		{
			res = file_selector(files[8]);
			if(!res) break;

			// +WIN for second disk select
			int win = get_mod_win();
			if(res)
			{
				if(compare_ext(files[8],fil_type_car))
				{
					file_init(files[0]);
					set_drive_status(0,0);
					file_init(files[1]);
					set_drive_status(1,0);

					//use copy to keep the folder
					*files[4] = *files[8];
					set_cart_select(load_car(files[4]));
					break;
				}
				else
				{
					int n = win ? 1 : 0;
					file_init(files[4]);
					set_cart_select(0);

					//use copy to keep the folder
					*files[n] = *files[8];
					set_drive_status(n,files[n]);
					if(!win) break;
				}
			}
		}

		while(get_hotkey_settings());

		//prevent triggering disk swap
		while(get_mod_win());

		debug_pos = -1;
		restore();
		if(res) reboot(1);
	}
	else if (get_mod_win() && (get_controls() == 0x10)) // disk swap WIN+Fire/Enter
	{
		struct SimpleFile * temp = files[0];
		files[0] = files[1];
		files[1] = temp;

		temp = get_drive_status(0);
		set_drive_status(0, get_drive_status(1));
		set_drive_status(1,temp);
		
		while(get_mod_win());
	}

	//pause as WIN is held down
	set_pause_6502(get_mod_win() ? 1 : 0);
}
