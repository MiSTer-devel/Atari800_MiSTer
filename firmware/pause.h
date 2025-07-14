#ifndef PAUSE_H
#define PAUSE_H

// void wait_us(int unsigned num);

#define wait_us(x) *zpu_pause = (x)

#endif
