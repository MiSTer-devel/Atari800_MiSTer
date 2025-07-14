#pragma once

#include "file.h"

// Allow us to take over the system
// NB: CPU should be frozen before calling these!

// Provide 128K of RAM...
void freeze_init(void * memory);

// Set hardware registers to 'neutral'
// Back up system ram
void freeze();

// Restore system ram
// Restore hardware registers
void restore();

// Store system ram to a file for debugging (base 64k only)
//void freeze_save(struct SimpleFile * file);
//void freeze_load(struct SimpleFile * file);

