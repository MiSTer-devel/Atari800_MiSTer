#ifndef regs_h
#define regs_h
#include "memory.h"

static const int screen_address = 11328;

#define zpu_in1 ((int volatile *)(0*4+zpu_regbase))
#define zpu_in2 ((int volatile *)(1*4+zpu_regbase))
#define zpu_in3 ((int volatile *)(2*4+zpu_regbase))
#define zpu_in4 ((int volatile *)(3*4+zpu_regbase))

#define zpu_out1 ((int volatile *)(4*4+zpu_regbase))
#define zpu_out2 ((int volatile *)(5*4+zpu_regbase))
#define zpu_out3 ((int volatile *)(6*4+zpu_regbase))
#define zpu_out4 ((int volatile *)(7*4+zpu_regbase))
#define zpu_out5 ((int volatile *)(14*4+zpu_regbase))
#define zpu_out6 ((int volatile *)(15*4+zpu_regbase))

#define zpu_pause ((u32 volatile *)(8*4+zpu_regbase))
#define zpu_timer ((u32 volatile *)(8*4+zpu_regbase))

#define zpu_spi_data ((int volatile *)(9*4+zpu_regbase))
#define zpu_spi_state ((int volatile *)(10*4+zpu_regbase))

#define zpu_sio ((int volatile *)(11*4+zpu_regbase))

#define zpu_board ((int volatile *)(12*4+zpu_regbase))

#define zpu_spi_dma ((int volatile *)(13*4+zpu_regbase))

// read number of us
#define zpu_timer2 ((u32 volatile *)(18*4+zpu_regbase))
// reset timer if > this many us (stored)
#define zpu_timer2_threshold ((u32 volatile *)(18*4+zpu_regbase))

// 8-bit random number lsfr
#define zpu_rand ((int volatile *)(19*4+zpu_regbase))

#define zpu_uart_tx ((u32 volatile *)(0x0*4+pokey_regbase))
#define zpu_uart_tx_fifo ((u32 volatile *)(0x1*4+pokey_regbase))
#define zpu_uart_rx ((u32 volatile *)(0x2*4+pokey_regbase))
#define zpu_uart_rx_fifo ((u32 volatile *)(0x3*4+pokey_regbase))
#define zpu_uart_divisor ((u32 volatile *)(0x4*4+pokey_regbase))
#define zpu_uart_framing_error ((u32 volatile *)(0x5*4+pokey_regbase))
#define zpu_uart_debug ((u32 volatile *)(0x7*4+pokey_regbase))
#define zpu_uart_debug2 ((u32 volatile *)(0x8*4+pokey_regbase))
#define zpu_uart_debug3 ((u32 volatile *)(0x9*4+pokey_regbase))

#define atari_nmien ((unsigned char volatile *)(0xd40e + atari_regbase))
#define atari_dlistl ((unsigned char volatile *)(0xd402 + atari_regbase))
#define atari_dlisth ((unsigned char volatile *)(0xd403 + atari_regbase))

#define atari_porta ((unsigned char volatile *)(0xd300 + atari_regbase))
#define atari_portb ((unsigned char volatile *)(0xd301 + atari_regbase))
#define atari_chbase ((unsigned char volatile *)(0xd409 + atari_regbase))
#define atari_chactl ((unsigned char volatile *)(0xd401 + atari_regbase))
#define atari_dmactl ((unsigned char volatile *)(0xd400 + atari_regbase))

#define atari_cartswitch ((unsigned char volatile *)(0xd500 + atari_regbase))

#define atari_coldst ((unsigned char volatile *)(0x244 + atari_regbase))
#define atari_basicf ((unsigned char volatile *)(0x3F8 + atari_regbase))
#define atari_gintlk ((unsigned char volatile *)(0x3FA + atari_regbase))
#define atari_pupbt1 ((unsigned char volatile *)(0x33D + atari_regbase))
#define atari_pupbt2 ((unsigned char volatile *)(0x33E + atari_regbase))
#define atari_pupbt3 ((unsigned char volatile *)(0x33F + atari_regbase))
#define atari_bootflag ((unsigned char volatile *)(0x09 + atari_regbase))
#define atari_casinil ((unsigned char volatile *)(0x02 + atari_regbase))  
#define atari_casinih ((unsigned char volatile *)(0x03 + atari_regbase))
#define atari_dosvecl ((unsigned char volatile *)(0x0A + atari_regbase))  
#define atari_dosvech ((unsigned char volatile *)(0x0B + atari_regbase))
#define atari_runadl ((unsigned char volatile *)(0x2E0 + atari_regbase))  
#define atari_runadh ((unsigned char volatile *)(0x2E1 + atari_regbase))
#define atari_initadl ((unsigned char volatile *)(0x2E2 + atari_regbase))  
#define atari_initadh ((unsigned char volatile *)(0x2E3 + atari_regbase))

#ifdef FIRMWARE_5200
// 5200: GTIA and POKEY are on different addresses
#define atari_colbk ((unsigned char volatile *)(0xc01a + atari_regbase))
#define atari_colpf1 ((unsigned char volatile *)(0xc017 + atari_regbase))
#define atari_colpf2 ((unsigned char volatile *)(0xc018 + atari_regbase))
#define atari_colpf3 ((unsigned char volatile *)(0xc019 + atari_regbase))
#define atari_colpf0 ((unsigned char volatile *)(0xc016 + atari_regbase))
#define atari_prior ((unsigned char volatile *)(0xc01b + atari_regbase))
#define atari_consol ((unsigned char volatile *)(0xc01f + atari_regbase))
#define atari_trig0 ((unsigned char volatile *)(0xc010 + atari_regbase))
#define atari_trig1 ((unsigned char volatile *)(0xc011 + atari_regbase))
#define atari_trig2 ((unsigned char volatile *)(0xc012 + atari_regbase))
#define atari_trig3 ((unsigned char volatile *)(0xc013 + atari_regbase))

#define atari_skctl ((unsigned char volatile *)(0xe80f + atari_regbase))
#define atari_kbcode ((unsigned char volatile *)(0xe809 + atari_regbase))
#define atari_random ((unsigned char volatile *)(0xe80a + atari_regbase))
#define atari_pot0 ((unsigned char volatile *)(0xe800 + atari_regbase))
#define atari_pot1 ((unsigned char volatile *)(0xe801 + atari_regbase))
#define atari_pot2 ((unsigned char volatile *)(0xe802 + atari_regbase))
#define atari_pot3 ((unsigned char volatile *)(0xe803 + atari_regbase))
#define atari_potgo ((unsigned char volatile *)(0xe80b + atari_regbase))
#define atari_allpot ((unsigned char volatile *)(0xe808 + atari_regbase))

#else

#define atari_colbk ((unsigned char volatile *)(0xd01a + atari_regbase))
#define atari_colpf1 ((unsigned char volatile *)(0xd017 + atari_regbase))
#define atari_colpf2 ((unsigned char volatile *)(0xd018 + atari_regbase))
#define atari_colpf3 ((unsigned char volatile *)(0xd019 + atari_regbase))
#define atari_colpf0 ((unsigned char volatile *)(0xd016 + atari_regbase))
#define atari_prior ((unsigned char volatile *)(0xd01b + atari_regbase))

#define atari_skctl ((unsigned char volatile *)(0xd20f + atari_regbase))
#define atari_kbcode ((unsigned char volatile *)(0xd209 + atari_regbase))
#define atari_random ((unsigned char volatile *)(0xd20a + atari_regbase))

#define atari_trig0 ((unsigned char volatile *)(0xd010 + atari_regbase))
#define atari_trig1 ((unsigned char volatile *)(0xd011 + atari_regbase))

#endif

#endif // regs_h
