#include "uart.h"

#include "regs.h"

void actions();

//-- 0 = transmit (w)
//-- 1 = tx fifo status (r)
//-- 2 = fetch/receive (r) - requests next data - i.e. first read trash
//-- 3 = rx fifo status (r)
//-- 4 = divisor (w)
//-- 5 = framing error/clear (r)
//		data_out(9 downto 0) <= fifo_rx_full&fifo_rx_empty&fifo_rx_count;

/*
void USART_Init( u08 value )
{
	// value is pokey div + 6
	u32 val2 = value;
	val2=val2<<1;

	val2=val2+1;
	*zpu_uart_divisor = val2;
}
*/

void USART_Transmit_Byte( unsigned char data )
{
	// wait until fifo not full
	while (0x200&*zpu_uart_tx_fifo) // fifo full
	{
		actions();
	}

	*zpu_uart_tx = data;
}
u32 USART_Receive_Byte( void )
{
	// wait for data
	while (0x100&*zpu_uart_rx_fifo) // fifo empty
	{
		actions();
	}

	u32 res = *zpu_uart_rx; //serin at same address
	return res;
}

/*
int USART_Framing_Error()
{
	return *zpu_uart_framing_error;
}
*/
