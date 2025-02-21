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

// number of angular units in a full disk rotation
#define AU_FULL_ROTATION         26042
// number of angular units to read one sector
#define AU_ONE_SECTOR_READ       1208
// number of ms for each angular unit
// #define MS_ANGULAR_UNIT_VAL      0.007999897601
// number of milliseconds drive takes to process a request
#define MS_DRIVE_REQUEST_DELAY   3.22
// number of milliseconds to calculate CRC
#define MS_CRC_CALCULATION       2
// number of milliseconds drive takes to step 1 track
#define MS_TRACK_STEP            5.3
// number of milliseconds drive head takes to settle after track stepping
#define MS_HEAD_SETTLE           0
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

struct atxTrackInfo {
    u32 offset;   // absolute position within file for start of track header
};

enum atx_density { atx_single, atx_medium, atx_double };

extern unsigned char atari_sector_buffer[256];
// extern u16 last_angle_returned; // extern so we can display it on the screen

u16 gBytesPerSector[NUM_ATX_DRIVES];                                 // number of bytes per sector
u08 gSectorsPerTrack[NUM_ATX_DRIVES];                                // number of sectors in each track
struct atxTrackInfo gTrackInfo[NUM_ATX_DRIVES][MAX_TRACK];  // pre-calculated info for each track and drive
                                                     // support slot D1 and D2 only because of insufficient RAM!
u16 gLastAngle[NUM_ATX_DRIVES];
u08 gCurrentHeadTrack[NUM_ATX_DRIVES];
u08 atxDensity[NUM_ATX_DRIVES];

u08 loadAtxFile(u08 drive) {
    struct atxFileHeader *fileHeader;
    struct atxTrackHeader *trackHeader;
    u08 r = 0;

    // read the file header
    if(!faccess_offset(FILE_ACCESS_READ, 0, sizeof(struct atxFileHeader))) {
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
        fileHeader->minVersion != ATX_VERSION) {
        return r;
    }
    r = fileHeader->density;
    // enhanced density is 26 sectors per track, single and double density are 18
    gSectorsPerTrack[drive] = (r == atx_medium) ? (u08) 26 : (u08) 18;
    // single and enhanced density are 128 bytes per sector, double density is 256
    gBytesPerSector[drive] = (r == atx_double) ? (u16) 256 : (u16) 128;
    atxDensity[drive] = r;
    gCurrentHeadTrack[drive] = 0;

    // calculate track offsets
    u32 startOffset = fileHeader->startData;
    int track;
    for(track = 0; track < MAX_TRACK ; track++) {
        if (!faccess_offset(FILE_ACCESS_READ, startOffset, sizeof(struct atxTrackHeader))) {
            break;
        }
        trackHeader = (struct atxTrackHeader *) atari_sector_buffer;
        byteSwapAtxTrackHeader(trackHeader);
        gTrackInfo[drive][track].offset = startOffset;
        startOffset += trackHeader->size;
    }

    return r;
}

// Return 0 on full success, 1 on "Atari disk problem" (may have data)
// -1 on internal storage problem (corrupt ATX) 
int loadAtxSector(u08 drive, u16 num, u08 *status) {

    struct atxTrackHeader *trackHeader;
    struct atxSectorListHeader *slHeader;
    struct atxSectorHeader *sectorHeader;
    struct atxTrackChunk *extSectorData;

    u16 i;
    int r = 1;
    u08 is1050 = 1; // TODO make this configurable

    // calculate track and relative sector number from the absolute sector number
    u08 tgtTrackNumber = (num - 1) / gSectorsPerTrack[drive];
    u08 tgtSectorNumber = (num - 1) % gSectorsPerTrack[drive] + 1;

    // set initial status (in case the target sector is not found)
    *status = MASK_FDC_MISSING;

    u16 atxSectorSize = gBytesPerSector[drive];

    // delay for the time the drive takes to process the request
    // TODO
    _delay_ms(MS_DRIVE_REQUEST_DELAY);

    // delay for track stepping if needed
    int diff = tgtTrackNumber - gCurrentHeadTrack[drive];
    if (diff) {
        if (diff > 0)
		diff += (is1050 ? 1 : 0);
	else
		diff = -diff;
        // wait for each track (this is done in a loop since _delay_ms needs a compile-time constant)
        for (i = 0; i < diff; i++) {
            _delay_ms(MS_TRACK_STEP);
        }
        // delay for head settling
        _delay_ms(MS_HEAD_SETTLE);
    }

    // set new head track position
    gCurrentHeadTrack[drive] = tgtTrackNumber;

    // TODO sample current head position
    u16 headPosition = getCurrentHeadPosition();

    u16 sectorCount = 0;

    // read the track header
    u32 currentFileOffset = gTrackInfo[drive][tgtTrackNumber].offset;
    
    if (currentFileOffset) {
	    if(faccess_offset(FILE_ACCESS_READ, currentFileOffset, sizeof(struct atxTrackHeader))) {
		    trackHeader = (struct atxTrackHeader *) atari_sector_buffer;
		    byteSwapAtxTrackHeader(trackHeader);
		    sectorCount = trackHeader->sectorCount;	    
	    } else {
		    r = -1;
	    }
    }

    if (trackHeader->trackNumber != tgtTrackNumber || atxDensity[drive] != ((trackHeader->flags & 0x2) ? atx_medium : atx_single)) {
	    sectorCount = 0;
    }

    u32 trackHeaderSize = trackHeader->headerSize;

    if (sectorCount) {
	currentFileOffset += trackHeaderSize;
        if(faccess_offset(FILE_ACCESS_READ, currentFileOffset, sizeof(struct atxSectorListHeader))) {
	    slHeader = (struct atxSectorListHeader *) atari_sector_buffer;
	    byteSwapAtxSectorListHeader(slHeader);
	    // sector list header is variable length, so skip any extra header bytes that may be present
	    currentFileOffset += slHeader->next - sectorCount * sizeof(struct atxSectorHeader);
	} else {
	    sectorCount = 0;
	    r = -1;
	}
    }

    u32 tgtSectorOffset;        // the offset of the target sector data
    int16_t weakOffset;

    u08 retries = is1050 ? MAX_RETRIES_1050 : MAX_RETRIES_810;

    u32 retryOffset = currentFileOffset;
    u16 extSectorSize;

    while (retries > 0) {
	retries--;
        currentFileOffset = retryOffset;
	int pTT;
	u16 tgtSectorIndex = 0;         // the index of the target sector within the sector list
	tgtSectorOffset = 0;
	weakOffset = -1;
        // iterate through all sector headers to find the target sector

	if(sectorCount) {

		for (i=0; i < sectorCount; i++) {
			if(!faccess_offset(FILE_ACCESS_READ, currentFileOffset, sizeof(struct atxSectorHeader))) {
				r = -1;
				break;
			}
			sectorHeader = (struct atxSectorHeader *)atari_sector_buffer;
			byteSwapAtxSectorHeader(sectorHeader);

			// if the sector is not flagged as missing and its number matches the one we're looking for...
			if (sectorHeader->number == tgtSectorNumber) {
				if(sectorHeader->status & MASK_FDC_MISSING) {
					currentFileOffset += sizeof(struct atxSectorHeader);
					continue;
				}
				// check if it's the next sector that the head would encounter angularly...
				int tt = sectorHeader->timev - headPosition;
				if (!tgtSectorOffset || (tt > 0 && pTT <= 0) || (tt > 0 && pTT > 0 && tt < pTT) || (tt <= 0 && pTT <= 0 && tt < pTT)) {
					pTT = tt;
					// TODO gLastAngle will not be needed later when the timing is fixed
					gLastAngle[drive] = sectorHeader->timev;
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
        if (*status & MASK_EXTENDED_DATA) {
            currentFileOffset = gTrackInfo[drive][tgtTrackNumber].offset + trackHeaderSize;
            do {
                if(!faccess_offset(FILE_ACCESS_READ, currentFileOffset, sizeof(struct atxTrackChunk))) {
			r = -1;
			break;
		}
                extSectorData = (struct atxTrackChunk *) atari_sector_buffer;
                byteSwapAtxTrackChunk(extSectorData);
                if (extSectorData->size) {
                    // if the target sector has a weak data flag, grab the start weak offset within the sector data
                    if (extSectorData->sectorIndex == tgtSectorIndex) {
			    if(extSectorData->type == 0x10) {// weak sector
				    weakOffset = extSectorData->data;
			    } else if(extSectorData->type == 0x11) { // extended sector
				    extSectorSize = 128 << extSectorData->data;
				    // 1050 waits for long sectors, 810 does not
				    if(is1050 ? (extSectorSize > actSectorSize) : (extSectorSize < actSectorSize)) {
					    actSectorSize = extSectorSize;
				    }
			    }
                    }
                    currentFileOffset += extSectorData->size;
                }
            } while (extSectorData->size);
        }
	    
        if (tgtSectorOffset) {
	    if(!faccess_offset(FILE_ACCESS_READ, gTrackInfo[drive][tgtTrackNumber].offset + tgtSectorOffset, atxSectorSize)) {
		    r = -1;
		    tgtSectorOffset = 0;
	    }
	    // TODO
	    u16 rotationDelay;
            if (gLastAngle[drive] > headPosition) {
                rotationDelay = (gLastAngle[drive] - headPosition);
            } else {
                rotationDelay = (AU_FULL_ROTATION - headPosition + gLastAngle[drive]);
            }

            // determine the angular position we need to wait for by summing the head position, rotational delay and the number 
            // of rotational units for a sector read. Then wait for the head to reach that position.
            // (Concern: can the SD card read take more time than the amount the disk would have rotated?)
            waitForAngularPosition(incAngularDisplacement(incAngularDisplacement(headPosition, rotationDelay), AU_ONE_SECTOR_READ));
        }else{
	    // TODO
    	    waitForAngularPosition(incAngularDisplacement(getCurrentHeadPosition(), AU_FULL_ROTATION));
    
        }
	    
	    // TODO
    	headPosition = getCurrentHeadPosition();

	if(!*status || r < 0)
		break;

    }

    *status &= ~(MASK_RESERVED | MASK_EXTENDED_DATA);

    if (*status & MASK_FDC_DLOST) {
	    if(is1050) {
	        *status |= MASK_FDC_DRQ;
	    }
	    else
	    {
		*status &= ~(MASK_FDC_DLOST | MASK_FDC_CRC);
		*status |= MASK_FDC_BUSY;
	    }
    }
    if(!is1050 && (*status & MASK_FDC_REC)) {
	*status |= MASK_FDC_WP;
    }

    if (tgtSectorOffset && !*status && r >= 0) {
	    r = 0;
    }

    // if a weak offset is defined, randomize the appropriate data
    if (weakOffset > -1) {
        for (i = (u16) weakOffset; i < atxSectorSize; i++) {
            atari_sector_buffer[i] = (u08) (rand() & 0xFF);
        }
    }

    // TODO
    // delay for CRC calculation
    _delay_ms(MS_CRC_CALCULATION);

    // the Atari expects an inverted FDC status byte
    *status = ~(*status);

    // store the last angle returned for the debugging window
    // last_angle_returned = gLastAngle[drive];

    // return the number of bytes read
    return r;
}

u16 incAngularDisplacement(u16 start, u16 delta) {
    // increment an angular position by a delta taking a full rotation into consideration
    u16 ret = start + delta;
    if (ret > AU_FULL_ROTATION) {
        ret -= AU_FULL_ROTATION;
    }
    return ret;
}
