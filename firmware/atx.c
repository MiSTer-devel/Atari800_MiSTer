/*! \file atx.c \brief ATX file handling. */
//*****************************************************************************
//
// File Name	: 'atx.c'
// Title		: ATX file handling
// Author		: Daniel Noguerol
// Date			: 21/01/2018
// Revised		: 21/01/2018
// Version		: 0.1
// Target MCU	: ???
// Editor Tabs	: 4
//
// NOTE: This code is currently below version 1.0, and therefore is considered
// to be lacking in some functionality or documentation, or may not be fully
// tested.  Nonetheless, you can expect most functions to work.
//
// This code is distributed under the GNU Public License
//		which can be found at http://www.gnu.org/licenses/gpl.txt
//
//*****************************************************************************

#include "atx_eclaire.h"
#include "atx.h"
#include "regs.h"
#include "pause.h"

#define get_atx1050() (*zpu_in2 & 0x00000020)

// number of angular units in a full disk rotation
#define AU_FULL_ROTATION         26042

#define US_CS_CALC_1050 270 // According to Altirra
#define US_CS_CALC_810 5136 // According to Altirra

#define US_TRACK_STEP_810 5300 // number of microseconds drive takes to step 1 track
#define US_TRACK_STEP_1050 20120 // According to Avery / Altirra
#define US_HEAD_SETTLE_1050 20000
#define US_HEAD_SETTLE_810 10000

#define US_3FAKE_ROT_810 1566000
#define US_2FAKE_ROT_1050 942000

// mask for checking FDC status "data lost" bit
#define MASK_FDC_DLOST           0x04
// mask for checking FDC status "missing" bit
#define MASK_FDC_MISSING         0x10
// mask for checking FDC status extended data bit
#define MASK_EXTENDED_DATA       0x40

#define MASK_FDC_BUSY            0x01
#define MASK_FDC_DRQ             0x02
#define MASK_FDC_CRC             0x08
#define MASK_FDC_REC             0x20
#define MASK_FDC_WP              0x40
#define MASK_RESERVED            0x80

#define MAX_RETRIES_1050         2
#define MAX_RETRIES_810          4

#define MAX_TRACK                42

enum atx_density { atx_single, atx_medium, atx_double };

extern unsigned char atari_sector_buffer[256];

struct {
	u16 bytesPerSector; // number of bytes per sector
	u08 sectorsPerTrack; // number of sectors in each track
	u32 trackOffset[MAX_TRACK]; // pre-calculated info for each track and drive
	u08 currentHeadTrack;
	u08 density;
} atx_info[NUM_ATX_DRIVES];

struct {
	u32 stamp;
	u16 angle;
} headPosition;

static void getCurrentHeadPosition()
{
	u32 s = *zpu_timer;
	headPosition.stamp = s;
	headPosition.angle = (u16)((s >> 3) % AU_FULL_ROTATION);
}

static void wait_from_stamp(u32 us_delay)
{
	u32 t = *zpu_timer - headPosition.stamp;
	t = us_delay - t;
	// If, for whatever reason, we are already too late, just skip
	if(t <= us_delay)
	{
		wait_us(t);
	}
}

u08 loadAtxFile(u08 drive)
{
	struct atxFileHeader *fileHeader;
	struct atxTrackHeader *trackHeader;
	u08 r = 0;

	// read the file header
	if(!faccess_offset(FILE_ACCESS_READ, 0, sizeof(struct atxFileHeader)))
	{
		return r;
	}
	byteSwapAtxFileHeader((struct atxFileHeader *) atari_sector_buffer);

	// validate the ATX file header
	fileHeader = (struct atxFileHeader *) atari_sector_buffer;
	if (fileHeader->signature[0] != 'A' ||
		fileHeader->signature[1] != 'T' ||
		fileHeader->signature[2] != '8' ||
		fileHeader->signature[3] != 'X' ||
		fileHeader->version != ATX_VERSION ||
		fileHeader->minVersion != ATX_VERSION)
	{
		return r;
	}
	r = fileHeader->density;
	// enhanced density is 26 sectors per track, single and double density are 18
	atx_info[drive].sectorsPerTrack = (r == atx_medium) ? (u08) 26 : (u08) 18;
	// single and enhanced density are 128 bytes per sector, double density is 256
	atx_info[drive].bytesPerSector = (r == atx_double) ? (u16) 256 : (u16) 128;
	atx_info[drive].density = r;
	atx_info[drive].currentHeadTrack = 0;

	// calculate track offsets
	u32 startOffset = fileHeader->startData;
	int track;
	for(track = 0; track < MAX_TRACK ; track++) {
		if (!faccess_offset(FILE_ACCESS_READ, startOffset, sizeof(struct atxTrackHeader)))
		{
			break;
		}
		trackHeader = (struct atxTrackHeader *) atari_sector_buffer;
		byteSwapAtxTrackHeader(trackHeader);
		atx_info[drive].trackOffset[track] = startOffset;
		startOffset += trackHeader->size;
	}

	return r;
}

// Return 0 on full success, 1 on "Atari disk problem" (may have data)
// -1 on internal storage problem (corrupt ATX) 
int loadAtxSector(u08 drive, u16 num, u08 *status)
{

	struct atxTrackHeader *trackHeader;
	struct atxSectorListHeader *slHeader;
	struct atxSectorHeader *sectorHeader;
	struct atxTrackChunk *extSectorData;

	u16 i;
	int r = 1;
	u08 is1050 = get_atx1050();

	// calculate track and relative sector number from the absolute sector number
	u08 tgtTrackNumber = (num - 1) / atx_info[drive].sectorsPerTrack;
	u08 tgtSectorNumber = (num - 1) % atx_info[drive].sectorsPerTrack + 1;

	// set initial status (in case the target sector is not found)
	*status = MASK_FDC_MISSING;

	u16 atxSectorSize = atx_info[drive].bytesPerSector;

	// delay for track stepping if needed
	int diff = tgtTrackNumber - atx_info[drive].currentHeadTrack;
	if (diff)
	{
		if (diff > 0)
		{
			diff += (is1050 ? 1 : 0);
		}
		else
		{
			diff = -diff;
		}
		wait_us(is1050 ? (diff*US_TRACK_STEP_1050 + US_HEAD_SETTLE_1050) : (diff*US_TRACK_STEP_810 + US_HEAD_SETTLE_810));
	}

	getCurrentHeadPosition();

	// set new head track position
	atx_info[drive].currentHeadTrack = tgtTrackNumber;
	u16 sectorCount = 0;
	// read the track header
	u32 currentFileOffset = atx_info[drive].trackOffset[tgtTrackNumber];
	
	if (currentFileOffset)
	{
		if(faccess_offset(FILE_ACCESS_READ, currentFileOffset, sizeof(struct atxTrackHeader)))
		{
			trackHeader = (struct atxTrackHeader *) atari_sector_buffer;
			byteSwapAtxTrackHeader(trackHeader);
			sectorCount = trackHeader->sectorCount;	    
		}
		else
		{
			r = -1;
		}
	}

	if (trackHeader->trackNumber != tgtTrackNumber || atx_info[drive].density != ((trackHeader->flags & 0x2) ? atx_medium : atx_single))
	{
		sectorCount = 0;
	}

	u32 trackHeaderSize = trackHeader->headerSize;

	if (sectorCount)
	{
		currentFileOffset += trackHeaderSize;
		if(faccess_offset(FILE_ACCESS_READ, currentFileOffset, sizeof(struct atxSectorListHeader)))
		{
			slHeader = (struct atxSectorListHeader *) atari_sector_buffer;
			byteSwapAtxSectorListHeader(slHeader);
			// sector list header is variable length, so skip any extra header bytes that may be present
			currentFileOffset += slHeader->next - sectorCount * sizeof(struct atxSectorHeader);
		}
		else
		{
			sectorCount = 0;
			r = -1;
		}
	}

	u32 tgtSectorOffset;        // the offset of the target sector data
	int16_t weakOffset;

	u08 retries = is1050 ? MAX_RETRIES_1050 : MAX_RETRIES_810;

	u32 retryOffset = currentFileOffset;
	u16 extSectorSize;

	while (retries > 0)
	{
		retries--;
		currentFileOffset = retryOffset;
		int pTT;
		u16 tgtSectorIndex = 0;         // the index of the target sector within the sector list
		tgtSectorOffset = 0;
		weakOffset = -1;
		// iterate through all sector headers to find the target sector

		if(sectorCount)
		{
			for (i=0; i < sectorCount; i++)
			{
				if(!faccess_offset(FILE_ACCESS_READ, currentFileOffset, sizeof(struct atxSectorHeader)))
				{
					r = -1;
					break;
				}
				sectorHeader = (struct atxSectorHeader *)atari_sector_buffer;
				byteSwapAtxSectorHeader(sectorHeader);

				// if the sector is not flagged as missing and its number matches the one we're looking for...
				if (sectorHeader->number == tgtSectorNumber)
				{
					if(sectorHeader->status & MASK_FDC_MISSING)
					{
						currentFileOffset += sizeof(struct atxSectorHeader);
						continue;
					}
					// check if it's the next sector that the head would encounter angularly...
					int tt = sectorHeader->timev - headPosition.angle;
					if (!tgtSectorOffset || (tt > 0 && pTT <= 0) || (tt > 0 && pTT > 0 && tt < pTT) || (tt <= 0 && pTT <= 0 && tt < pTT))
					{
						pTT = tt;
						*status = sectorHeader->status;
						tgtSectorIndex = i;
						tgtSectorOffset = sectorHeader->data;
					}
				}
				currentFileOffset += sizeof(struct atxSectorHeader);
			}
		}
	
		u16 actSectorSize = atxSectorSize;
		extSectorSize = 0;
		// if an extended data record exists for this track, iterate through all track chunks to search
		// for those records (note that we stop looking for chunks when we hit the 8-byte terminator; length == 0)
		if (*status & MASK_EXTENDED_DATA)
		{
			currentFileOffset = atx_info[drive].trackOffset[tgtTrackNumber] + trackHeaderSize;
			do {
				if(!faccess_offset(FILE_ACCESS_READ, currentFileOffset, sizeof(struct atxTrackChunk)))
				{
					r = -1;
					break;
				}
				extSectorData = (struct atxTrackChunk *) atari_sector_buffer;
				byteSwapAtxTrackChunk(extSectorData);
				if (extSectorData->size)
				{
					// if the target sector has a weak data flag, grab the start weak offset within the sector data
					if (extSectorData->sectorIndex == tgtSectorIndex)
					{
						if(extSectorData->type == 0x10)
						{ // weak sector
							weakOffset = extSectorData->data;
						}
						else if(extSectorData->type == 0x11)
						{ // extended sector
							extSectorSize = 128 << extSectorData->data;
							// 1050 waits for long sectors, 810 does not
							if(is1050 ? (extSectorSize > actSectorSize) : (extSectorSize < actSectorSize))
							{
								actSectorSize = extSectorSize;
							}
						}
					}
					currentFileOffset += extSectorData->size;
				}
			} while (extSectorData->size);
		}

		if (tgtSectorOffset)
		{
			if(!faccess_offset(FILE_ACCESS_READ, atx_info[drive].trackOffset[tgtTrackNumber] + tgtSectorOffset, atxSectorSize))
			{
				r = -1;
				tgtSectorOffset = 0;
			}

			u16 au_one_sector_read = (23+actSectorSize)*(atx_info[drive].density == atx_single ? 8 : 4)+2;
			// We will need to circulate around the disk one more time if we are re-reading the just written sector	    
			wait_from_stamp((au_one_sector_read + pTT + (pTT > 0 ? 0 : AU_FULL_ROTATION))*8);

			if(*status)
			{		    
				// This is according to Altirra, but it breaks DjayBee's test J in 1050 mode?!
				// wait_us(is1050 ? (US_TRACK_STEP_1050+US_HEAD_SETTLE_1050) : (AU_FULL_ROTATION*8));
				// This is what seems to work:
				wait_us(AU_FULL_ROTATION*8);
			}
		}
		else
		{
			// No matching sector found at all or the track does not match the disk density
			wait_from_stamp(is1050 ? US_2FAKE_ROT_1050 : US_3FAKE_ROT_810);
			if(is1050 || retries == 2)
			{
				// Repositioning the head for the target track
				if(!is1050)
				{
					wait_us((43+tgtTrackNumber)*US_TRACK_STEP_810+US_HEAD_SETTLE_810);
				}
				else if(tgtTrackNumber)
				{
					wait_us((2*tgtTrackNumber+1)*US_TRACK_STEP_1050+US_HEAD_SETTLE_1050);
				}
			}
		}
	
		getCurrentHeadPosition();

		if(!*status || r < 0)
		{
			break;
		}	
	}

	*status &= ~(MASK_RESERVED | MASK_EXTENDED_DATA);

	if (*status & MASK_FDC_DLOST)
	{
		if(is1050)
		{
			*status |= MASK_FDC_DRQ;
		}
		else
		{
			*status &= ~(MASK_FDC_DLOST | MASK_FDC_CRC);
			*status |= MASK_FDC_BUSY;
		}
	}
	if(!is1050 && (*status & MASK_FDC_REC))
	{
		*status |= MASK_FDC_WP;
	}

	if (tgtSectorOffset && !*status && r >= 0)
	{
		r = 0;
	}

	// if a weak offset is defined, randomize the appropriate data
	if (weakOffset > -1)
	{
		for (i = (u16) weakOffset; i < atxSectorSize; i++)
		{
			atari_sector_buffer[i] = (u08) (rand() & 0xFF);
		}
	}

	wait_from_stamp(is1050 ? US_CS_CALC_1050 : US_CS_CALC_810);
	// There is no file reading since last time stamp, so the alternative
	// below is probably equally good
	//wait_us(is1050 ? US_CS_CALC_1050 : US_CS_CALC_810);

	// the Atari expects an inverted FDC status byte
	*status = ~(*status);

	// return the number of bytes read
	return r;
}

/*
u16 incAngularDisplacement(u16 start, u16 delta) {
    // increment an angular position by a delta taking a full rotation into consideration
    u16 ret = start + delta;
    if (ret > AU_FULL_ROTATION) {
        ret -= AU_FULL_ROTATION;
    }
    return ret;
}
*/
