#include "freeze.h"

#include "regs.h"
#include "memory.h"

unsigned char store_portb;
unsigned volatile char *store_mem;
unsigned volatile char *custom_mirror;
unsigned volatile char *atari_base;

void freeze_init(void *memory)
{
	store_mem = (unsigned volatile char *)memory;

	custom_mirror = (unsigned volatile char *)atari_regmirror;
	atari_base = (unsigned volatile char *)atari_regbase;
}

void freeze()
{
	int i;
	// store custom chips
	//store_portb = *atari_portb;
	{
		//gtia
		for (i=0xc000; i!=0xc020; i++)
		{
			store_mem[i] = custom_mirror[i];
			atari_base[i] = 0;
		}
		//pokey1/2
		for (i=0xe800; i!=0xe810; i++)
		{
			store_mem[i] = custom_mirror[i];
			atari_base[i] = 0;
		}
		//antic
		for (i=0xd400; i!=0xd410; i++)
		{
			store_mem[i] = custom_mirror[i];
			atari_base[i] = 0;
		}
	}

	//*atari_portb = 0xff;

	// Copy 16k ram to sdram
	// Atari screen memory...
	for (i=0x0; i!=0x4000; ++i)
	{
		store_mem[i] = atari_base[i];
	}

	//Clear, except dl (first 0x40 bytes)
	clearscreen();

	// Put custom chips in a safe state
	// write a display list at 0600
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
	int j = 0;
	for (i=0x0600; j!=sizeof(dl); ++i,++j)
	{
		atari_base[i] = dl[j];
	}

	// point antic at my display list
	*atari_dlisth = 0x06;
	*atari_dlistl = 0x00;

	*atari_colbk = 0x00;
	*atari_colpf0 = 0x2f;
	*atari_colpf1 = 0x3f;
	*atari_colpf2 = 0x00;
	*atari_colpf3 = 0x1f;
	*atari_prior = 0x00;
	*atari_chbase = 0xf8;
	*atari_dmactl = 0x22;
	*atari_skctl = 0x2;
	*atari_chactl = 0x2;
	*atari_consol = 4;
	*atari_potgo = 0xff;
}

void restore()
{
	int i;

	// Restore memory
	for (i=0x0; i!=0x4000; ++i)
	{
		atari_base[i] = store_mem[i];
	}

	// Restore custom chips
	{
		//gtia
		for (i=0xc000; i!=0xc020; i++)
		{
			atari_base[i] = store_mem[i];
		}
		//pokey1/2
		for (i=0xe800; i!=0xe810; i++)
		{
			atari_base[i] = store_mem[i];
		}
		//antic
		for (i=0xd400; i!=0xd410; i++)
		{
			atari_base[i] = store_mem[i];
		}
	}

	//*atari_portb = store_portb;
}

