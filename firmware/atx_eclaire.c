#include "atx_eclaire.h"
#include "atx.h"
#include "regs.h"

struct SimpleFile * gAtxFile;
// u16 last_angle_returned; // extern so we can display it on the screen

extern unsigned char atari_sector_buffer[256];

void longbyteswap(u32 * x);
void byteswap(u16 * x);

void byteSwapAtxFileHeader(struct atxFileHeader * header)
{
    // only swap the used entries
    byteswap(&header->version);
    byteswap(&header->minVersion);
    longbyteswap(&header->startData);
}

void byteSwapAtxTrackHeader(struct atxTrackHeader * header)
{
    // only swap the used entries
    longbyteswap(&header->size); // used
    byteswap(&header->sectorCount); // used
    longbyteswap(&header->headerSize); // used
    longbyteswap(&header->flags); // used
}

void byteSwapAtxSectorListHeader(struct atxSectorListHeader * header)
{
	longbyteswap(&header->next);
}

void byteSwapAtxSectorHeader(struct atxSectorHeader * header)
{
	byteswap(&header->timev);
	longbyteswap(&header->data);
}

void byteSwapAtxTrackChunk(struct atxTrackChunk *header)
{
	byteswap(&header->data);
	longbyteswap(&header->size);
}


#if 0
void waitForAngularPosition(u16 pos)
{
    int where = getCurrentHeadPosition();
    int diff = pos-where;
    if (diff < 0)
    {
	    diff = 26042+diff;
    }

    *zpu_pause = diff<<3;

/*    // if the position is less than the current timer, we need to wait for a rollover 
    // to occur
    if (pos < TCNT1 / 2) {
        TIFR1 |= _BV(OCF1A);
        while (!(TIFR1 & _BV(OCF1A)));
    }
    // wait for the timer to reach the target position
    while (TCNT1 / 2 < pos);*/
}

u16 getCurrentHeadPosition() {
    // TCNT1 is a variable driven by an Atmel timer that ticks every 4 microseconds. A full 
    // rotation of the disk is represented in an ATX file by an angular positional value 
    // between 1-26042 (or 8 microseconds based on 288 rpms). So, TCNT1 / 2 always gives the 
    // current angular position of the drive head on the track any given time assuming the 
    // disk is spinning continously.
    //return TCNT1 / 2;
    int res = *zpu_timer2;
    res = (res >> 3)+1;
    return res;
}

#endif

int faccess_offset(int type, int offset, int bytes)
{
	int read = 0;

	// TODO This is probably not needed, at least not here!
	//*zpu_timer2_threshold = 208335;

	file_seek(gAtxFile,offset);
	file_read(gAtxFile,&atari_sector_buffer[0],bytes,&read);
	return bytes==read;
}

int rand()
{
	return *zpu_rand;
}


extern void byteswap(WORD * inw);

void longbyteswap(u32 * inl)
{
#ifndef LITTLE_ENDIAN
	unsigned char * in = (unsigned char *)inl;
	unsigned char temp0  = in[0];
	unsigned char temp1 = in[1];
	in[0] = in[3];
	in[1] = in[2];
	in[2] = temp1;
	in[3] = temp0;
#endif
}

