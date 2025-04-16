; Links:
; http://atariki.krap.pl/index.php/ROM_PBI

pdvmsk	= $247
pdvrs	= $248
ddevic	= $300
dunit	= $301
dstats	= $303
dtimlo	= $306
cdtma1	= $226
setvbv	= $e45c

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
	tsx : stx $d106
	lda dtimlo : ror : ror : tay : and #$3f : tax : tya : ror : and #$c0 : tay : lda #1
	jsr setvbv
	lda #<pbi_time_out : sta cdtma1 : lda #>pbi_time_out : sta cdtma1+1
	inc $d104 : lda $d104 : bne *-3
	ldx #0 : ldy #0 : lda #1 : jsr setvbv 
	lda $d105 : bmi pdior_bail ; the FW says either no PBI service or ATX (plain SIO)
	beq pdior_pbi_ok ; the drive was in PBI mode and got serviced
	; otherwise call HSIO
	jsr $dc00 : sec : rts
pdior_pbi_ok
	ldy dstats : sec : rts
pdior_bail
	; We are not servicing this block I/O request
	clc : rts
pbi_time_out
	lda #0 : sta $d104 : ldx $d106 : txs : lda #$8a : sta dstats : bne pdior_pbi_ok
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