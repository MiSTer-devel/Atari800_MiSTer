#include "printf.h"

#include "utils.h"

int compare_ext(char const * filename, char const * ext)
{
	int dot = 0;
	//printf("WTFA:%s %s\n",filenamein, extin);
	//printf("WTFB:%s %s\n",filename, ext);

	char const * end = strlen(filename) + filename;
	while (--end != filename)
	{
		if (*end == '.')
			break;
	}
	if (0==stricmp(end+1,ext)) return 1;

	return 0;
}

