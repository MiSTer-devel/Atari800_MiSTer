#ifndef UART_H
#define UART_H

#include "integer.h"

//void USART_Init( u08 value ); // value is baud rate

#define USART_Init(v) *zpu_uart_divisor = ((v)<<1) +1

void USART_Transmit_Byte( unsigned char data );
u32 USART_Receive_Byte( void );

#define USART_Framing_Error() *zpu_uart_framing_error

//int USART_Framing_Error();

#endif
