/*-------------------------------------------*/
/* Integer type definitions for FatFs module */
/*-------------------------------------------*/

#ifndef _FF_INTEGER
#define _FF_INTEGER

#ifdef _WIN32	/* FatFs development platform */

#include <windows.h>
#include <tchar.h>

#else			/* Embedded platform */

/* This type MUST be 8 bit */
typedef unsigned char	BYTE;
typedef unsigned char	u08;
typedef unsigned char	uint8_t;

typedef signed char	int8_t;

/* These types MUST be 16 bit */
typedef short			SHORT;
typedef unsigned short	WORD;
typedef unsigned short	WCHAR;
typedef unsigned short	u16;
typedef unsigned short	uint16_t;

typedef signed short	int16_t;

/* These types MUST be 16 bit or 32 bit */
typedef int				INT;
typedef unsigned int	UINT;

/* These types MUST be 32 bit */
typedef long			LONG;
typedef unsigned int	DWORD;
typedef unsigned int u32;
typedef unsigned int uint32_t;

typedef uint8_t bool;
typedef uint8_t BOOL;
#define false (0)
#define FALSE (0)
#define NULL (0)
#define true (1)
#define TRUE (1)

#endif

#endif
