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
#include "file.h"

void actions(); // this is called whenever possible - should be quick

void init_drive_emulator();
void run_drive_emulator(); // Blocks. Pokey at its fastest is 6 cycles * 10 bits per byte. i.e. 60 cycles at 1.79MHz.

// To remove a disk, set file to null
// For a read-only disk, just have no write function!
struct SimpleFile;
void set_drive_status(int driveNumber, struct SimpleFile * file);
struct SimpleFile * get_drive_status(int driveNumber);
void describe_disk(int driveNumber, char * buffer);

// Pokey divisor
void set_turbo_drive(int pos);
int get_turbo_drive();
char const * get_turbo_drive_str();

