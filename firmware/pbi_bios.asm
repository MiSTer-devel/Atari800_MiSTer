; Links:
; http://atariki.krap.pl/index.php/ROM_PBI

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
	.byte $31	; ddevic we are servicing
pdior_vec
	jmp pdior
pdint_vec
	rts : nop : nop
	; Magic 2
	.byte $91
	.byte $00	; no CIO 
	.word pdint_vec
	.word pdint_vec
	.word pdint_vec
	.word pdint_vec
	.word pdint_vec
	.word pdint_vec

pdinit
	lda pdvmsk : ora pdvrs : sta pdvmsk
	lda #0 : ldx #$fe : sta $d100-1,x : dex : bne *-4
	; Marker for the core firmware
	lda #$a5 : sta $d100 : sta $d101
	; ask for init
	inc $d102 : lda $d102 : bne *-3
	; Do we want the splash?
	lda $d103 : beq pdinit_ret
	lda #$0c : sta $2c5 ; color 1
	lda #$e0 : sta $d409 ; chbase
	lda #<display_list : sta $d402 : lda #>display_list : sta $d403 ; display list
	lda $14 : cmp $14 : beq *-2 : ldy #$22 : sty $d400 ; dmactl
	clc : adc #100 : cmp $14 : bne *-2 : stx $d400
pdinit_ret
	rts

display_list
	.byte $70, $70, $70
	.byte $42 : .word display_text1
	.byte $10
	.byte $42 : .word display_text2
	.byte $70
	.byte $42 : .word display_text3
	.byte $41 : .word display_list

display_text1
	.byte 0,0
	.byte 'A'-$20,'tari','8'-$20,'0'-$20,'0'-$20,0,'M'-$20,'i','S'-$20,'T'-$20,'er',0,'core',0 
	.byte 'P'-$20,'B'-$20,'I'-$20,0,'B'-$20,'I'-$20,'O'-$20,'S'-$20,0
	.byte 'v','0'-$20,'.'-$20,'8'-$20
display_text1_len = *-display_text1
	.dsb 40-display_text1_len,0
display_text2
	.byte 0,0
	.byte '('-$20,'C'-$20,')'-$20,0,'2'-$20,'0'-$20,'2'-$20,'5'-$20,0,'woj','@'-$20,'A'-$20,'tari','A'-$20,'ge'
display_text2_len = *-display_text2
	.dsb 40-display_text2_len,0
display_text3 = $d110 

; The main block I/O routine
pdior
	lda ddevic : cmp #$31 : bne pdior_bail
	lda dunit : beq pdior_bail
	cmp #5 : bcs pdior_bail
	inc $d104 : lda $d104 : bne *-3
	lda $d105 : bmi pdior_bail ; the FW says either no PBI service or ATX (plain SIO)
	beq pdior_pbi_ok ; the drive was in PBI mode and got serviced
	; otherwise call HSIO
	jsr $dc00 ; TODO or does it return with carry set and we can just jmp?
pdior_pbi_ok
	ldy $303 ; TODO HSIO already does that, swap things around here
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