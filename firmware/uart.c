#include "uart.h"

#include "regs.h"

void actions();

int USART_Data_Needed()
{
	int needed = 0==(0x10&(*zpu_pokey_irqen));
	if (needed)
	{
		*zpu_pokey_irqen = 0x28;
		*zpu_pokey_irqen = 0x38;
	}
	return needed;
}

int USART_Data_Ready()
{
	int ready = 0==(0x20&(*zpu_pokey_irqen));
	if (ready)
	{
		*zpu_pokey_irqen = 0x18;
		*zpu_pokey_irqen = 0x38;
	}
	return ready;
}

void USART_Init( u08 value )
{
	// value is pokey div + 6
	*zpu_pokey_skctl = 0;
	wait_us(10);
	USART_Receive_Mode(); // turn of reset and listen to commands
	*zpu_pokey_audctl = 0x78; // linked channels, fast clocked
	*zpu_pokey_audf1 = 0x00;
	*zpu_pokey_audf0 = value-6;
	*zpu_pokey_audf3 = 0x00;
	*zpu_pokey_audf2 = value-6;

	*zpu_pokey_irqen = 0x00;
	*zpu_pokey_irqen = 0x38;
}

void USART_Transmit_Byte( unsigned char data )
{
	*zpu_pokey_serout = data;

	// wait until next byte is needed 
	while (!USART_Data_Needed());
}
unsigned char USART_Receive_Byte( void )
{
	// wait for data
	while (!USART_Data_Ready())
	{
		actions();
	}

	u08 res = *zpu_pokey_serout; //serin at same address
	return res;
}

void USART_Transmit_Mode()
{
	*zpu_pokey_skctl = 0x23; // 010 for transmission
	*zpu_pokey_skrest = 0xff;
	*zpu_pokey_irqen = 0x28; // clear data needed
	*zpu_pokey_irqen = 0x38;
}

void USART_Receive_Mode()
{
	*zpu_pokey_skctl = 0x13; // 001 for receiving
	*zpu_pokey_skrest = 0xff;
}

int USART_Framing_Error()
{
	if (0x80&(*zpu_pokey_skctl))
	{
		return 0;
	}
	else
	{
		return 1;
	}
}

void USART_Wait_Transmit_Complete()
{
	while (1)
	{
		int ready = 0==(0x08&(*zpu_pokey_irqen));
		if (ready)
		{
			*zpu_pokey_irqen = 0x30;
			*zpu_pokey_irqen = 0x38;
			return;
		}
	}
}

int USART_Command_Line()
{
	return (1&(*zpu_sio));
}

