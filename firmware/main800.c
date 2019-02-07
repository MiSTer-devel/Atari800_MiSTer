static const int main_ram_size=65536;

#include "main.h" //!!!
#include "atari_drive_emulator.h"

int last_mount;

void mainmenu()
{
	init_drive_emulator();
	last_mount = get_sd_mounted();
	file_reset();

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
		struct SimpleFile *file = files[num];
		file->size = *zpu_in3;
		file->type = get_sd_filetype();
		file->is_readonly = get_sd_readonly();
		file->offset = 0;
		file_reset();

		if(num<4)
		{
			set_cart_select(0);
			set_drive_status(num,file->size ? file : 0);
		}
		else
		{
			set_pause_6502(1);

			set_drive_status(0,0);
			set_drive_status(1,0);
			set_drive_status(3,0);
			set_drive_status(4,0);
			set_cart_select(file->size ? load_car(file) : 0);

			reboot(1);
		}
	}

	//pause as WIN is held down
	set_pause_6502(get_mod_win() ? 1 : 0);
}
