; Links:
; http://atariki.krap.pl/index.php/ROM_PBI

; RAM area D600-D7FF, 512 bytes, in the bios initialize to some id tag (A5A5??) and zero out the rest
; ROM area D800-DFFF, 2048 bytes, but this can be bank switched
; Locate all this in SDRAM in between Basic (8K) and the OS ROM (16K), this gives 8K in total.
; Further RAM cells should be used by the HSIO handler
; Alternativelly, implement RAM directly as D1xx r/w registers, only a few are needed.
; This would allow to use one more PBI rom bank, internal core RAM routing would not 
; be needed, and it could stay active all the time, not only when PBI rom is banked in.

; [one (?) location in this RAM is a marker for PBI request to the firmware, like with the XEX loader
; one location is for the status code, one for whether we service this at all]
; condition for servicing:
; - PBI bios on (already established)
; - If SIO is connected to user port???
; - SIO connected internally
; - DDEVIC+DUNIT-1 is a drive that is mounted, is not an ATX type, and drive is not
;   configured as Off 
; - SIO connected externally: or drive is set to HSIO
;   this is request #1 to the firmware, firmware reports back:
;   will not service, will service in PBI mode, will service in HSIO mode
; If it cannot be serviced, clear the carry flag and return
; If it can be serviced:
;  - if the drive is in HSIO mode -> call HSIO (check if Y is set by HSIO?), set carry flag
;    and then return
;  - if the drive is in PBI mode -> singal firmware to service it DMA style, wait for completion,
;    check for time-out somehow?, copy DSTAT to Y, set the carry flag 

; In the MiSTer menu each drive can be configured (only active / meaningful when PBI bios is on)
; to be Off, PBI or (H)SIO

; firmware:
;    observe request #1 flag in PBI RAM, react accordingly and lower the flag
;    observe request #2 flag, run the drive emulator in PBI mode
;    drive emulator needs to see a flag in the command to know the PBI mode
;    and then use the direct Atari memory buffer rather than atari_sector_buffer
;    this needs a separate processCommand routine
