BASE	= zpu-elf
CC      = $(BASE)-gcc
LD      = $(BASE)-gcc
AS      = $(BASE)-as
CP      = $(BASE)-objcopy
DUMP    = $(BASE)-objdump
SREC    = srec_cat

# we use mincrt0.s from here
STARTUP_DIR = .

BUILD_DIR=zpu_obj

DIR = a800
5200_DIR = a5200

800_BUILD_DIR = $(BUILD_DIR)/$(DIR)
5200_BUILD_DIR = $(BUILD_DIR)/$(5200_DIR)

MINSTARTUP_SRC = mycrt0.s
MINSTARTUP_OBJ = $(patsubst $(STARTUP_DIR)/%.s,$(BUILD_DIR)/%.o,$(MINSTARTUP_SRC))

COMMON_SRC = uart.c file.c printf.c 

PRJ = zpu_rom_800
SRC = $(COMMON_SRC) main800.c atari_drive_emulator.c atx.c atx_eclaire.c libgcc_divmod.c joystick800.c freeze800.c
OBJ = $(patsubst %.c,$(800_BUILD_DIR)/%.o,$(SRC))

5200_PRJ = zpu_rom_5200
5200_SRC = $(COMMON_SRC) main5200.c joystick5200.c freeze5200.c
5200_OBJ = $(patsubst %.c,$(5200_BUILD_DIR)/%.o,$(5200_SRC))

LINKMAP  = ./standalone_simple.ld
LINKMAP_LARGE  = ./standalone_simple_large.ld

# Commandline options for each tool.

CFLAGS  = -I. -Isd_direct -Iprintf -Ifat -Icommon -Isdram_common -c -g -Os -DDISABLE_UART_RX -DMAX_RAM_SELECT=6

LFLAGS  = -nostartfiles -nostdlib -Wl,--relax -g -Os -Wl,-Map=out.map
LFLAGS_5200  = -nostartfiles -Wl,--relax -g -Os -Wl,-Map=out.map

CFLAGS_5200 = $(CFLAGS) -DFIRMWARE_5200

# Our target.
all: 800 5200

xex_loader.h: xex_loader.asm
	xa -M -l xex_loader.lab -o xex_loader.o65 xex_loader.asm
	python3 process_xex_loader.py

PBIBIOS.mif:	pbi_bios.asm
	xa -M -o pbi_bios.o65 pbi_bios.asm 
	$(SREC) pbi_bios.o65 -binary -o PBIBIOS.mif -mif 8

800: PBIBIOS.mif xex_loader.h $(BUILD_DIR) $(PRJ).bin $(PRJ).rpt $(PRJ).mif

5200: $(BUILD_DIR) $(5200_PRJ).bin $(5200_PRJ).rpt $(5200_PRJ).mif

clean:
	rm -rf $(BUILD_DIR)/* *.hex *.elf *.map *.lst *.srec *.bin *.rpt *.o65 *.lab


# Convert ELF binary to bin file.
%.bin: %.elf
	$(CP) -O binary $< $@

%.mif: %.bin
	$(SREC) $< -binary -o $@ -mif 32

%.rpt: %.elf
	echo >$@ -n "End of code:\t"
	$(DUMP) -x $< | grep >>$@ _romend
	echo >>$@ -n "Start of BSS:\t"
	$(DUMP) -x $< | grep  >>$@ __bss_start__
	echo >>$@ -n "End of BSS:\t"
	$(DUMP) -x $< | grep >>$@ __bss_end__
	cat $@

# Link - this produces an ELF binary.

$(PRJ).elf: $(MINSTARTUP_OBJ) $(OBJ)
	$(LD) $(LFLAGS) -T $(LINKMAP_LARGE) -o $@ $+ $(LIBS)

$(5200_PRJ).elf: $(MINSTARTUP_OBJ) $(5200_OBJ)
	$(LD) $(LFLAGS_5200) -T $(LINKMAP) -o $@ $+ $(LIBS)

$(800_BUILD_DIR)/%.o: %.c Makefile
	mkdir -p `dirname $@`
	$(CC) -I$(DIR) $(CFLAGS)  -o $@ -c $<

$(5200_BUILD_DIR)/%.o: %.c Makefile
	mkdir -p `dirname $@`
	$(CC) -I$(5200_DIR) $(CFLAGS_5200)  -o $@ -c $<

$(BUILD_DIR)/%.o: %.s
	$(AS) -o $@ $<

$(BUILD_DIR)/%.o: $(STARTUP_DIR)/%.s
	$(AS) -o $@ $<

$(BUILD_DIR):
	mkdir $(BUILD_DIR)
