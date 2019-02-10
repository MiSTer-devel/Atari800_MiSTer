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
#include "integer.h"

extern int debug_pos; // ARG!
extern unsigned char volatile * baseaddr;

#define send_ACK()	USART_Transmit_Byte('A');
#define send_NACK()	USART_Transmit_Byte('N');
#define send_CMPL()	USART_Transmit_Byte('C');
#define send_ERR()	USART_Transmit_Byte('E');

/* BiboDos needs at least 50us delay before ACK */
#define DELAY_T2_MIN wait_us(100);

/* the QMEG OS needs at least 300usec delay between ACK and complete */
#define DELAY_T5_MIN wait_us(300);

/* QMEG OS 3 needs a delay of 150usec between complete and data */
#define DELAY_T3_PERIPH wait_us(150);

#define speedslow 0x28
#define speedfast turbo_div()
int turbo_div();
static int init_done = 0;

#define XEX_SECTOR_SIZE 128

#define MAX_DRIVES 4

struct SimpleFile * drives[MAX_DRIVES];
unsigned char drive_info[MAX_DRIVES];
enum DriveInfo {DI_XD=0,DI_SD=1,DI_MD=2,DI_DD=3,DI_BITS=3,DI_RO=4};

//#ifdef SOCKIT
//double when()
//{
//	struct timeval tv;
//	gettimeofday(&tv,0);
//	double now = tv.tv_sec;
//	now += tv.tv_usec/1e6;
//	return now;
//}
//#endif

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
struct ATRHeader atr_header;
int offset;
char custom_loader;
int xex_size;

char speed;
char opendrive;

unsigned char atari_sector_status;

unsigned char atari_sector_buffer[256];

unsigned char get_checksum(unsigned char* buffer, int len);

#define    TWOBYTESTOWORD(ptr,val)           (*((u08*)(ptr)) = val&0xff);(*(1+(u08*)(ptr)) = (val>>8)&0xff);

void processCommand();
void USART_Send_cmpl_and_atari_sector_buffer_and_check_sum(unsigned short len, int success);
void clearAtariSectorBuffer()
{
	int i=256;
	while (--i)
		atari_sector_buffer[i] = 0;
}

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
//  relokacni tabulka neni potreba, meni se vsechny hodnoty 0x07
//  (melo by byt PRESNE 20 vyskytu! pokud je jich vic, pak bacha!!!)

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
	unsigned char cmdstat;
	int prob;
	prob = 0;
	while (1)
	{
		for (i=0;i!=5;++i)
		{
			u32 data = USART_Receive_Byte(); // Timeout?
			*zpu_uart_debug = i;
			*zpu_uart_debug = 1&(data>>8);
			*zpu_uart_debug = data&0xff;
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
			prob = 0;

			*zpu_uart_debug2 = 0xf0;
			// error
			continue;
		}

		*zpu_uart_debug = 0xba;
		USART_Receive_Byte();
		*zpu_uart_debug = 0xda;

		*zpu_uart_debug = *zpu_uart_divisor;

		atari_sector_buffer[0] = cmd->deviceId;
		atari_sector_buffer[1] = cmd->command;
		atari_sector_buffer[2] = cmd->aux1;
		atari_sector_buffer[3] = cmd->aux2;
		expchk = get_checksum(&atari_sector_buffer[0],4);

		//*zpu_uart_debug2 = expchk;
		//*zpu_uart_debug2 = cmd->chksum;

		if (expchk==cmd->chksum) {
			*zpu_uart_debug2 = 0x44;
			// got a command frame
			//
			switch_speed();
			break;
		} else {
			*zpu_uart_debug2 = 0xff;
			// just an invalid checksum, switch speed anyways
		}
	}

	DELAY_T2_MIN;
}

// Called whenever file changed
void set_drive_status(int driveNumber, struct SimpleFile * file)
{
	int read = 0;
	int xfd = 0;
	int atx = 0;
	unsigned char info = 0;

	drives[driveNumber] = 0;
	drive_info[driveNumber] = 0;

	*zpu_uart_debug2 = 0x11;

	if (!file) return;

	*zpu_uart_debug2 = 0x12;

	//printf("WTF:%d %x\n",driveNumber, file);

	// Read header
	read = 0;
	file_seek(file,0);
	*zpu_uart_debug2 = 0x23;
	file_read(file,(unsigned char *)&atr_header, 16, &read);
	*zpu_uart_debug2 = 0x33;
	if (read!=16)
	{
		//printf("Could not read header\n");
		return; //while(1);
	}

	*zpu_uart_debug2 = 0x13;

	byteswap(&atr_header.wMagic);
	byteswap(&atr_header.wPars);
	byteswap(&atr_header.wSecSize);
	/*printf("\nHeader:");
	printf("%d",atr_header.wMagic);
	plotnext(toatarichar(' '));
	printf("%d",atr_header.wPars);
	plotnext(toatarichar(' '));
	printf("%d",atr_header.wSecSize);
	plotnext(toatarichar(' '));
	printf("%d",atr_header.btParsHigh);
	plotnext(toatarichar(' '));
	printf("%d",atr_header.dwCRC);
	printf("\n");
	*/

	custom_loader = 0;
	atari_sector_status = 0xff;

	if (file_type(file) == 2)
	{
		//printf("XFD ");
		// build a fake atr header
		offset = 0;
		atr_header.wMagic = 0x296;
		atr_header.wPars = file_size(file)/16;
		atr_header.wSecSize = 0x80;
		atr_header.btFlags |= file_readonly(file);
	}
	if (file_type(file) == 3)
	{
		int i;
		unsigned char j;
		int k;
		int orig;
		u16 sectorSize;
		offset = -256;
		custom_loader = 2;
		atr_header.wMagic = 0xffff;
		xex_size = file_size(file);
		atr_header.wPars = xex_size/16;
		atr_header.wSecSize = XEX_SECTOR_SIZE;
		atr_header.btFlags = 1;

		gAtxFile = file;
		sectorSize = loadAtxFile(0);
	}
	else if (atr_header.wMagic == 0xFFFF) // XEX
	{
		int i;
		//printf("XEX ");
		offset = -256;
		custom_loader = 1;
		atr_header.wMagic = 0xffff;
		xex_size = file_size(file);
		atr_header.wPars = xex_size/16;
		atr_header.wSecSize = XEX_SECTOR_SIZE;
		atr_header.btFlags = 1;
	}
	else if (atr_header.wMagic == 0x296) // ATR
	{
		//printf("ATR ");
		offset = 16;
		atr_header.btFlags |= file_readonly(file);
	}
	else
	{
		//printf("Unknown file type");
		return;
	}

	*zpu_uart_debug2 = 0x14;

	if (atr_header.btFlags&1)
	{
		info |= DI_RO;
	}

	if (atr_header.wSecSize == 0x80)
	{
		if (atr_header.wPars>(720*128/16))
			info |= DI_MD;
		else
			info |= DI_SD;
	}
	else if (atr_header.wSecSize == 0x100)
	{
		info |= DI_DD;
	}
	else if (atr_header.wSecSize < 0x100)
	{
		info |= DI_XD;
	}
	else
	{
		//printf("BAD sector size");
		return;
	}	
	//printf("%d",atr_header.wPars);
	//printf("0\n");
	//
	*zpu_uart_debug2 = 0x15;

	drives[driveNumber] = file;
	drive_info[driveNumber] = info;
	//printf("appears valid\n");
}

struct SimpleFile * get_drive_status(int driveNumber)
{
	return drives[driveNumber];
}

void init_drive_emulator()
{
	int i;

	opendrive = -1;
	speed = speedslow;
	USART_Init(speed+6);
	for (i=0; i!=MAX_DRIVES; ++i)
	{
		drives[i] = 0;
	}
}

void run_drive_emulator()
{
	while (1)
	{
		processCommand();
	}
}

/////////////////////////

struct sio_action
{
	int bytes;
	int success;
	int speed;
	int respond;
};

typedef void (*CommandHandler)(struct command, struct SimpleFile *, struct sio_action *);
CommandHandler  getCommandHandler(struct command);

void processCommand()
{
	struct command command;

	getCommand(&command);

	if (command.deviceId >= 0x31 && command.deviceId <= 0x34)
	{
		int drive = 0;
		struct SimpleFile * file = 0;

		drive = (command.deviceId&0xf) -1;
	//	printf("Drive:");
	//	printf("%x %d",command.deviceId,drive);

		if (drive<0 || !drives[drive])
		{
			//send_NACK();
			//wait_us(100); // Wait for transmission to complete - Pokey bug, gets stuck active...

			//printf("Drive not present:%d %x", drive, drives[drive]);
			//
			//
			*zpu_uart_debug2 = 0x16;
			return;
		}

		*zpu_uart_debug3 = command.command;

		file = drives[opendrive];

		CommandHandler handleCommand = getCommandHandler(command);
		DELAY_T2_MIN;
		if (handleCommand)
		{
			struct sio_action action;
			action.bytes = 0;
			action.success = 1;
			action.speed = -1;
			action.respond = 1;

			send_ACK();
			clearAtariSectorBuffer();


			if (drive!=opendrive)
			{
				*zpu_uart_debug3 = drive;
				if (drive<MAX_DRIVES && drive>=0)
				{
					opendrive = drive;
					set_drive_status(drive, drives[drive]);
					//printf("HERE!:%d\n",drive);
				}
			}

			handleCommand(command, drives[drive], &action); //TODO -> this should respond with more stuff and we handle result in a common way...

			if (action.respond)
				USART_Send_cmpl_and_atari_sector_buffer_and_check_sum(action.bytes, action.success);
			if (action.speed>=0)
				USART_Init(action.speed); // Wait until fifo is empty - then set speed!
		}
		else
		{
			send_NACK();
		}
	}
}

void handleSpeed(struct command command, struct SimpleFile * file, struct sio_action * action)
{
	//printf("Speed:");
	int sector = ((int)command.aux2)<<8;
	atari_sector_buffer[0] = speedfast;
	//hexdump_pure(atari_sector_buffer,1);
	action->bytes = 1;

	if (sector == 0)
	{
		speed = speedfast;
		//printf("SPDF");
		//printf("%d",speed);
	}
	else
	{
		speed = speedslow;
		//printf("SPDS");
		//printf("%d",speed);
	}

	action->speed = speed +6;
}

void handleFormat(struct command command,struct  SimpleFile * file, struct sio_action * action)
{
	if (atr_header.btFlags&1)
	{
		// fail, write protected
		action->success = 0;
	}
	else
	{
		int i;
		int pos = offset;

		// fill image with zeros
		int written = 0;
		for (i=0; i!=(atr_header.wPars>>3); ++i)
		{
			file_seek(file,pos);
			file_write(file,&atari_sector_buffer[0], 128, &written);
			pos+=128;
		}
		file_write_flush();

		// return done
		atari_sector_buffer[0] = 0xff;
		atari_sector_buffer[1] = 0xff;
		for(i=2;i!=atr_header.wSecSize; ++i)
		{
			atari_sector_buffer[i] = 0;
		}

		action->bytes=atr_header.wSecSize;
	}
}

void handleReadPercomBlock(struct command command, struct SimpleFile * file, struct sio_action * action)
{
	unsigned totalSectors = (atr_header.wPars<<4)/atr_header.wSecSize;
	//printf("Stat:");

	atari_sector_buffer[0] = 1;
	atari_sector_buffer[1] = 11;
	atari_sector_buffer[2] = totalSectors>>8;
	atari_sector_buffer[3] = totalSectors&0xff;
	atari_sector_buffer[5] = (atr_header.wSecSize==256) ? 4 : 0;
	atari_sector_buffer[6] = atr_header.wSecSize>>8;
	atari_sector_buffer[7] = atr_header.wSecSize&0xff;
	atari_sector_buffer[8] = 0x0ff;
	//hexdump_pure(atari_sector_buffer,12); // Somehow with this...
	
	action->bytes = 12;
	//printf("%d",atari_sector_buffer[0]); // and this... The wrong checksum is sent!!
	//printf(":done\n");
}

void handleGetStatus(struct command command, struct SimpleFile * file, struct sio_action * action)
{
	unsigned char status;
	//printf("Stat:");

	status = 0x10; // Motor on;
	if (atr_header.btFlags&1)
	{
		status |= 0x08; // write protected; // no write support yet...
	}
	if (atr_header.wSecSize == 0x80) // normal sector size
	{
		if (atr_header.wPars>(720*128/16))
		{
			status |= 0x80; // medium density - or a strange one...
		}
	}
	else
	{
		status |= 0x20; // 256 byte sectors
	}
	atari_sector_buffer[0] = status;
	atari_sector_buffer[1] = atari_sector_status;
	atari_sector_buffer[2] = 0xe0;
	atari_sector_buffer[3] = 0x0;
	//hexdump_pure(atari_sector_buffer,4); // Somehow with this...
	
	action->bytes = 4;
	//printf("%d",atari_sector_buffer[0]); // and this... The wrong checksum is sent!!
	//printf(":done\n");
}

void handleWrite(struct command command, struct SimpleFile * file, struct sio_action * action)
{
	//debug_pos = 0;

	int sector = ((int)command.aux1) + (((int)command.aux2)<<8);
	int sectorSize = 0;
	int location =0;

	if (file_readonly(file))
	{
		action->success = 0;
		return;
	}
	//printf("%f:WACK\n",when());
	//
	action->respond = 0;

	location = offset;
	if (sector>3)
	{
		sector-=4;
		location += 128*3;
		location += sector*atr_header.wSecSize;
		sectorSize = atr_header.wSecSize;
	}
	else
	{
		location += 128*(sector-1);
		sectorSize = 128;
	}

	// Receive the data
	//printf("%f:Getting data\n",when());
	int i;
	for (i=0;i!=sectorSize;++i)
	{
		unsigned char temp = USART_Receive_Byte();
		atari_sector_buffer[i] = temp;
		//printf("%02x",temp);
	}
	unsigned char checksum = USART_Receive_Byte();
	//hexdump_pure(atari_sector_buffer,sectorSize); // Somehow with this...
	unsigned char expchk = get_checksum(&atari_sector_buffer[0],sectorSize);
	//printf("DATA:%d:",sectorSize);
	//printf("%f:CHK:%02x EXP:%02x %s\n", when(), checksum, expchk, checksum!=expchk ? "BAD" : "");
	//printf(" %d",atari_sector_buffer[0]); // and this... The wrong checksum is sent!!
	//printf(":done\n");
	if (checksum==expchk)
	{
		send_ACK();

		DELAY_T2_MIN
		//printf("%f:WACK data\n",when());
		//printf("%d",location);
		//printf("\n");
		file_seek(file,location);
		int written = 0;
		file_write(file,&atari_sector_buffer[0], sectorSize, &written);

		int ok = 0;

		if (command.command == 0x57)
		{
			unsigned char buffer[256];
			int read;
			file_seek(file,location);
			file_read(file,buffer,sectorSize,&read);

			ok = 1;
			for (i=0;i!=sectorSize;++i)
			{
				if (buffer[i] != atari_sector_buffer[i]) ok = 0;
			}
		}
		else
			ok = 1;

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
	else
	{
		//printf("%f:NACK(bad checksum)\n",when());
		send_NACK();
	}
}

void handleRead(struct command command, struct SimpleFile * file, struct sio_action * action)
{
	int sector = ((int)command.aux1) + (((int)command.aux2)<<8);

	int read = 0;
	int location =0;


	//printf("Sector:");
	//printf("%d",sector);
	//printf(":");
	if(custom_loader==1)         //n_sector>0 && //==0 se overuje hned na zacatku
	{
		//sektory xex bootloaderu, tj. 1 nebo 2
		u08 i,b;
		u08 *spt, *dpt;
		int file_sectors;

		//file_sectors se pouzije pro sektory $168 i $169 (optimalizace)
		//zarovnano nahoru, tj. =(size+124)/125
		file_sectors = ((xex_size+(u32)(XEX_SECTOR_SIZE-3-1))/((u32)XEX_SECTOR_SIZE-3));

		//printf("XEX ");

		if (sector<=2)
		{
			//printf("boot ");

			spt= &boot_xex_loader[(u16)(sector-1)*((u16)XEX_SECTOR_SIZE)];
			dpt= atari_sector_buffer;
			i=XEX_SECTOR_SIZE;
			do
			{
				b=*spt++;
				//relokace bootloaderu z $0700 na jine misto
				//TODO if (b==0x07) b+=bootloader_relocation;
				*dpt++=b;
				i--;
			} while(i);
		}
		else
		if(sector==0x168)
		{
			//printf("numtobuffer ");
			//vrati pocet sektoru diskety
			//byty 1,2
			goto set_number_of_sectors_to_buffer_1_2;
		}
		else
		if(sector==0x169)
		{
			//printf("name ");
			//fatGetDirEntry(FileInfo.vDisk.file_index,5,0);
			//fatGetDirEntry(FileInfo.vDisk.file_index,0); //ale musi to posunout o 5 bajtu doprava

			{
				u08 i,j;
				for(i=j=0;i<8+3;i++)
				{
					/*if( ((xex_name[i]>='A' && xex_name[i]<='Z') ||
						(xex_name[i]>='0' && xex_name[i]<='9')) )
					{
					  //znak je pouzitelny na Atari
					  atari_sector_buffer[j]=xex_name[i];
					  j++;
					}*/
					if ( (i==7) || (i==8+2) )
					{
						for(;j<=i;j++) atari_sector_buffer[j]=' ';
					}
				}
				//posune nazev z 0-10 na 5-15 (0-4 budou systemova adresarova data)
				//musi pozpatku
				for(i=15;i>=5;i--) atari_sector_buffer[i]=atari_sector_buffer[i-5];
				//a pak uklidi cely zbytek tohoto sektoru
				for(i=5+8+3;i<XEX_SECTOR_SIZE;i++)
					atari_sector_buffer[i]=0x00;
			}

			//teprve ted muze pridat prvnich 5 bytu na zacatek nulte adresarove polozky (pred nazev)
			//atari_sector_buffer[0]=0x42;							//0
			//jestlize soubor zasahuje do sektoru cislo 1024 a vic,
			//status souboru je $46 misto standardniho $42
			atari_sector_buffer[0]=(file_sectors>(0x400-0x171))? 0x46 : 0x42; //0

			TWOBYTESTOWORD(atari_sector_buffer+3,0x0171);			//3,4
set_number_of_sectors_to_buffer_1_2:
			TWOBYTESTOWORD(atari_sector_buffer+1,file_sectors);		//1,2
		}
		else
		if(sector>=0x171)
		{
			//printf("data ");
			file_seek(file,((u32)sector-0x171)*((u32)XEX_SECTOR_SIZE-3));
			file_read(file,&atari_sector_buffer[0], XEX_SECTOR_SIZE-3, &read);

			if(read<(XEX_SECTOR_SIZE-3))
				sector=0; //je to posledni sektor
			else
				sector++; //ukazatel na dalsi

			atari_sector_buffer[XEX_SECTOR_SIZE-3]=((sector)>>8); //nejdriv HB !!!
			atari_sector_buffer[XEX_SECTOR_SIZE-2]=((sector)&0xff); //pak DB!!! (je to HB,DB)
			atari_sector_buffer[XEX_SECTOR_SIZE-1]=read;
		}
		//printf(" sending\n");

		action->bytes = XEX_SECTOR_SIZE;
	}
	else if (custom_loader==2)
	{
		gAtxFile = file;
		unsigned short ss;
		int res = loadAtxSector(0,sector, &ss, &atari_sector_status);

		action->bytes = ss;
		action->success = res;

		// Are existing default delays workable or do they need removing?
		// What if put into drive 3/4? Boom?
	}
	else
	{
		location = offset;
		if (sector>3)
		{
			sector-=4;
			location += 128*3;
			location += sector*atr_header.wSecSize;
			action->bytes = atr_header.wSecSize;
		}
		else
		{
			location += 128*(sector-1);
			action->bytes = 128;
		}
		//printf("%d",location);
		//printf("\n");
		//printf("%f:Read\n",when());
		file_seek(file,location);
		file_read(file,&atari_sector_buffer[0], action->bytes, &read);
		//printf("%f:Read done\n",when());
	}

	//topofscreen();
	//hexdump_pure(atari_sector_buffer,sectorSize);
	//printf("Sending\n");

	//pause_6502(1);
	//hexdump_pure(0x10000+0x400,128);
	//get_checksum(0x10000+0x400, sectorSize);
	//printf(" receive:");
	//printf("%d",chksumreceive);
	//printf("\n");
	//pause_6502(1);
	//while(1);
}

CommandHandler getCommandHandler(struct command command)
{
	CommandHandler res = 0;
	int sector = ((int)command.aux1) + (((int)command.aux2)<<8);

	switch (command.command)
	{
	case 0x3f:
		res = &handleSpeed;
		break;
	case 0x21: // format single
	case 0x22: // format enhanced
		res = &handleFormat;
		break;
	case 0x4e: // read percom block
		res = &handleReadPercomBlock;
		break;
	case 0x53: // get status
		res = &handleGetStatus;
		break;
	case 0x50: // write
	case 0x57: // write with verify
		if (sector!=0)
			res = &handleWrite;
		break;
	case 0x52: // read
		if (sector!=0)
			res = &handleRead;
		break;
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

		//printf("c:%02x:",sumo);
	}
	return sum;
}

void USART_Send_Buffer(unsigned char *buff, u16 len)
{
	while(len>0) { USART_Transmit_Byte(*buff++); len--; }
}

void USART_Send_cmpl_and_atari_sector_buffer_and_check_sum(unsigned short len, int success)
{
	u08 check_sum;
	//printf("(send:");
	//printf("%d",len);

	DELAY_T5_MIN;
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

	check_sum = 0;
	//printf("%f:SendBuffer\n",when());
	USART_Send_Buffer(atari_sector_buffer,len);
	// tx_checksum is updated by bit-banging USART_Transmit_Byte,
	// so we can skip separate calculation
	check_sum = get_checksum(atari_sector_buffer,len);
	USART_Transmit_Byte(check_sum);
	//printf("%f:Done\n",when());
	//hexdump_pure(atari_sector_buffer,len);
	/*printf(":chk:");
	printf("%d",check_sum);
	printf(")");*/
}

void describe_disk(int driveNumber, char * buffer)
{
	if (drives[driveNumber]==0)
	{
		buffer[0] = 'N';
		buffer[1] = 'O';
		buffer[2] = 'N';
		buffer[3] = 'E';
		buffer[4] = '\0';
		return;
	}
//enum DriveInfo {DI_XD=0,DI_SD=1,DI_MD=2,DI_DD=3,DI_BITS=3,DI_RO=4};
	unsigned char info = drive_info[driveNumber];
	buffer[0] = 'R';
	buffer[1] = info&DI_RO ? 'O' : 'W';
	buffer[2] = ' ';
	unsigned char density;
	switch (info&3)
	{
	case DI_XD:
		density = 'X';
		break;
	case DI_SD:
		density = 'S';
		break;
	case DI_MD:
		density = 'M';
		break;
	case DI_DD:
		density = 'D';
		break;
	}
	buffer[3] = density;
	buffer[4] = 'D';
	buffer[5] = '\0';
}

int turbo_div()
{
	static int turbodivs[] = 
	{
		speedslow,
		0x6,
		0x5,
		0x4,
		0x3,
		0x2,
		0x1,
		0x0
	};
	return turbodivs[get_speeddrv()];
}

void set_turbo_drive(int pos)
{
}

int get_turbo_drive()
{
	return get_speeddrv();
}

char const * get_turbo_drive_str()
{
	static char const * turbostr[] = 
	{
		"Standard",
		"Fast(6)",
		"Fast(5)",
		"Fast(4)",
		"Fast(3)",
		"Fast(2)",
		"Fast(1)",
		"Fast(0)"
	};
	return turbostr[get_speeddrv()];
}
