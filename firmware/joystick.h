#ifndef JOYSTICK_H
#define JOYSTICK_H

#define get_hotkey_settings() (*zpu_in1 & 0x00000800) 
#define get_controls() ((*zpu_in1 >> 12) & 0x3F)

struct joystick_status
{
	int x_;
	int y_;
	int fire_;
	int escape_;
};

enum JoyWait {WAIT_QUIET, WAIT_FIRE, WAIT_MOVE, WAIT_EITHER};

void joystick_poll(struct joystick_status * status);
void joystick_wait(struct joystick_status * status, enum JoyWait waitFor);

#endif
