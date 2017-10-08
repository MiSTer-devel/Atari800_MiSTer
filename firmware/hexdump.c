#include "hexdump.h"
#include "printf.h"

void hexdump_pure(void const * str, int length)
{
	for (;length>0;--length)
	{
		unsigned char val= *(unsigned char *)str++;
		printf("%02x",val);
	}
}
