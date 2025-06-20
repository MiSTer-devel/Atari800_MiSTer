#pragma once

// In principle the drive emulator itself just needs to have access to files from somewhere and then serves requests from the Atari.
// So it doesn't need to depend on fat, just needs a way of reading the specified 'file'
// So entry points are:
// i) Provide function ptr to: fetch data, check file size
// ii) Notify when disk has been changed/removed
// iii) Drive - called frequently so we can respond to commands received from Pokey

// To speak to the Atari we need:
// a) Command line
// b) Pokey
// Both these are mapped into zpu config regs
#include "integer.h"
#include "file.h"

#define MAX_DRIVES 15

struct drive_info
{
	struct SimpleFile *file;
	u08 info;
	char custom_loader;
	u32 offset;
	u32 meta_offset; // HDD only
	u16 partition_id; // HDD only
	u32 sector_count;
	u16 sector_size;
	u08 atari_sector_status;	
};

// The extra slot is for the HDD image as a whole (APT API)
extern struct drive_info drive_infos[MAX_DRIVES+1];

void actions(); // this is called whenever possible - should be quick

void init_drive_emulator();
void processCommand();
unsigned char processCommandPBI(unsigned char *);

// To remove a disk, set file to null
// For a read-only disk, just have no write function!
struct SimpleFile;
void set_drive_status(int driveNumber, struct SimpleFile * file);

