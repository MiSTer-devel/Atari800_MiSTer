# Atari 800/800XL/65XE/130XE and Atari 5200 for [MiSTer Board](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

### This is the port of [Atari 800XL core by Mark Watson](http://ssh.scrameta.net/)

### Installation
* **Core requires secondary SD card on I/O board v5.x. (or solder SD connector by yourself).**
* Copy the *.rbf file to the root of the system SD card.
* Format the secondary SD card with FAT16 and extract [sdcard.zip](https://github.com/MiSTer-devel/Atari800_MiSTer/tree/master/releases/sdcard.zip) to root.

## Usage notes

### System ROM
There are ROMs for both 800 and 800XL models. By default 800XL(atarixl.rom) is loaded. Remove it or rename if you wish to use 800(atariosb.rom) ROM by default.

800XL ROM supplied in 2 versions:
* ATARIXL.ROM - includes SIO turbo patch (fast disk loading). Loaded by default.
* ATARIXLn.ROM - original 800XL ROM. 
  
You can use menu to choose required ROM, or rename ATARIXLn.ROM to ATARIXL.ROM if you don't want to use turbo loading.

Turbo ROM has hot keys to control the turbo mode:
* SHIFT+CONTROL+N    Disable highspeed SIO (normal speed)
* SHIFT+CONTROL+H    Enable highspeed SIO 
  
Additionally, you can control the speed of turbo loading in settings menu (F12).

### Differences from original version
* Joystick/Paddle mode switched by joystick. Press **Paddle1/2** to switch to paddle mode (analog X/Y). Press **Fire** to switch to joystick mode (digital X/Y).
* Use ` key as a **Brake** on reduced keyboards.
* Cursor keys are mapped to Atari cursor keys.
* PAL/NTSC mode switch in settings menu
* Video aspect ratio switch in settings menu
* Some optimizations and tweaks in file selector and settings menu navigation.
* Combined cartridge/disk quick selector (F11).
* WIN+Enter/Fire in quick selector loads Drive 2.
* WIN+Enter/Fire in normal work swaps Drive 1 <-> Drive 2.
* WIN+F12 opens reduced MiSTer menu where you can assign joystick buttons.
* Mouse emulates analog joystick(Atari 5200) and paddles(Atari 800).

### More info
See more info in original [instructions](https://github.com/MiSTer-devel/Atari800_MiSTer/tree/master/instructions.txt)
and original [manual](https://github.com/MiSTer-devel/Atari800_MiSTer/tree/master/manual.pdf).

## Download precompiled binaries
Go to [releases](https://github.com/MiSTer-devel/Atari800_MiSTer/tree/master/releases) folder.
