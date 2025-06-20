#include "freeze.h"

#include "regs.h"
#include "memory.h"

unsigned volatile char *store_mem;
unsigned volatile char *custom_mirror;
unsigned volatile char *atari_base;

// TODO - almost the same as 5200 one
// skctl, chbase and lack of portb to merge into one file...

void memset8(void *address, int value, int length);

// Moving this outside function removes gcc pulling in memcpy
unsigned char dl[] = {
	0x70,
	0x70,
	0x47,0x40,0x2c,
	0x70,
	0x42,0x68,0x2c,
	0x2,0x2,0x2,0x2,0x2,
	0x2,0x2,0x2,0x2,0x2,
	0x2,0x2,0x2,0x2,0x2,
	0x2,0x2,0x2,0x2,0x2,
	0x2,0x2,
	0x41,0x00,0x06
};

void freeze_init(void * memory)
{
	store_mem = (unsigned volatile char *)memory;

	custom_mirror = (unsigned volatile char *)atari_regmirror;
	atari_base = (unsigned volatile char *)atari_regbase;
}

void memcp8(char const volatile *from, char volatile *to, int offset, int len)
{
	from+=offset;
	to+=offset;
	while (len--) *to++ = *from++;
}

void freeze()
{
	int i;
	// store custom chips
	store_mem[0xd300] = *atari_portb;
	{
		//backup last value written to custom chip regs
		//gtia
		memcp8(custom_mirror,store_mem,0xd000,0x20);
		//pokey1/2
		memcp8(custom_mirror,store_mem,0xd200,0x20);
		//antic
		memcp8(custom_mirror,store_mem,0xd400,0x10);

		//PBI ram and rom control
		memcp8(custom_mirror,store_mem,0xd100,0x100);

		// Write 0 to custom chip regs
		memset8(atari_base+0xd000,0,0x20);
		memset8(atari_base+0xd200,0,0x20);
		memset8(atari_base+0xd400,0,0x10);
	}

	*atari_portb = 0xff;

	// Copy 64k ram to sdram
	// Atari screen memory...
	memcp8(atari_base,store_mem,0,0xd000);
	memcp8(atari_base,store_mem,0xd800,0x2800);

	//Clear, except dl (first 0x40 bytes)
	clearscreen();

	// Put custom chips in a safe state
	// write a display list at 0600
	memcp8(dl,atari_base+0x600,0,sizeof(dl));

	// point antic at my display list
	*atari_dlisth = 0x06;
	*atari_dlistl = 0x00;

	*atari_colbk = 0x00;
	*atari_colpf0 = 0x2f;
	*atari_colpf1 = 0x3f;
	*atari_colpf2 = 0x00;
	*atari_colpf3 = 0x1f;
	*atari_prior = 0x00;
	*atari_chbase = 0xe0;
	*atari_dmactl = 0x22;
	*atari_skctl = 0x3;
	*atari_chactl = 0x2;
}

void restore()
{
	// Restore memory
	memcp8(store_mem,atari_base,0,0xd000);
	memcp8(store_mem,atari_base,0xd800,0x2800);

	// Restore custom chips
	{
		// gtia
		memcp8(store_mem,atari_base,0xd000,0x20);
		// pokey
		memcp8(store_mem,atari_base,0xd200,0x20);
		// antic
		memcp8(store_mem,atari_base,0xd400,0x10);

		// PBI rom, order is important!
		atari_base[0xd1ff] = store_mem[0xd1ff];
		memcp8(store_mem,atari_base,0xd100,0xFF);
		
	}

	*atari_portb = store_mem[0xd300];
}

#if 0
void freeze_save(struct SimpleFile * file)
{
	if (file->size >= 65536 && !file->is_readonly)
	{
		int byteswritten = 0;
		file_write(file,(void *)store_mem,65536,&byteswritten);
		// file_write_flush();
	}
}
void freeze_load(struct SimpleFile * file)
{
	if (file->size >= 65536)
	{
		int bytesread = 0;
		file_read(file,(void *)store_mem,65536,&bytesread);
	}
}
#endif