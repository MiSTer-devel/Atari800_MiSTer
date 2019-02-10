#ifndef UART_H
#define UART_H

#include "integer.h"

void USART_Init( u08 value ); // value is baud rate

void USART_Transmit_Byte( unsigned char data );
u32 USART_Receive_Byte( void );

int USART_Framing_Error();

#endif
