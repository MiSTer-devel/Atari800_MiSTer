#include <alloca.h>
#include <sys/types.h>
#include "integer.h"
#include "regs.h"
#include "pause.h"
#include "memory.h"
#include "file.h"
#include "printf.h"
#include "joystick.h" 
#include "freeze.h"

void mainloop();

// FUNCTIONS in here
//   cold reset atari (clears base ram...)
//   start atari (begins paused)
//   freeze/resume atari - NOT USED EVERYWHERE!
//   pause - TODO - base this on pokey clock...

// standard ZPU IN/OUT use...
// OUT1 - 6502 settings (pause,reset,speed)
// pause_n: bit 0 
// reset_n: bit 1
// turbo: bit 2-4: meaning... 0=1.79Mhz,1=3.58MHz,2=7.16MHz,3=14.32MHz,4=28.64MHz,5=57.28MHz,etc.
// ram_select: bit 5-7: 
//   		RAM_SELECT : in std_logic_vector(2 downto 0); -- 64K,128K,320KB Compy, 320KB Rambo, 576K Compy, 576K Rambo, 1088K, 4MB

#define BIT_REG(op,mask,shift,name,reg) \
int get_ ## name() \
{ \
	int val = *reg; \
	return op((val>>shift)&mask); \
} \
void set_ ## name(int param) \
{ \
	int val = *reg; \
	 \
	val = (val&~(mask<<shift)); \
	val |= op(param)<<shift; \
	 \
	*reg = val; \
}

#define BIT_REG_RO(op,mask,shift,name,reg) \
int get_ ## name() \
{ \
	int val = *reg; \
	return op((val>>shift)&mask); \
}

BIT_REG(,0x1,0,pause_6502,zpu_out1)
BIT_REG(,0x1,1,reset_6502,zpu_out1)
BIT_REG(,0x3f,2,turbo_6502,zpu_out1)
BIT_REG(,0x7,8,ram_select,zpu_out1)
//BIT_REG(,0x3f,11,rom_select,zpu_out1)
BIT_REG(,0x3f,17,cart_select,zpu_out1)
// reserve 2 bits for extending cart_select
BIT_REG(,0x01,25,freezer_enable,zpu_out1)

BIT_REG_RO(,0x1,0,hotkey_f1,zpu_in1)
BIT_REG_RO(,0x1,1,hotkey_f2,zpu_in1)
BIT_REG_RO(,0x1,2,hotkey_f3,zpu_in1)
BIT_REG_RO(,0x1,3,hotkey_f4,zpu_in1)
BIT_REG_RO(,0x1,4,hotkey_f5,zpu_in1)
BIT_REG_RO(,0x1,5,hotkey_f6,zpu_in1)
BIT_REG_RO(,0x1,6,hotkey_f7,zpu_in1)
BIT_REG_RO(,0x1,7,hotkey_f8,zpu_in1)
BIT_REG_RO(,0x1,8,hotkey_softboot,zpu_in1)
BIT_REG_RO(,0x1,9,hotkey_coldboot,zpu_in1)
BIT_REG_RO(,0x1,10,hotkey_fileselect,zpu_in1)
BIT_REG_RO(,0x1,11,hotkey_settings,zpu_in1)
BIT_REG_RO(,0x1,18,mod_win,zpu_in1)

BIT_REG_RO(,0x3f,12,controls,zpu_in1) // (esc)FLRDU

BIT_REG_RO(,0x7,0,speeddrv,zpu_in2)

// file i/o registers
BIT_REG_RO(,0x1,8,sd_done,zpu_in2)
BIT_REG_RO(,0x1,9,sd_mounted,zpu_in2)
BIT_REG_RO(,0x7,10,sd_fileno,zpu_in2)
BIT_REG_RO(,0x3,13,sd_filetype,zpu_in2)
BIT_REG_RO(,0x1,15,sd_readonly,zpu_in2)

BIT_REG(,0x1,0,sd_data_mode,zpu_out2) //0 - write/read the buffer, 1 - write LBA
BIT_REG(,0x1,1,sd_read,zpu_out2)
BIT_REG(,0x1,2,sd_write,zpu_out2)
BIT_REG(,0x7,3,sd_num,zpu_out2)

// zpu_in3 - read the buffer;
// zpu_out3 - write to buffer;


void
wait_us(int unsigned num)
{
	// pause counter runs at pokey frequency - should be 1.79MHz
	int unsigned cycles = (num*230)>>7;
	*zpu_pause = cycles;
}

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

void char_out (void* p, char c)
{
	unsigned char val = toatarichar(c);
	if (debug_pos>=0)
	{
		*(baseaddr+debug_pos) = val|debug_adjust;
		++debug_pos;
	}
}

void memset8(void *address, int value, int length)
{
	char *mem = address;
	while (length--) *mem++=value;
}

void memset32(void *address, int value, int length)
{
	int *mem = address;
	while (length--) *mem++=value;
}

void clear_main_ram()
{
	memset8(SRAM_BASE, 0, main_ram_size); // SRAM, if present (TODO)
	memset32(SDRAM_BASE, 0, main_ram_size/4);
}

void
reboot(int cold)
{
	set_pause_6502(1);
	if (cold)
	{
		set_freezer_enable(0);
		clear_main_ram();
	}
	set_reset_6502(1);
	// Do nothing in here - this resets the memory controller!
	set_reset_6502(0);
	set_pause_6502(0);
}

#define NUM_FILES 8
struct SimpleFile files[NUM_FILES];

int last_mount;

int main(void)
{
	INIT_MEM

	int i;
	for (i=0; i!=NUM_FILES; ++i) file_init(&files[i], i);
	file_reset();
	
	set_pause_6502(1);
	set_reset_6502(1);
	set_reset_6502(0);
	if(!get_turbo_6502())
	{
		set_turbo_6502(1);
		set_ram_select(2);
	}
	set_cart_select(0);
	set_freezer_enable(0);

	freeze_init((void*)FREEZE_MEM); // 128k

	debug_pos = -1;
	debug_adjust = 0;
	baseaddr = (unsigned char volatile *)(screen_address + atari_regbase);
	init_printf(0, char_out);

	last_mount = 0;
	mainloop();
	return 0;
}
