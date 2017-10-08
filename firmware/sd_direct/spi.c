/*! \file spi.c \brief SPI interface driver. */
//*****************************************************************************
//
// File Name	: 'spi.c'
// Title		: SPI interface driver
// Author		: Pascal Stang - Copyright (C) 2000-2002
// Created		: 11/22/2000
// Revised		: 06/06/2002
// Version		: 0.6
// Target MCU	: Atmel AVR series
// Editor Tabs	: 4
//
// NOTE: This code is currently below version 1.0, and therefore is considered
// to be lacking in some functionality or documentation, or may not be fully
// tested.  Nonetheless, you can expect most functions to work.
//
// ----------------------------------------------------------------------------
// 17.8.2008
// Bob!k & Raster, C.P.U.
// Original code was modified especially for the SDrive device. 
// Some parts of code have been added, removed, rewrited or optimized due to
// lack of MCU AVR Atmega8 memory.
// ----------------------------------------------------------------------------
//
// This code is distributed under the GNU Public License
//		which can be found at http://www.gnu.org/licenses/gpl.txt
//
//*****************************************************************************

#include "spi.h"

#include "regs.h"
#include "spi.h"

#include "printf.h"

int spi_slow; // 1 is slow
int spi_chip_select_n; // 0 is selected
int display;
void updateSpiState()
{
	*zpu_spi_state = (spi_slow<<1)|(spi_chip_select_n);
}

// access routines
void setSpiFast()
{
	spi_slow = 0;
	updateSpiState();
}

void setSpiSlow()
{
	spi_slow = 1;
	updateSpiState();
}

void set_spi_clock_freq() // avr handles spi clock?
{
	setSpiFast();
}

void spiInit()
{
	spiDisplay(0);
	spi_slow = 1;
	spi_chip_select_n = 1;
	updateSpiState();
}

void mmcChipSelect(int select)
{
	spi_chip_select_n = !select;
	updateSpiState();
}

u08 spiTransferByte(u08 data)
{
	u08 res = 0;

	//debug("spiTransferByte");

	/*if (display!=0)
	{
		plotnext(hextoatarichar((data&0xf0) >> 4));
		plotnext(hextoatarichar((data&0xf)));
	}*/

	// send the given data
	*zpu_spi_data = data;

	// wait for transfer to complete
	while ((1&*zpu_spi_state) == 1);

	// return the received data
	res = *zpu_spi_data;

	if (display!=0)
	{
		//XXX plotnext(hextoatarichar((res&0xf0) >> 4));
		//XXX plotnext(hextoatarichar((res&0xf)));

		//plotnext(toatarichar(' '));
	}

	return res;
}

u08 spiTransferFF()
{
	return spiTransferByte(0xFF);
}

void spiDisplay(int i)
{
	display = i;
}

void spiReceiveData(u08 * from, u08 * to)
{
	u32 from32 = (u32)from;
	u32 to32 = (u32)to;
	u32 val = to32<<16 | from32;
	*zpu_spi_dma = val;
}

