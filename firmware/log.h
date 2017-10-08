#ifndef LOG_H
#define LOG_H

#ifdef LINUX_BUILD
#include "curses_screen.h"
#define LOG(x...) print_log(x)
#else
#define LOG(x...) do { } while(0)
#endif

#endif
