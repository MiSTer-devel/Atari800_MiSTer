#ifndef UART_H
#define UART_H

#include "integer.h"

// Might be simplest to use another Pokey as the UART...

void USART_Init( u08 value ); // value is baud rate
// must flush too

void USART_Transmit_Byte( unsigned char data );
unsigned char USART_Receive_Byte( void );

int USART_Data_Ready();

void USART_Transmit_Mode();
void USART_Receive_Mode();

int USART_Framing_Error();

void USART_Wait_Transmit_Complete();

int USART_Command_Line();

#endif
