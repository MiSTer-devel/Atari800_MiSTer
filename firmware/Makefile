BASE	= zpu-elf
CC      = $(BASE)-gcc
LD      = $(BASE)-gcc
AS      = $(BASE)-as
CP      = $(BASE)-objcopy
DUMP    = $(BASE)-objdump

SOCKIT_CC = arm-linux-gnueabihf-gcc
SOCKIT_LD = arm-linux-gnueabihf-gcc

SOCKIT_CFLAGS = -g -DLITTLE_ENDIAN -DSOCKIT -O2
SOCKIT_CFLAGS+= -W -Wall
SOCKIT_LDFLAGS = -g

HOST_CC	= gcc
HOST_LD	= gcc

HOST_CFLAGS	= -g -DLINUX_BUILD -DLITTLE_ENDIAN -fno-builtin
HOST_CFLAGS	+= -W -Wall
HOST_LDFLAGS	= -g

#HOST_CFLAGS	+= -m32
#HOST_LDFLAGS	+= -m32

HOST_CFLAGS	+= $(shell pkg-config --cflags ncurses)
HOST_LDFLAGS	+= $(shell pkg-config --libs ncurses)

# we use mincrt0.s from here
STARTUP_DIR = .

# we fetch ROM prologue / epilogue from here
RTL_DIR = $(ZPUFLEXDIR)/RTL/


BUILD_DIR=zpu_obj

AEON_LITE_DIR = aeon_lite
PAPILIODUO_DIR = papilioduo
DE1_DIR = de1
DE1_5200_DIR = de1_5200
CHAMELEON_DIR = chameleon
ECLAIREXL_DIR = eclairexl
MCC_DIR = mcc
MCC_5200_DIR = mcc_5200
MCCTV_DIR = mcctv
MCCTV_5200_DIR = mcctv_5200
MIST_DIR = mist
MIST_5200_DIR = mist_5200
LINUXSIM_DIR = linux
LINUXSIM_5200_DIR = linux_5200
SOCKIT_DIR = sockit

AEON_LITE_BUILD_DIR = $(BUILD_DIR)/$(AEON_LITE_DIR)
PAPILIODUO_BUILD_DIR = $(BUILD_DIR)/$(PAPILIODUO_DIR)
DE1_BUILD_DIR = $(BUILD_DIR)/$(DE1_DIR)
SOCKIT_BUILD_DIR = $(BUILD_DIR)/$(SOCKIT_DIR)
DE1_5200_BUILD_DIR = $(BUILD_DIR)/$(DE1_5200_DIR)
CHAMELEON_BUILD_DIR = $(BUILD_DIR)/$(CHAMELEON_DIR)
ECLAIREXL_BUILD_DIR = $(BUILD_DIR)/$(ECLAIREXL_DIR)
MCC_BUILD_DIR = $(BUILD_DIR)/$(MCC_DIR)
MCC_5200_BUILD_DIR = $(BUILD_DIR)/$(MCC_5200_DIR)
MCCTV_BUILD_DIR = $(BUILD_DIR)/$(MCCTV_DIR)
MCCTV_5200_BUILD_DIR = $(BUILD_DIR)/$(MCCTV_5200_DIR)
MIST_BUILD_DIR = $(BUILD_DIR)/$(MIST_DIR)
MIST_5200_BUILD_DIR = $(BUILD_DIR)/$(MIST_5200_DIR)
LINUXSIM_BUILD_DIR = $(BUILD_DIR)/$(LINUXSIM_DIR)
LINUXSIM_5200_BUILD_DIR = $(BUILD_DIR)/$(LINUXSIM_5200_DIR)

#MINSTARTUP_SRC = mincrt0.s
MINSTARTUP_SRC = mycrt0.s
MINSTARTUP_OBJ = $(patsubst $(STARTUP_DIR)/%.s,$(BUILD_DIR)/%.o,$(MINSTARTUP_SRC))

CORE_SRC = cartridge.c uart.c
COMMON_SRC = ${CORE_SRC}
SDCARD_SRC = file.c
A800_SRC_LIGHT = main800.c atari_drive_emulator.c libgcc_divmod.c
A800_SRC = ${A800_SRC_LIGHT}
5200_SRC_LIGHT = main5200.c
5200_SRC = ${5200_SRC_LIGHT} printf.c joystick.c freeze.c
USB_SRC = usb/hid.c  usb/hidparser.c  usb/hub.c usb/timer.c  usb/usb.c usb/debug.c

AEON_LITE_PRJ = AEON_LITE
AEON_LITE_SRC = $(COMMON_SRC) $(SDCARD_SRC) $(A800_SRC) de1/dirs.c
AEON_LITE_OBJ = $(patsubst %.c,$(AEON_LITE_BUILD_DIR)/%.o,$(AEON_LITE_SRC))

PAPILIODUO_PRJ = PAPILIODUO
PAPILIODUO_SRC = $(COMMON_SRC) $(SDCARD_SRC) $(A800_SRC) de1/dirs.c
PAPILIODUO_OBJ = $(patsubst %.c,$(PAPILIODUO_BUILD_DIR)/%.o,$(PAPILIODUO_SRC))

DE1_PRJ = DE1
DE1_SRC = $(COMMON_SRC) $(SDCARD_SRC) $(A800_SRC)
DE1_OBJ = $(patsubst %.c,$(DE1_BUILD_DIR)/%.o,$(DE1_SRC))

DE1_5200_PRJ = DE1_5200
DE1_5200_SRC = $(COMMON_SRC) $(SDCARD_SRC) $(5200_SRC)
DE1_5200_OBJ = $(patsubst %.c,$(DE1_5200_BUILD_DIR)/%.o,$(DE1_5200_SRC))

CHAMELEON_PRJ = CHAMELEON
CHAMELEON_SRC = $(COMMON_SRC) $(SDCARD_SRC) $(A800_SRC) chameleon/dirs.c
CHAMELEON_OBJ = $(patsubst %.c,$(CHAMELEON_BUILD_DIR)/%.o,$(CHAMELEON_SRC))

ECLAIREXL_PRJ = ECLAIREXL
ECLAIREXL_SRC = $(COMMON_SRC) $(SDCARD_SRC) $(A800_SRC) $(USB_SRC) de1/dirs.c
ECLAIREXL_OBJ = $(patsubst %.c,$(ECLAIREXL_BUILD_DIR)/%.o,$(ECLAIREXL_SRC))

MCC_PRJ = MCC216
MCC_SRC = $(COMMON_SRC) $(SDCARD_SRC) $(A800_SRC) $(USB_SRC) mcc/dirs.c
#MCC_SRC = $(COMMON_SRC) $(SDCARD_SRC) $(A800_SRC) mcc/dirs.c
MCC_OBJ = $(patsubst %.c,$(MCC_BUILD_DIR)/%.o,$(MCC_SRC))

MCC_5200_PRJ = MCC216_5200
MCC_5200_SRC = $(COMMON_SRC) $(SDCARD_SRC) $(5200_SRC) $(USB_SRC) mcc_5200/dirs.c
MCC_5200_OBJ = $(patsubst %.c,$(MCC_5200_BUILD_DIR)/%.o,$(MCC_5200_SRC))

MCCTV_PRJ = MCCTV
MCCTV_SRC = $(COMMON_SRC) $(SDCARD_SRC) $(A800_SRC) $(USB_SRC) mcc/dirs.c
#MCCTV_SRC = $(COMMON_SRC) $(SDCARD_SRC) $(A800_SRC) mcc/dirs.c
MCCTV_OBJ = $(patsubst %.c,$(MCCTV_BUILD_DIR)/%.o,$(MCCTV_SRC))

MCCTV_5200_PRJ = MCCTV_5200
MCCTV_5200_SRC = $(COMMON_SRC) $(SDCARD_SRC) $(5200_SRC) $(USB_SRC) mcc_5200/dirs.c
MCCTV_5200_OBJ = $(patsubst %.c,$(MCCTV_5200_BUILD_DIR)/%.o,$(MCCTV_5200_SRC))

MIST_PRJ = MIST
MIST_SRC = $(COMMON_SRC) $(SDCARD_SRC) $(A800_SRC) mist/dirs.c
MIST_OBJ = $(patsubst %.c,$(MIST_BUILD_DIR)/%.o,$(MIST_SRC))

MIST_5200_PRJ = MIST_5200
MIST_5200_SRC = $(COMMON_SRC) $(SDCARD_SRC) $(5200_SRC) mist_5200/dirs.c
MIST_5200_OBJ = $(patsubst %.c,$(MIST_5200_BUILD_DIR)/%.o,$(MIST_5200_SRC))

SOCKIT_PRJ = SOCKIT
SOCKIT_SRC = $(CORE_SRC) a800/freeze.c  a800/mainmenu.c atari_drive_emulator.c a800/joystick.c sockit/dirs.c sockit/linuxfile.c sockit/linuxdir.c sockit/memory.c
SOCKIT_OBJ = $(patsubst %.c,$(SOCKIT_BUILD_DIR)/%.o,$(SOCKIT_SRC))

LINKMAP  = ./standalone_simple.ld
LINKMAP_LARGE  = ./standalone_simple_large.ld

LINUXSIM_EXE	= linuxsim
LINUXSIM_SRC	= $(COMMON_SRC) $(A800_SRC_LIGHT) $(USB_SRC) linux/main.c linux/mmc.c \
	sd_direct/diskio_mmc.c linux/dirs.c linux/linux_memory.c linux/curses_screen.c \
	linux/linux_helper.c linux/emulate_usb.c

LINUXSIM_5200_EXE	= linuxsim_5200
LINUXSIM_5200_SRC	= $(COMMON_SRC) $(5200_SRC_LIGHT) linux/main.c linux/mmc.c \
	sd_direct/diskio_mmc.c linux/dirs.c linux/linux_memory.c linux/curses_screen.c \
	linux/linux_helper.c

LINUXSIM_OBJ	= $(patsubst %.c,$(LINUXSIM_BUILD_DIR)/%.o,$(LINUXSIM_SRC))
LINUXSIM_5200_OBJ	= $(patsubst %.c,$(LINUXSIM_5200_BUILD_DIR)/%.o,$(LINUXSIM_5200_SRC))

# Commandline options for each tool.

#ZPUOPTS= -mno-poppcrel -mno-pushspadd -mno-callpcrel -mno-shortop -mno-neg # No-neg requires bugfixed toolchain
#Include everything -> need to include emulation rom...
ZPUOPTS =
CFLAGS  = -I. -Isd_direct -Iprintf -Ifat -Icommon -Isdram_common -c -g -Os $(ZPUOPTS) -DDISABLE_UART_RX -DMAX_RAM_SELECT=6
CFLAGS_AEON  = -I. -Isd_direct -Iprintf -Ifat -Icommon -Iaeon_lite -c -g -Os $(ZPUOPTS) -DDISABLE_UART_RX -DMAX_RAM_SELECT=5
CFLAGS_PAPILIODUO  = -I. -Isd_direct -Iprintf -Ifat -Icommon -Ipapilioduo -c -g -Os $(ZPUOPTS) -DDISABLE_UART_RX -DMAX_RAM_SELECT=3

SOCKIT_CFLAGS += -I. -Icommon -Isockit -Iprintf -DMAX_RAM_SELECT=6

HOST_CFLAGS += -I. -Isd_direct -Iprintf -Ifat -Icommon -Isdram_common -DDISABLE_UART_RX -DUSB -Iusb -DMAX_RAM_SELECT=6

LFLAGS  = -nostartfiles -nostdlib -Wl,--relax -g -Os -Wl,-Map=out.map
LFLAGS_5200  = -nostartfiles -Wl,--relax -g -Os -Wl,-Map=out.map
#LFLAGS  = -nostartfiles -Os

CFLAGS_USB = $(CFLAGS) -DUSB -Iusb
CFLAGS_USB2 = $(CFLAGS) -DUSB -DUSB2 -Iusb
CFLAGS_5200 = $(CFLAGS) -DFIRMWARE_5200
CFLAGS_5200_USB = $(CFLAGS) -DFIRMWARE_5200 -DUSB -Iusb
CFLAGS_5200_USB2 = $(CFLAGS) -DFIRMWARE_5200  -DUSB -DUSB2 -Iusb
HOST_CFLAGS_5200 = $(HOST_CFLAGS) -DFIRMWARE_5200

# Our target.
all: eclairexl mcc mcctv mist de1 aeon_lite chameleon  de1_5200 mist_5200 mcc_5200 mcctv_5200 sockit papilioduo

install:
	cd ../common/romgen && ./createall && cd ../../firmware

aeon_lite: $(BUILD_DIR) $(AEON_LITE_PRJ).bin $(AEON_LITE_PRJ).rpt

papilioduo: $(BUILD_DIR) $(PAPILIODUO_PRJ).bin $(PAPILIODUO_PRJ).rpt

de1: $(BUILD_DIR) $(DE1_PRJ).bin $(DE1_PRJ).rpt

de1_5200: $(BUILD_DIR) $(DE1_5200_PRJ).bin $(DE1_5200_PRJ).rpt

chameleon: $(BUILD_DIR) $(CHAMELEON_PRJ).bin $(CHAMELEON_PRJ).rpt

eclairexl: $(BUILD_DIR) $(ECLAIREXL_PRJ).bin $(ECLAIREXL_PRJ).rpt

mcc: $(BUILD_DIR) $(MCC_PRJ).bin $(MCC_PRJ).rpt

mcc_5200: $(BUILD_DIR) $(MCC_5200_PRJ).bin $(MCC_5200_PRJ).rpt

mcctv: $(BUILD_DIR) $(MCCTV_PRJ).bin $(MCCTV_PRJ).rpt

mcctv_5200: $(BUILD_DIR) $(MCCTV_5200_PRJ).bin $(MCCTV_5200_PRJ).rpt

mist: $(BUILD_DIR) $(MIST_PRJ).bin $(MIST_PRJ).rpt

mist_5200: $(BUILD_DIR) $(MIST_5200_PRJ).bin $(MIST_5200_PRJ).rpt

sockit: $(BUILD_DIR) $(SOCKIT_PRJ).elf

.PHONY: linux
linux: $(BUILD_DIR) $(LINUXSIM_EXE)

.PHONY: linux_5200
linux_5200: $(BUILD_DIR) $(LINUXSIM_5200_EXE)

clean:
	rm -rf $(BUILD_DIR)/* *.hex *.elf *.map *.lst *.srec *.bin *.rpt $(LINUXSIM_EXE) $(LINUXSIM_5200_EXE)


# Convert ELF binary to bin file.
%.bin: %.elf
	$(CP) -O binary $< $@

%.rpt: %.elf
	echo >$@ -n "End of code:\t"
	$(DUMP) -x $< | grep >>$@ _romend
	echo >>$@ -n "Start of BSS:\t"
	$(DUMP) -x $< | grep  >>$@ __bss_start__
	echo >>$@ -n "End of BSS:\t"
	$(DUMP) -x $< | grep >>$@ __bss_end__
	cat $@

# Link - this produces an ELF binary.

$(AEON_LITE_PRJ).elf: $(MINSTARTUP_OBJ) $(AEON_LITE_OBJ)
	$(LD) $(LFLAGS) -T $(LINKMAP) -o $@ $+ $(LIBS)

$(PAPILIODUO_PRJ).elf: $(MINSTARTUP_OBJ) $(PAPILIODUO_OBJ)
	$(LD) $(LFLAGS) -T $(LINKMAP) -o $@ $+ $(LIBS)

$(DE1_PRJ).elf: $(MINSTARTUP_OBJ) $(DE1_OBJ)
	$(LD) $(LFLAGS) -T $(LINKMAP_LARGE) -o $@ $+ $(LIBS)

$(DE1_5200_PRJ).elf: $(MINSTARTUP_OBJ) $(DE1_5200_OBJ)
	$(LD) $(LFLAGS_5200) -T $(LINKMAP) -o $@ $+ $(LIBS)

$(CHAMELEON_PRJ).elf: $(MINSTARTUP_OBJ) $(CHAMELEON_OBJ)
	$(LD) $(LFLAGS) -T $(LINKMAP) -o $@ $+ $(LIBS)

$(ECLAIREXL_PRJ).elf: $(MINSTARTUP_OBJ) $(ECLAIREXL_OBJ)
	$(LD) $(LFLAGS) -T $(LINKMAP_LARGE) -o $@ $+ $(LIBS)

$(MCC_PRJ).elf: $(MINSTARTUP_OBJ) $(MCC_OBJ)
	$(LD) $(LFLAGS) -T $(LINKMAP_LARGE) -o $@ $+ $(LIBS)
#	$(LD) $(LFLAGS) -T $(LINKMAP) -o $@ $+ $(LIBS)

$(MCC_5200_PRJ).elf: $(MINSTARTUP_OBJ) $(MCC_5200_OBJ)
	$(LD) $(LFLAGS_5200) -T $(LINKMAP_LARGE) -o $@ $+ $(LIBS)

$(MCCTV_PRJ).elf: $(MINSTARTUP_OBJ) $(MCCTV_OBJ)
	$(LD) $(LFLAGS) -T $(LINKMAP_LARGE) -o $@ $+ $(LIBS)

$(MCCTV_5200_PRJ).elf: $(MINSTARTUP_OBJ) $(MCCTV_5200_OBJ)
	$(LD) $(LFLAGS_5200) -T $(LINKMAP_LARGE) -o $@ $+ $(LIBS)

$(MIST_PRJ).elf: $(MINSTARTUP_OBJ) $(MIST_OBJ)
	$(LD) $(LFLAGS) -T $(LINKMAP) -o $@ $+ $(LIBS)

$(MIST_5200_PRJ).elf: $(MINSTARTUP_OBJ) $(MIST_5200_OBJ)
	$(LD) $(LFLAGS_5200) -T $(LINKMAP) -o $@ $+ $(LIBS)

$(SOCKIT_PRJ).elf: $(SOCKIT_OBJ)
	$(SOCKIT_LD) $(SOCKIT_LDFLAGS) -o $@ $+

$(LINUXSIM_EXE): $(LINUXSIM_OBJ)
	$(HOST_LD) $(HOST_LDFLAGS) -o $@ $+

$(LINUXSIM_5200_EXE): $(LINUXSIM_5200_OBJ)
	$(HOST_LD) $(HOST_LDFLAGS) -o $@ $+

$(AEON_LITE_BUILD_DIR)/%.o: %.c Makefile
	mkdir -p `dirname $@`
	$(CC) -I$(AEON_LITE_DIR) $(CFLAGS_AEON)  -o $@ -c $<

$(PAPILIODUO_BUILD_DIR)/%.o: %.c Makefile
	mkdir -p `dirname $@`
	$(CC) -I$(PAPILIODUO_DIR) $(CFLAGS_PAPILIODUO)  -o $@ -c $<

$(CHAMELEON_BUILD_DIR)/%.o: %.c Makefile
	mkdir -p `dirname $@`
	$(CC) -I$(CHAMELEON_DIR) $(CFLAGS)  -o $@ -c $<

$(DE1_BUILD_DIR)/%.o: %.c Makefile
	mkdir -p `dirname $@`
	$(CC) -I$(DE1_DIR) $(CFLAGS)  -o $@ -c $<

$(DE1_5200_BUILD_DIR)/%.o: %.c Makefile
	mkdir -p `dirname $@`
	$(CC) -I$(DE1_5200_DIR) $(CFLAGS_5200)  -o $@ -c $<

$(ECLAIREXL_BUILD_DIR)/%.o: %.c Makefile
	mkdir -p `dirname $@`
	$(CC) -I$(ECLAIREXL_DIR) $(CFLAGS_USB2)  -o $@ -c $<

$(MCC_BUILD_DIR)/%.o: %.c Makefile
	mkdir -p `dirname $@`
	$(CC) -I$(MCC_DIR) $(CFLAGS_USB)  -o $@ -c $<

$(MCC_5200_BUILD_DIR)/%.o: %.c Makefile
	mkdir -p `dirname $@`
	$(CC) -I$(MCC_5200_DIR) $(CFLAGS_5200_USB)  -o $@ -c $<

$(MCCTV_BUILD_DIR)/%.o: %.c Makefile
	mkdir -p `dirname $@`
	$(CC) -I$(MCCTV_DIR) $(CFLAGS_USB2)  -o $@ -c $<

$(MCCTV_5200_BUILD_DIR)/%.o: %.c Makefile
	mkdir -p `dirname $@`
	$(CC) -I$(MCCTV_5200_DIR) $(CFLAGS_5200_USB2)  -o $@ -c $<

$(MIST_BUILD_DIR)/%.o: %.c Makefile
	mkdir -p `dirname $@`
	$(CC) -I$(MIST_DIR) $(CFLAGS)  -o $@ -c $<

$(MIST_5200_BUILD_DIR)/%.o: %.c Makefile
	mkdir -p `dirname $@`
	$(CC) -I$(MIST_5200_DIR) $(CFLAGS_5200)  -o $@ -c $<

$(SOCKIT_BUILD_DIR)/%.o: %.c Makefile
	mkdir -p `dirname $@`
	$(SOCKIT_CC) -I$(SOCKIT_DIR) $(SOCKIT_CFLAGS)  -o $@ -c $<

$(LINUXSIM_BUILD_DIR)/%.o: %.c Makefile
	@mkdir -p `dirname $@`
	$(HOST_CC) -I$(LINUXSIM_DIR) $(HOST_CFLAGS)  -o $@ -c $<

$(LINUXSIM_5200_BUILD_DIR)/%.o: %.c Makefile
	@mkdir -p `dirname $@`
	$(HOST_CC) -I$(LINUXSIM_DIR) $(HOST_CFLAGS_5200)  -o $@ -c $<

$(BUILD_DIR)/%.o: %.s
	$(AS) -o $@ $<

$(BUILD_DIR)/%.o: $(STARTUP_DIR)/%.s
	$(AS) -o $@ $<

$(BUILD_DIR):
	mkdir $(BUILD_DIR)

