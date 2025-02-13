buffer_index	= $43
load_addr	= $44
load_end	= $46

cart_off_reg	= $d510
cart_base_reg	= $d500

trig3		= $d013
portb		= $d301
wsync		= $d40a

rtclok		= $12
ramtop		= $6a
coldst		= $244
runad		= $2e0
initad		= $2e2
ramsiz		= $2e4
basicf		= $3f8
gintlk		= $3fa

edev_vecs	= $e400

loader_addr	= $700
buffer		= loader_addr + $100

cart_header_len = 13

	* = loader_addr
read_next_byte
	ldx buffer_index : inx : bne read_next_from_buffer
	stx read_status : reloc01 = *-1
	lda #1 : read_status = *-1 : beq *-2
read_next_from_buffer
	stx buffer_index
	lda buffer,x : reloc02 = *-1
read_next_byte_ret
	rts

#define BURST_READ

init
magic	; $20
	jsr loader_init : reloc03 = *-1
load_next_block
	ldy #0
	jsr read_next_byte : reloc04 = *-1 : sta load_addr
	jsr read_next_byte : reloc05 = *-1 : sta load_addr+1
	and load_addr : cmp #$FF : beq load_next_block
	jsr read_next_byte : reloc06 = *-1 : sta load_end
	jsr read_next_byte : reloc07 = *-1 : sta load_end+1
	ora load_end : beq init_go
	lda #0 : runad_ready = *-1 : bne load_next_block_1
	inc runad_ready : reloc08 = *-1
	lda load_addr : sta runad : lda load_addr+1 : sta runad+1
load_next_block_1
	lda #<read_next_byte_ret : sta initad : lda #>read_next_byte_ret : reloc09 = *-1 : sta initad+1
load_loop
	jsr read_next_byte : reloc10 = *-1

#ifdef BURST_READ

	cpx #0 : bne load_loop_1
	tax
	lda load_end+1 : sec : sbc load_addr+1 : cmp #2 : bcc load_loop_2
burst_copy_loop
	lda buffer,y : reloc11 = *-1 : sta (load_addr),y : iny : bne burst_copy_loop
	inc load_addr+1
	dec buffer_index
	bne load_loop
load_loop_2
	txa
load_loop_1

#endif

	sta (load_addr),y
	lda load_addr : cmp load_end : bne advance_address
	lda load_addr+1 : cmp load_end+1 : beq run_init_ad
advance_address
	inc load_addr : bne load_loop : inc load_addr+1
	bne load_loop
run_init_ad
	lda #>(load_next_block-1) : reloc12 = *-1 : pha
	lda #<(load_next_block-1) : pha
	jmp (initad)
init_go
	dec magic : reloc13 = *-1
	jmp (runad)

loader_init
	sta cart_off_reg : sta wsync : lda trig3 : sta gintlk
	lda #$C0 : cmp ramtop : beq loader_init_ret
	sta ramtop : sta ramsiz
	lda portb : ora #$02 : sta portb
	lda #1 : sta basicf
	ldx #2 : jsr editor : reloc14 = *-1
	ldx #0 : jsr editor : reloc15 = *-1
	lda rtclok+2 : cmp rtclok+2 : beq *-2
loader_init_ret
	dec magic : reloc16 = *-1
	rts
editor
	lda edev_vecs+1,x : pha
	lda edev_vecs,x : pha
	rts
loader_end

loader_len = loader_end - loader_addr

init_cart
	ldy #loader_len
init_copy_loop
	lda $A000-1,y : sta loader_addr-1,y : reloc17 = *-1
	dey : bne init_copy_loop

	ldx #$FF : stx buffer_index : txs
	inx : stx coldst
	jmp init : reloc18 = *-1

init_cart_addr = $A000+loader_len

	sta cart_base_reg
	sta wsync
	rts
	.word init_cart_addr
	.byte 0
	.byte 4
	.word $C000-cart_header_len
