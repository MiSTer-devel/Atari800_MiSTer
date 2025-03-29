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

pdvmsk	= $0247
pdvrs	= $0248
colbak	= $d01a
;wsync	= $d40a
ddevic = $300
dunit = $301

	* = $D800
bios1_start
	.byte 'M', 'S', 'T'
	; Magic 1
	.byte $80
	.byte $31
pdior_vec
	jmp	pdior
pdint_vec
	rts
	nop
	nop
	; Magic 2
	.byte $91
	.byte $00
	.word pdint_vec
	.word pdint_vec
	.word pdint_vec
	.word pdint_vec
	.word pdint_vec
	.word pdint_vec

pdinit
	lda pdvmsk : ora pdvrs : sta pdvmsk
	lda #0
	ldx #$fe
	sta $d100-1,x : dex : bne *-4
	; Marker for the core firmware
	lda #$a5 : sta $d100 : sta $d101
	; Silly rainbow effect, to be removed / replaced later
	ldy #0
color_loop
	ldx #0
	stx colbak : inx : bne *-4
	iny : bne color_loop
	rts

; The main block I/O routine
pdior
	lda ddevic : cmp #$31 : bne pdior_bail
	lda dunit : beq pdior_bail
	cmp #5 : bcs pdior_bail
	jsr $dc00 ; TODO or does it return with carry set and we can just jmp?
	sec
	rts
pdior_bail
	; We are not servicing this block I/O request
	clc
	rts
bios1_end

.dsb ($400-bios1_end+bios1_start),$ff

hsio_start	; This should be $dc00
.bin 6,0,"hsio-pbi.xex"
hsio_end

.dsb ($400-hsio_end+hsio_start),$ff

	* = $D800
.dsb $800,$22

	* = $D800
.dsb $800,$33

	* = $D800
.dsb $800,$44