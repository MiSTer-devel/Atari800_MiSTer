#include "simplefile.h"
#include "simpledir.h"
#include "joystick.h"
#include "regs.h" // NO NEED!!! 
#include "printf.h"
#include "fileutils.h"

extern int debug_pos; // ARG!
extern int debug_adjust; // ARG!
extern char USER_DIR[];

// TODO!
#define MAX_PATH_LENGTH (9*5 + 8+3+1 + 1) 

int (* filter)(struct SimpleDirEntry * entry);

int filter_disks(struct SimpleDirEntry * entry)
{
	if (dir_is_subdir(entry)) return 1;
	char const * f = dir_filename(entry);
	int res = (compare_ext(f,"ATR") || compare_ext(f,"XFD") || compare_ext(f,"XEX"));
	//printf("filter_disks:%s:%d\n",f,res);
	return res;
}

char const * fil_type;
char const * fil_type_rom;
char const * fil_type_bin;
char const * fil_type_car;
char const * fil_type_mem;

int filter_disks_and_carts(struct SimpleDirEntry * entry)
{
	if (dir_is_subdir(entry)) return 1;
	char const * f = dir_filename(entry);
	int res = (compare_ext(f,"ATR") || compare_ext(f,"XFD") || compare_ext(f,"XEX") || compare_ext(f,fil_type_car));
	return res;
}

int filter_specified(struct SimpleDirEntry * entry)
{
	if (dir_is_subdir(entry)) return 1;
	char const * f = dir_filename(entry);
	return (compare_ext(f,fil_type));
}

void dir_of(char * dir, char const * path); // TODO - into simpledir

int file_selector(struct SimpleFile * file)
{
	char dir[MAX_PATH_LENGTH];
	if (file_name(file)[0] == '\0')
	{
		strcpy(&dir[0],USER_DIR);
	}
	else
	{
		dir_of(&dir[0],file_path(file));
	}

	struct joystick_status joy;
	joy.x_ = joy.y_ = joy.fire_ = joy.escape_ = 0;
	for (;!joy.escape_;)
	{
		struct SimpleDirEntry * entry = dir_entries_filtered(dir,filter);

		// Count how many we have
		int entries = 0;
		struct SimpleDirEntry * temp_entry = entry;
		while (temp_entry)
		{
			++entries;
			temp_entry = dir_next(temp_entry);
		}
		//printf("Entries:%d\n",entries);

		// Selected item
		int pos = 0;
		int prevstartpos = -1;

		for (;;)
		{
			if (pos<0) pos = 0;
			if (pos>=entries) pos = entries-1;

			// render
			{
				// find which chunk to render
				int startpos = pos-10;
				//printf("\nA pos:%d, startpos:%d\n",pos,startpos);
				//startpos &= 0xfffffffe;
				//printf("startpos:%d\n",startpos);
				if (startpos<0) startpos=0;
				//printf("pos:%d, startpos:%d\n",pos,startpos);

				// get the dir entries for these
				struct SimpleDirEntry * render_entry = entry;
				int skip = startpos;
				while (skip-->0)
				{
					render_entry =  dir_next(render_entry);
				}

				// clear the screen
				if (startpos!=prevstartpos)
				{
					clearscreen();
					prevstartpos = startpos;
				}

				// find selected entry
				struct SimpleDirEntry * sel_entry = entry;
				skip = pos;
				while (skip-->0)
				{
					sel_entry =  dir_next(sel_entry);
				}

				// output the new entries
				int line;
				debug_pos = 0;
				debug_adjust = 0;
				printf("Choose ");
				debug_adjust = 128;
				printf("file");
				debug_pos = 40;
				int end = 22*40;
				for (;;)
				{
					if (!render_entry) break;
					
					int prev_debug_pos = debug_pos;
					if (render_entry == sel_entry)
					{
						debug_adjust = 128;
					}
					else
					{
						debug_adjust = 0;
					}
					if (dir_is_subdir(render_entry))
					{
						printf("DIR:");
					}
					printf("%s",dir_filename(render_entry));

					render_entry = dir_next(render_entry);

					while(prev_debug_pos<debug_pos)
					{
						prev_debug_pos+=40;
					}
					debug_pos = prev_debug_pos;
					//printf("debug_pos:%d",debug_pos);
					if (debug_pos>=end) break;
				}

				debug_pos = 40*23;
				if (sel_entry)
				{
					//printf("%s %s %d %d %d",dir_is_subdir(sel_entry) ? "DIR":"", dir_filename(sel_entry), joy.x_, joy.y_, pos);
					printf("%s %s",dir_is_subdir(sel_entry) ? "DIR":"", dir_filename(sel_entry));
				}
				int i;
				for (i=0;i!=40;++i) printf(" ");
			}

			// Slow it down a bit
			wait_us(100000);

			// move
			joystick_wait(&joy,WAIT_QUIET);
			joystick_wait(&joy,WAIT_EITHER);
			if (joy.escape_) break;
			
			if (joy.fire_)
			{
				int i = pos;
				while(i--)
				{
					if (!entry) break;
					entry = dir_next(entry);
				}

				if (entry)
				{
					if (!dir_is_subdir(entry))
					{
						file_open_dir(entry, file);
						return 1;
					}
					else
					{
						char const *f = dir_filename(entry);
						if (strcmp("..",f)==0)
						{
							int x = strlen(dir);
							while (x-->0)
							{
								if (dir[x] == '/')
								{
									dir[x] = '\0';
									break;
								}
							}
							//printf("\nDIR UP! %s\n",dir);
						}
						else
						{
							//strcpy(dir + strlen(dir),"/");
							//strcpy(dir + strlen(dir),f);
							//printf("\nDIR DOWN:%s -> %s\n",f,dir);
							strcpy(dir,dir_path(entry));
						}
					}
					break;
				}

				return 1;
			}
			
			pos += joy.x_*10;
			pos += joy.y_;
		}
	}

	joystick_wait(&joy,WAIT_QUIET);
	return 0;
}

