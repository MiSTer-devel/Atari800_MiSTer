#include "atari_drive_emulator.h"
//#include "fileutils.h"

#include "uart.h"
#include "regs.h"
#include "pause.h"
#include "atx_eclaire.h"
#include "atx.h"
//#include "hexdump.h"

//#include "printf.h"
//#include <stdio.h>

extern int debug_pos; // ARG!
// extern unsigned char volatile * baseaddr;

#define send_ACK()	USART_Transmit_Byte('A')
#define send_NACK()	USART_Transmit_Byte('N')
#define send_CMPL()	USART_Transmit_Byte('C')
#define send_ERR()	USART_Transmit_Byte('E')
#define set_drive_led_on()  *zpu_out1 |= 0x08000000
#define set_drive_led_off() *zpu_out1 &= 0xF7FFFFFF
#define get_speeddrv() (*zpu_in2 & 0x7)

/* BiboDos needs at least 50us delay before ACK */
#define DELAY_T2_MIN wait_us(100)

/* the QMEG OS needs at least 300usec delay between ACK and complete */
#define DELAY_T5_MIN wait_us(300)

/* QMEG OS 3 needs a delay of 150usec between complete and data */
#define DELAY_T3_PERIPH wait_us(150)

#define speedslow 0x28
#define speedfast turbo_divs[get_speeddrv()]
const unsigned char turbo_divs[] = { speedslow,	0x6, 0x5, 0x4, 0x3, 0x2, 0x1, 0x0 };

#define XEX_SECTOR_SIZE 128

struct drive_info drive_infos[MAX_DRIVES+1];

char speed;

u32 pre_ce_delay;
u32 pre_an_delay;

#define INFO_RO 0x40
#define INFO_HDD 0x80
#define INFO_META 0x20 // if the HDD uses the meta information sectors
#define INFO_SS 0x10 // mark that the sector is smaller than the SD card image sector

struct ATRHeader
{
	u16 wMagic;
	u16 wPars;
	u16 wSecSize;
	u08 btParsHigh;
	u32 dwCRC;
	u32 dwUNUSED;
	u08 btFlags;
} __attribute__((packed));

#define ATARI_SECTOR_BUFFER_SIZE 512

unsigned char atari_sector_buffer[ATARI_SECTOR_BUFFER_SIZE];

unsigned char get_checksum(unsigned char* buffer, int len);

#define    TWOBYTESTOWORD(ptr,val)           (*((u08*)(ptr)) = val&0xff);(*(1+(u08*)(ptr)) = (val>>8)&0xff);

void memset8(void *address, int value, int length);
void USART_Send_cmpl_and_atari_sector_buffer_and_check_sum(unsigned char *sector_buffer, unsigned short len, int success);

uint8_t boot_xex_loader[179] = {
	0x72,0x02,0x5f,0x07,0xf8,0x07,0xa9,0x00,0x8d,0x04,0x03,0x8d,0x44,0x02,0xa9,0x07,
	0x8d,0x05,0x03,0xa9,0x70,0x8d,0x0a,0x03,0xa9,0x01,0x8d,0x0b,0x03,0x85,0x09,0x60,
	0x7d,0x8a,0x48,0x20,0x53,0xe4,0x88,0xd0,0xfa,0x68,0xaa,0x8c,0x8e,0x07,0xad,0x7d,
	0x07,0xee,0x8e,0x07,0x60,0xa9,0x93,0x8d,0xe2,0x02,0xa9,0x07,0x8d,0xe3,0x02,0xa2,
	0x02,0x20,0xda,0x07,0x95,0x43,0x20,0xda,0x07,0x95,0x44,0x35,0x43,0xc9,0xff,0xf0,
	0xf0,0xca,0xca,0x10,0xec,0x30,0x06,0xe6,0x45,0xd0,0x02,0xe6,0x46,0x20,0xda,0x07,
	0xa2,0x01,0x81,0x44,0xb5,0x45,0xd5,0x43,0xd0,0xed,0xca,0x10,0xf7,0x20,0xd2,0x07,
	0x4c,0x94,0x07,0xa9,0x03,0x8d,0x0f,0xd2,0x6c,0xe2,0x02,0xad,0x8e,0x07,0xcd,0x7f,
	0x07,0xd0,0xab,0xee,0x0a,0x03,0xd0,0x03,0xee,0x0b,0x03,0xad,0x7d,0x07,0x0d,0x7e,
	0x07,0xd0,0x8e,0x20,0xd2,0x07,0x6c,0xe0,0x02,0x20,0xda,0x07,0x8d,0xe0,0x02,0x20,
	0xda,0x07,0x8d,0xe1,0x02,0x2d,0xe0,0x02,0xc9,0xff,0xf0,0xed,0xa9,0x00,0x8d,0x8e,
	0x07,0xf0,0x82 };

void byteswap(WORD * inw)
{
#ifndef LITTLE_ENDIAN
	unsigned char * in = (unsigned char *)inw;
	unsigned char temp = in[0];
	in[0] = in[1];
	in[1] = temp;
#endif
}

struct command
{
	u08 deviceId;
	u08 command;
	u08 aux1;
	u08 aux2;
	u08 chksum;
	u16 auxab;
} __attribute__((packed));

static void switch_speed()
{
	int tmp = *zpu_uart_divisor;
	*zpu_uart_divisor = tmp-1;
}

void getCommand(struct command * cmd)
{
	int expchk;
	int i;
	int prob;
	while (1)
	{
		prob = 0;
		for (i=0;i!=5;++i)
		{
			u32 data = USART_Receive_Byte(); // Timeout?
			//*zpu_uart_debug = i;
			//*zpu_uart_debug = 1&(data>>8);
			//*zpu_uart_debug = data&0xff;
			if (USART_Framing_Error() | ((data>>8)!=(i+1)))
			{
				prob = 1;
				break;
			}
			((unsigned char *)cmd)[i] = data&0xff;
			//*zpu_uart_debug = (data&0xff);
			//*zpu_uart_debug3 = i;
		}


		if (prob) // command malformed, try again!
		{
			//prob = 0;

			//*zpu_uart_debug2 = 0xf0;
			// error
			continue;
		}

		//*zpu_uart_debug = 0xba;
		USART_Receive_Byte();
		//*zpu_uart_debug = 0xda;

		//*zpu_uart_debug = *zpu_uart_divisor;

		memcp8(cmd, atari_sector_buffer, 0, 4);
		expchk = get_checksum(&atari_sector_buffer[0],4);

		//*zpu_uart_debug2 = expchk;
		//*zpu_uart_debug2 = cmd->chksum;

		if (expchk==cmd->chksum) {
			//*zpu_uart_debug2 = 0x44;
			// got a command frame
			//
			switch_speed();
			break;
		} else {
			//*zpu_uart_debug2 = 0xff;
			// just an invalid checksum, switch speed anyways
		}
	}
	// This is done elsewhere!
	// DELAY_T2_MIN;
}

unsigned char hdd_partition_scan(struct SimpleFile *file, unsigned char info)
{
	int read = 0;
	file_seek(file, 0);
	file_read(file, atari_sector_buffer, 256, &read);
	if(read != 256) return 0;
	if(atari_sector_buffer[1] != 'A' || atari_sector_buffer[2] != 'P' || atari_sector_buffer[3] != 'T')
	{
		file_read(file, atari_sector_buffer, 256, &read);
		if(read != 256) return 0;
		read = 0xC2;
		while(read < 0x100)
		{
			if(atari_sector_buffer[read] == 0x7F)
			{
				read = ((atari_sector_buffer[read+4]) |
				((atari_sector_buffer[read+5] << 8)) | 
				((atari_sector_buffer[read+6] << 16)) | 
				((atari_sector_buffer[read+7] << 24))) << 9; 
				file_seek(file, read);
				file_read(file, atari_sector_buffer, 256, &read);
				if(read != 256 || atari_sector_buffer[1] != 'A' || atari_sector_buffer[2] != 'P' || atari_sector_buffer[3] != 'T') return 0;
				break;
			}
			read += 16;
		}
	}
	if(atari_sector_buffer[0] == 0x10)
	{
		info |= INFO_META;
	}
	else if(atari_sector_buffer[0]) return 0;
	info |= (atari_sector_buffer[4] & 0xF);
	for(read = 0; read < 15; read++)
	{
		int i = (read+1)*16;
		if(!atari_sector_buffer[i])
		{
			// empty slot
			if(drive_infos[read].file && (drive_infos[read].info & INFO_HDD))
			{
				drive_infos[read].file = 0;
			}
		}
		else
		{
			drive_infos[read].info = (info & 0xC0) | (atari_sector_buffer[i] & 0x40 ? INFO_META : 0) |
			((atari_sector_buffer[i] & 0x30) || (atari_sector_buffer[i+12] & 0x80) ? INFO_RO : 0);
			atari_sector_buffer[i] &= 0x8F;
			if(atari_sector_buffer[i] > 3 || (atari_sector_buffer[i+1] != 0x00 && atari_sector_buffer[i+1] != 0x03) || !(atari_sector_buffer[i+12] & 0x40))
			{
				drive_infos[read].file = 0;
			}
			else
			{
				drive_infos[read].sector_size = 128 << (atari_sector_buffer[i]-1);
				if(drive_infos[read].sector_size != 512)
				{
					drive_infos[read].info |= INFO_SS;
				}
				drive_infos[read].offset =
				( atari_sector_buffer[i+2] |
					(atari_sector_buffer[i+3] << 8) | 
					(atari_sector_buffer[i+4] << 16) | 
					(atari_sector_buffer[i+5] << 24)
				) << 9;
				drive_infos[read].sector_count = 
				atari_sector_buffer[i+6] |
				(atari_sector_buffer[i+7] << 8) | 
				(atari_sector_buffer[i+8] << 16) | 
				(atari_sector_buffer[i+9] << 24);
				drive_infos[read].partition_id = atari_sector_buffer[i+10] | (atari_sector_buffer[i+11] << 8);
				if(atari_sector_buffer[i+1] == 0x00) // DOS partition
				{
					u16 p_offset =
					(atari_sector_buffer[i+14] | (atari_sector_buffer[i+15] << 8)) << 9;
					drive_infos[read].meta_offset = drive_infos[read].offset - 512;
					drive_infos[read].offset += p_offset;
				}
				else // External partition
				{
					drive_infos[read].meta_offset =
					(atari_sector_buffer[i+13] |
						(atari_sector_buffer[i+14] << 8) | 
						(atari_sector_buffer[i+15] << 16)
					) << 9;
				}
				drive_infos[read].custom_loader = 0;
				drive_infos[read].atari_sector_status = 0xFF;
				drive_infos[read].file = file;
				
			}
		}
	}
	return info;
}

// Called whenever file changed
void set_drive_status(int driveNumber, struct SimpleFile * file)
{
	int read = 0;
	unsigned char info = 0;
	struct ATRHeader atr_header;

	//*zpu_uart_debug2 = 0x11;

	if (!file)
	{
		if(driveNumber > 1 && drive_infos[MAX_DRIVES].file)
		{
			for(read = 0; read <= MAX_DRIVES; read++)
			{
				if(drive_infos[read].info & INFO_HDD)
				{
					drive_infos[read].file = 0;
				}
			}
		}
		else
		{
			drive_infos[driveNumber].file = 0;	
		}
		return;
	}
	
	// Slots 3 & 4 double as HDD image -> redirect to the last slot in the table
	if(driveNumber > 1 && file->type == 3)
	{
		driveNumber = MAX_DRIVES;
	}

	if(file->is_readonly)
	{
		info |= INFO_RO;			
	}

	//*zpu_uart_debug2 = 0x12;

	// set_drive_status should be only called once on file loading
	// the position should be 0 then and this is obsolete
	// file_seek(file, 0);
	//*zpu_uart_debug2 = 0x23;
	
	if(file->type == 0) // ATR only
	{
		file_read(file, (unsigned char *)&atr_header, 16, &read);
		//*zpu_uart_debug2 = 0x33;
		if (read != 16)
		{
			return;
		}
		
		//*zpu_uart_debug2 = 0x13;
		
		byteswap(&atr_header.wMagic);
		byteswap(&atr_header.wPars);
		byteswap(&atr_header.wSecSize);
	}

	drive_infos[driveNumber].custom_loader = 0;
	drive_infos[driveNumber].atari_sector_status = 0xff;

	if (file->type == 2) // XDF
	{
		drive_infos[driveNumber].offset = 0;
		drive_infos[driveNumber].sector_count = file->size / 0x80;
		drive_infos[driveNumber].sector_size = 0x80;
	}
	if (file->type == 3) // ATX or HDD image
	{
		if(driveNumber < MAX_DRIVES)
		{
			drive_infos[driveNumber].custom_loader = 2;
			gAtxFile = file;
			info |= INFO_RO;
			u08 atxType = loadAtxFile(driveNumber);
			drive_infos[driveNumber].sector_count = (atxType == 1) ? 1040 : 720;
			drive_infos[driveNumber].sector_size = (atxType == 2) ? 256 : 128;
		}
		else
		{
			info |= INFO_HDD;
			drive_infos[driveNumber].sector_size = 512;
			drive_infos[driveNumber].sector_count = file->size / 0x200;
			drive_infos[driveNumber].atari_sector_status = 0;
			drive_infos[driveNumber].offset = 0;
			info = hdd_partition_scan(file, info);
			if(!info) return;
		}
	}
	else if (file->type == 1) // XEX
	{
		drive_infos[driveNumber].custom_loader = 1;
		drive_infos[driveNumber].sector_count = 0x173+(file->size+(XEX_SECTOR_SIZE-4))/(XEX_SECTOR_SIZE-3);
		drive_infos[driveNumber].sector_size = XEX_SECTOR_SIZE;
		info |= INFO_RO;
	}
	else if (file->type == 0) // ATR
	{
		drive_infos[driveNumber].offset = 16;
		if(atr_header.wSecSize == 512)
		{
			drive_infos[driveNumber].sector_count = (atr_header.wPars | (atr_header.btParsHigh << 16)) / 32;	
		}
		else
		{
			drive_infos[driveNumber].sector_count = 3 + ((atr_header.wPars | (atr_header.btParsHigh << 16))*16 - 128*3) / atr_header.wSecSize;
		}
		drive_infos[driveNumber].sector_size = atr_header.wSecSize;
	}

	drive_infos[driveNumber].file = file;
	drive_infos[driveNumber].info = info;
	//printf("appears valid\n");
}


void init_drive_emulator()
{
	speed = speedslow;
	USART_Init(speedslow+6);
	memset8(drive_infos, 0, (MAX_DRIVES+1)*sizeof(struct drive_info));
}

/////////////////////////

struct sio_action
{
	int bytes;
	int success;
	int speed;
	int respond;
	unsigned char *sector_buffer;
};

typedef void (*CommandHandler)(struct command, int, struct SimpleFile *, struct sio_action *);
CommandHandler  getCommandHandler(struct command, u08);

unsigned char processCommandPBI(unsigned char *drives_config)
{
	// We are more or less guranteed to serve the correct device id and 
	// drive unit number by now, no need to check here
	// mark a bit (0x40) in deviceId to indicate this is PBI, this is not the same
	// as the XDCB bit (0x80)

	unsigned char volatile *ptr = (unsigned char volatile *)(atari_regbase + 0x300);
	u08 sd_device = (ptr[0] & 0x7F) == 0x20;
	int drive = ptr[1] - 1;
	struct command command;
	command.deviceId = (ptr[0] + drive) | 0x40; // ddevic + dunit - 1 plus PBI marker

	/*
	  This piece of admitedely contrived logic takes care of diverting or not further processing
	  to SIO routines. The procedure is not exactly the same as on, say, Ultimate 1MB PBI BIOS, nor 
	  it is strictly according to the PBI API requirements, here we (safely?) assume there are no
	  other PBI devices (and hence ROM BIOSes), so this allows us to take some shortcuts (which also
	  speeds up things on the Atari / SDX side).
	*/

	unsigned char mode = (sd_device && !drive) ? 1 : ((!sd_device && drive < 4) ? drives_config[drive] : ((ptr[0] & 0x80) >> 7));

	struct SimpleFile *file = 0;
	if(sd_device)
	{
		if(!drive)
		{
			drive = MAX_DRIVES;
			file = drive_infos[drive].file;
		}
	}
	else
	{
		file = drive_infos[drive].file;
	}
	
	if(file)
	{
		if(drive_infos[drive].info & INFO_HDD) // The type should be then ATR
		{
			if(!sd_device)
			{
				mode = 1;
			}
		}
		else
		{
			if(file->type == 3) mode = 0; // ATX -> Off
			if(file->type == 1) mode = 1; // XEX -> PBI
		}
	}

	// HSIO does not handle 512-byte sector ATRs
	if(!mode || (file && mode == 2 && drive_infos[drive].sector_size == 512))
		return 0xFF;

	mode--;
	if (!file || mode == 1)
	{
		if(!mode) ptr[3] = 0x8A;
		return mode;
	}

	command.command = ptr[2];
	command.aux1 = ptr[0xA];
	command.aux2 = ptr[0xB];
	command.auxab = (command.deviceId & 0x80) ? ptr[0xC] | (ptr[0xD] << 8) : 0;

	CommandHandler handleCommand = getCommandHandler(command, ptr[3]);
	if (handleCommand)
	{
		struct sio_action action;
		action.bytes = ptr[8] | (ptr[9] << 8);
		action.success = 1;
		action.respond = 1;
		action.sector_buffer = (unsigned char *)(atari_regbase + (ptr[4] | (ptr[5] << 8)));

		handleCommand(command, drive, file, &action);

		if (action.respond)
		{
			ptr[8] = action.bytes & 0xFF;
			ptr[9] = (action.bytes >> 8) & 0xFF;
		}
		ptr[3] = action.success ? 0x01 : 0x90;
	}
	else
	{
		ptr[3] = 0x8B;
	}
	return mode;
}

void processCommand()
{
	struct command command;

	getCommand(&command);
	command.auxab = 0;

	int drive = (command.deviceId & 0xf) -1;
	if (command.deviceId >= 0x31 && command.deviceId <= 0x34 && drive_infos[drive].sector_size != 512)
	{
		struct SimpleFile * file = drive_infos[drive].file;

	//	printf("Drive:");
	//	printf("%x %d",command.deviceId,drive);

		if (!file)
		{
			//send_NACK();
			//wait_us(100); // Wait for transmission to complete - Pokey bug, gets stuck active...

			//printf("Drive not present:%d %x", drive, drives[drive]);
			//
			//
			//*zpu_uart_debug2 = 0x16;
			return;
	
		}

		pre_ce_delay = 300;
		pre_an_delay = 100;
		
		//*zpu_uart_debug3 = command.command;

		CommandHandler handleCommand = getCommandHandler(command, 0);
		// DELAY_T2_MIN;
		wait_us(pre_an_delay);

		if (handleCommand)
		{
			struct sio_action action;
			action.bytes = 0;
			action.success = 1;
			action.speed = -1;
			action.respond = 1;
			action.sector_buffer = atari_sector_buffer;

			send_ACK();
			memset8(atari_sector_buffer, 0, ATARI_SECTOR_BUFFER_SIZE);

			handleCommand(command, drive, file, &action); //TODO -> this should respond with more stuff and we handle result in a common way...

			if (action.respond)
				USART_Send_cmpl_and_atari_sector_buffer_and_check_sum(action.sector_buffer, action.bytes, action.success);
			if (action.speed>=0)
				USART_Init(action.speed); // Wait until fifo is empty - then set speed!
		}
		else
		{
			send_NACK();
		}
	}
}

void handleSpeed(struct command command, int driveNumber, struct SimpleFile * file, struct sio_action * action)
{
	// We should be guaranteed that this is not called in PBI mode,
	// so no need to check the PBI bit
	action->bytes = 1;
	if(drive_infos[driveNumber].custom_loader == 2)
	{
		action->sector_buffer[0] = speedslow;
		speed = speedslow;
	}
	else
	{
		action->sector_buffer[0] = speedfast;
		speed = command.aux2 ? speedslow : speedfast;
	}
	action->speed = speed +6;
}

void handleFormat(struct command command, int driveNumber, struct  SimpleFile * file, struct sio_action * action)
{
	if (drive_infos[driveNumber].info & INFO_RO) 
	{
		// fail, write protected
		action->success = 0;
	}
	else
	{
		int i;

		// fill image with zeros
		memset8(action->sector_buffer, 0, drive_infos[driveNumber].sector_size);
		int written = 0;
		i = drive_infos[driveNumber].offset;
		file_seek(file, i);
		for (; i != file->size; i += 128)
		{
			file_write(file, &action->sector_buffer[0], 128, &written);
		}

		// return done
		action->sector_buffer[0] = 0xff;
		action->sector_buffer[1] = 0xff;
		action->bytes = drive_infos[driveNumber].sector_size;
	}
}

void handleReadPercomBlock(struct command command, int driveNumber, struct SimpleFile * file, struct sio_action * action)
{
	u16 totalSectors = drive_infos[driveNumber].sector_count;
	memset8(action->sector_buffer, 0, 12);
	action->sector_buffer[1] = 0x03;
	action->sector_buffer[6] = drive_infos[driveNumber].sector_size >> 8;
	action->sector_buffer[7] = drive_infos[driveNumber].sector_size & 0xff;		
	action->sector_buffer[8] = 0xff;
	
	if(!(drive_infos[driveNumber].info & INFO_HDD) && (totalSectors == 720 || totalSectors == 1040 || totalSectors == 1440))
	{
		totalSectors = totalSectors / 40;
		if(totalSectors == 36)
		{
			totalSectors = totalSectors / 2;
			action->sector_buffer[4] = 1;
		}
		action->sector_buffer[0] = 40;
		action->sector_buffer[5] = (drive_infos[driveNumber].sector_size == 256 || totalSectors == 26) ? 4 : 0;
	}
	else
	{
		action->sector_buffer[0] = 1;
		action->sector_buffer[5] = (drive_infos[driveNumber].sector_size == 128) ? 0 : 4;
	}
	action->sector_buffer[2] = totalSectors >> 8;
	action->sector_buffer[3] = totalSectors & 0xff;
	//hexdump_pure(atari_sector_buffer,12); // Somehow with this...
	
	action->bytes = 12;
	//printf("%d",atari_sector_buffer[0]); // and this... The wrong checksum is sent!!
	//printf(":done\n");
}

void handleForceMediaChange(struct command command, int driveNumber, struct SimpleFile * file, struct sio_action * action)
{
	action->respond = 0;
	unsigned char info = hdd_partition_scan(file, INFO_HDD | (file->is_readonly ? INFO_RO : 0));
	if(!info)
	{
		action->success = 0;
	}
	else
	{
		drive_infos[driveNumber].info =  info;
	}
}

void handleDeviceInfo(struct command command, int driveNumber, struct SimpleFile * file, struct sio_action * action)
{
	memset8(action->sector_buffer, 0, action->bytes);
	action->sector_buffer[0] = 1;
	action->sector_buffer[2] = 1;
	action->sector_buffer[6] = drive_infos[driveNumber].sector_size;
	action->sector_buffer[7] = drive_infos[driveNumber].sector_size >> 8;
	action->sector_buffer[8] = drive_infos[driveNumber].sector_count;
	action->sector_buffer[9] = drive_infos[driveNumber].sector_count >> 8;
	action->sector_buffer[10] = drive_infos[driveNumber].sector_count >> 16;
	action->sector_buffer[11] = drive_infos[driveNumber].sector_count >> 24;
	if(driveNumber == MAX_DRIVES)
	{
		memcp8((unsigned char volatile *)(atari_regbase + 0xDFAF), &action->sector_buffer[0x10], 0, ((unsigned volatile char *)(atari_regbase + 0xDFAE))[0]);
		memcp8((unsigned char volatile *)(atari_regbase + 0xDFD8), &action->sector_buffer[0x38], 0, ((unsigned volatile char *)(atari_regbase + 0xDFD7))[0]);
	}
	else
	{
		action->sector_buffer[3] = drive_infos[driveNumber].partition_id;
		action->sector_buffer[4] = drive_infos[driveNumber].partition_id >> 8;
		// TODO This made me realize that we are limited in the SD image size
		action->sector_buffer[12] = drive_infos[driveNumber].offset >> 9;
		action->sector_buffer[13] = drive_infos[driveNumber].offset >> 17;
		action->sector_buffer[14] = drive_infos[driveNumber].offset >> 25;
		if(drive_infos[driveNumber].info & INFO_META)
		{
			int read;
			file_seek(drive_infos[driveNumber].file, drive_infos[driveNumber].meta_offset+16);
			file_read(drive_infos[driveNumber].file, &action->sector_buffer[0x10], 40, &read);
			if(read != 40)
			{
				action->success = 0;
			}
		}
	}
}

/*
void handleDeviceStatus(struct command command, int driveNumber, struct SimpleFile * file, struct sio_action * action)
{
	memset8(action->sector_buffer, 0, action->bytes);
	action->sector_buffer[0x0C] = 0x3F;
}
*/

void handleGetStatus(struct command command, int driveNumber, struct SimpleFile * file, struct sio_action * action)
{
	unsigned char status;

	if(driveNumber == MAX_DRIVES)
	{
		status = 0x40;
	}
	else
	{
		
		status = 0x10; // Motor on;
		
		if (drive_infos[driveNumber].info & INFO_RO)
		{
			status |= 0x08; // write protected; // no write support yet...
		}
		if(drive_infos[driveNumber].sector_count != 720)
		{
			status |= 0x80; // medium density - or a strange one...
		}
		if(drive_infos[driveNumber].sector_size != 128)
		{
			status |= 0x20; // 256 byte sectors		
		}
	}
	action->sector_buffer[0] = status;
	action->sector_buffer[1] = drive_infos[driveNumber].atari_sector_status;
	action->sector_buffer[2] = driveNumber == MAX_DRIVES ? 0x10 : 0xe0; // What should be our ID?
	action->sector_buffer[3] = driveNumber == MAX_DRIVES ? ((unsigned volatile char *)(atari_regbase + 0xDFAD))[0] : 0x00; // version
	//hexdump_pure(atari_sector_buffer,4); // Somehow with this...
	
	action->bytes = 4;
	//printf("%d",atari_sector_buffer[0]); // and this... The wrong checksum is sent!!
	//printf(":done\n");
}

int set_location_offset(int driveNumber, u32 sector, u32 *location)
{
	*location = drive_infos[driveNumber].offset;
	int sectorSize = drive_infos[driveNumber].info & (INFO_HDD | INFO_SS) ? 512 : drive_infos[driveNumber].sector_size;
	if(drive_infos[driveNumber].sector_size == 512 || (drive_infos[driveNumber].info & INFO_HDD))
	{
		if(driveNumber != MAX_DRIVES)
		{
			sector--;
		}
		*location += sector * sectorSize;
	}
	else
	{
		if(sector>3)
		{
			*location += 128*3 + (sector-4) * sectorSize;
		}
		else
		{
			*location = *location + 128 * (sector - 1);
			sectorSize = 128;
		}
	}
	return sectorSize;
}

void handleWrite(struct command command, int driveNumber, struct SimpleFile * file, struct sio_action * action)
{
	//debug_pos = 0;
	set_drive_led_on();

	u08 pbi = command.deviceId & 0x40;
	u32 sector = (command.auxab << 16) | command.aux1 | (command.aux2 << 8);
	int sectorSize = 0;
	u32 location =0;

	if (file->is_readonly)
	{
		action->success = 0;
		return;
	}
	//printf("%f:WACK\n",when());
	//
	action->respond = 0;

	sectorSize = set_location_offset(driveNumber, sector, &location);

	unsigned char checksum = 0;
	unsigned char expchk = 0;
	int i;
	
	if(!pbi)
	{
		for (i=0;i!=sectorSize;++i)
		{
			//unsigned char temp = 
			action->sector_buffer[i] = USART_Receive_Byte(); // temp;
			//printf("%02x",temp);
		}
		checksum = USART_Receive_Byte();
		//hexdump_pure(atari_sector_buffer,sectorSize); // Somehow with this...
		expchk = get_checksum(&action->sector_buffer[0], sectorSize);
	}
	//printf("DATA:%d:",sectorSize);
	//printf("%f:CHK:%02x EXP:%02x %s\n", when(), checksum, expchk, checksum!=expchk ? "BAD" : "");
	//printf(" %d",atari_sector_buffer[0]); // and this... The wrong checksum is sent!!
	//printf(":done\n");
	if (checksum==expchk)
	{
		if(!pbi)
		{
			send_ACK();
			DELAY_T2_MIN;
		}
		//printf("%f:WACK data\n",when());
		//printf("%d",location);
		//printf("\n");
		file_seek(file, location);
		int written = 0;
		if(drive_infos[driveNumber].info & INFO_SS)
		{
			u08 step = 512 / drive_infos[driveNumber].sector_size;
			i = 0;
			sectorSize = ATARI_SECTOR_BUFFER_SIZE;
			memset8(atari_sector_buffer, 0, sectorSize);
			while(written < sectorSize)
			{
				atari_sector_buffer[written] = action->sector_buffer[i++];
				written += step;
			}
			file_write(file, atari_sector_buffer, sectorSize, &written);
		}
		else
		{
			file_write(file,&action->sector_buffer[0], sectorSize, &written);
		}

		int ok = 1;

		if (command.command == 0x57)
		{
			unsigned char buffer[512];
			int read;
			file_seek(file, location);
			file_read(file, buffer, sectorSize, &read);

			for (i=0;i!=sectorSize;++i)
			{
				if (buffer[i] != action->sector_buffer[i]) ok = 0;
			}
		}

		if(pbi)
		{
			action->success = ok;
		}
		else
		{
			DELAY_T5_MIN;
			
			if (ok)
			{
				//printf("%f:CMPL\n",when());
				send_CMPL();
			}
			else
			{
				//printf("%f:NACK(verify failed)\n",when());
				send_ERR();
			}
		}
	}
	else
	{
		//printf("%f:NACK(bad checksum)\n",when());
		send_NACK();
	}
	set_drive_led_off();
}

// As MiSTer does not pass on the original file name we
// use a dummy one for XEX disk images
const unsigned char cfile_name[] = {'F','I','L','E','N','A','M','E','X','E','X'};

void handleRead(struct command command, int driveNumber, struct SimpleFile * file, struct sio_action * action)
{
	set_drive_led_on();
	
	u32 sector = (command.auxab << 16) | command.aux1 | (command.aux2<<8);

	int read = 0;
	u32 location = 0;

	if(drive_infos[driveNumber].custom_loader == 1)
	{
		u08 i, b;
		int file_sectors;

		//printf("XEX ");

		if (sector<=2)
		{
			memcp8(&boot_xex_loader[(u16)(sector-1)*((u16)XEX_SECTOR_SIZE)], action->sector_buffer, 0, XEX_SECTOR_SIZE);
		}
		else
		if(sector==0x168)
		{
			file_sectors = drive_infos[driveNumber].sector_count;
			int vtoc_sectors = file_sectors / 1024;
			int rem = file_sectors - (vtoc_sectors * 1024);
			if(rem > 943) {
				vtoc_sectors += 2;
			}
			else if(rem)
			{
				vtoc_sectors++;
			}
			if(!(vtoc_sectors % 2))
			{
				vtoc_sectors++;
			} 
				
			file_sectors -= (vtoc_sectors + 12);
			action->sector_buffer[0] = (u08)((vtoc_sectors + 3)/2);
			goto set_number_of_sectors_to_buffer_1_2;
		}
		else
		if(sector==0x169)
		{
			file_sectors = drive_infos[driveNumber].sector_count - 0x173;

			memcp8(cfile_name, &action->sector_buffer[5], 0, 11);
			memset8(&action->sector_buffer[16], 0, XEX_SECTOR_SIZE-16);

			action->sector_buffer[0]=(file_sectors > 0x28F) ? 0x46 : 0x42; //0

			action->sector_buffer[3] = 0x71;
			action->sector_buffer[4] = 0x01;
set_number_of_sectors_to_buffer_1_2:
			action->sector_buffer[1] = file_sectors;
			action->sector_buffer[2] = (file_sectors >> 8);
		}
		else
		if(sector>=0x171)
		{
			file_seek(file,((u32)sector-0x171)*((u32)XEX_SECTOR_SIZE-3));
			file_read(file, action->sector_buffer, XEX_SECTOR_SIZE-3, &read);

			if(read<(XEX_SECTOR_SIZE-3))
				sector=0; //je to posledni sektor
			else
				sector++; //ukazatel na dalsi

			action->sector_buffer[XEX_SECTOR_SIZE-3] = (sector>>8);
			action->sector_buffer[XEX_SECTOR_SIZE-2] = sector;
			action->sector_buffer[XEX_SECTOR_SIZE-1] = read;
		}

		action->bytes = XEX_SECTOR_SIZE;
	}
	else if (drive_infos[driveNumber].custom_loader == 2)
	{
		gAtxFile = file;
		pre_ce_delay = 0; // Taken care of in loadAtxSector
		int res = loadAtxSector(driveNumber, sector, &drive_infos[driveNumber].atari_sector_status);

		action->bytes = drive_infos[driveNumber].sector_size;
		action->success = (res == 0);

		// Are existing default delays workable or do they need removing?
	}
	else
	{
		action->bytes = set_location_offset(driveNumber, sector, &location);
		file_seek(file, location);
		if(drive_infos[driveNumber].info & INFO_SS)
		{
			u08 step = 512 / drive_infos[driveNumber].sector_size;
			file_read(file, atari_sector_buffer, ATARI_SECTOR_BUFFER_SIZE, &read);
			read = 0;
			int n = 0;
			while(read < ATARI_SECTOR_BUFFER_SIZE)
			{
				action->sector_buffer[n++] = atari_sector_buffer[read];
				read += step;
			}
		}
		else
		{
			file_read(file, &action->sector_buffer[0], action->bytes, &read);			
		}
	}

	set_drive_led_off();
}

CommandHandler getCommandHandler(struct command command, u08 dstats)
{
	CommandHandler res = 0;
	u32 sector = (command.auxab << 16) | command.aux1 | (command.aux2<<8);
	// The HDD SD card counts sectors from 0
	u08 min_sector = (command.deviceId & 0x3F) == 0x20 ? 0 : 1;
	int driveNumber = min_sector ? (command.deviceId & 0xf) - 1 : MAX_DRIVES;
	u08 pbi = command.deviceId & 0x40;

	switch (command.command)
	{
	case 0x3f:
		if(!pbi)
			res = &handleSpeed;
		break;
	case 0x21: // format single
	case 0x22: // format enhanced
		if(!pbi)
			res = &handleFormat;
		break;
	case 0x46:
		if(pbi)
			res = &handleForceMediaChange;
		break;
	case 0x4e: // read percom block
		if(min_sector)
			res = &handleReadPercomBlock;
		break;
	case 0x53: // get status
		if(!pbi || dstats == 0x40)
			res = &handleGetStatus;
		break;
	case 0x50: // write
	case 0x57: // write with verify
		if ((!pbi || dstats == 0x80) && sector >= min_sector && sector - min_sector < drive_infos[driveNumber].sector_count)
			res = &handleWrite;
		break;
	case 0x52: // read
		if ((!pbi || dstats == 0x40) && sector >= min_sector && sector - min_sector < drive_infos[driveNumber].sector_count)
		{
			if(drive_infos[driveNumber].custom_loader == 2) // ATX!
			{
				pre_an_delay = 3220;
			}
			res = &handleRead;
		}
		break;
	case 0x6E: // PBI device info
		if(pbi && dstats == 0x40)
			res = &handleDeviceInfo;
		break;
/*
	case 0xEC: // PBI device status
		if(pbi && dstats == 0x40)
			res = &handleDeviceStatus;
		break;
*/
	}

	return res;
}
	
unsigned char get_checksum(unsigned char* buffer, int len)
{
	u16 i;
	u08 sumo,sum;
	sum=sumo=0;
	for(i=0;i<len;i++)
	{
		sum+=buffer[i];
		if(sum<sumo) sum++;
		sumo = sum;
	}
	return sum;
}

void USART_Send_Buffer(unsigned char *buff, u16 len)
{
	while(len>0) { USART_Transmit_Byte(*buff++); len--; }
}

void USART_Send_cmpl_and_atari_sector_buffer_and_check_sum(unsigned char *sector_buffer, unsigned short len, int success)
{
	u08 check_sum;
	//printf("(send:");
	//printf("%d",len);

	wait_us(pre_ce_delay);
	// DELAY_T5_MIN;
	//printf("%f:CMPL\n",when());
	if (success)
	{
		send_CMPL();
	}
	else
	{
		send_ERR();
	}

	// Hias: changed to 100us so that Qmeg3 works again with the
	// new bit-banging transmission code
	DELAY_T3_PERIPH;

	//check_sum = 0;
	//printf("%f:SendBuffer\n",when());
	USART_Send_Buffer(sector_buffer, len);
	// tx_checksum is updated by bit-banging USART_Transmit_Byte,
	// so we can skip separate calculation
	check_sum = get_checksum(sector_buffer, len);
	USART_Transmit_Byte(check_sum);
	//printf("%f:Done\n",when());
	//hexdump_pure(atari_sector_buffer,len);
	/*printf(":chk:");
	printf("%d",check_sum);
	printf(")");*/
}
