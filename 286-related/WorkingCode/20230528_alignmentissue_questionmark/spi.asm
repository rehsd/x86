spi_sdcard_init:
	push	ds
	pusha
	call	to0000ds
	mov		bx,		msg_sdcard_init
	call	print_string_to_serial

	call	delay			;remove? ...test
	call	delay


	; using SPI mode 0 (cpol=0, cpha=0)
	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; SPI_CS2 high (not enabled), start with MOSI high and CLK low
	out		VIA1_PORTB,		al	
	
	mov		si,				0x00a0			;80 full clock cycles to give card time to initiatlize
	.init_loop:
		xor		al,				SPI_CLK
		out		VIA1_PORTB,		al
		nop									; nops might not be needed... test reducing/removing
		nop
		nop
		nop
		dec		si
		cmp		si,				0    
		jnz		.init_loop

    .try00:													; GO_IDLE_STATE
		;mov		bx,		msg_sdcard_try00
		;call	print_string_to_serial

		mov		bx,		cmd0_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x01
		jne		.try00

		;mov		bx,		msg_sdcard_try00_done
		;call	print_string_to_serial


		;mov		bx,		msg_garbage
		;call	print_string_to_serial

	call	delay

	.try08:													; SEND_IF_COND

		;mov		bx,		msg_sdcard_try08
		;call	print_string_to_serial

		mov		bx,		cmd8_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x01
		jne		.try08

		;mov		bx,		msg_sdcard_try08_done
		;call	print_string_to_serial
		
		call	spi_readbyte_port_b							; read four bytes
		call	spi_readbyte_port_b
		call	spi_readbyte_port_b
		call	spi_readbyte_port_b

	.try55:													; APP_CMD
		;mov		bx,		msg_sdcard_try55
		;call	print_string_to_serial

		mov		bx,		cmd55_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x01
		jne		.try55

		;mov		bx,		msg_sdcard_try55_done
		;call	print_string_to_serial

	.try41:													; SD_SEND_OP_COND
		;mov		bx,		msg_sdcard_try41
		;call	print_string_to_serial

		mov		bx,		cmd41_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x00
		jne		.try55

		;mov		bx,		msg_sdcard_try41_done
		;call	print_string_to_serial

	.try18:													; READ_MULTIPLE_BLOCK, starting at 0x0
		;mov		bx,		msg_sdcard_try18
		;call	print_string_to_serial

		mov		bx,		cmd18_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand_noclose				; start reading SD card at 0x0


		; ** to do --	read bytes until 0xfe is returned
		;				this is where the actual data begins
		;call	spi_readbyte_port_b	
		;cmp		al,		0xfe							; 0xfe = have data
		;jne		.nodata									; if data avail, continue, otherwise jump to .nodata

		call	spi_sdcard_readdata	

		;mov		bx,		msg_sdcard_try18_done
		;call	print_string_to_serial
	
		jmp		.out

	.nodata:
		;mov		bx,		msg_sdcard_nodata
		;call	print_string_to_serial
	
	.out:

		mov		bx,		msg_sdcard_init_out
		call	print_string_to_serial
	popa
	pop		ds
	ret

spi_sdcard_readdata:
	push	ds
	push	si
	push	bx
	call	to0000ds

	call	send_garbage
	mov		al,				(SPI_CS1|			SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS2 low to enable, start with MOSI high and CLK low
	mov		[spi_state_b],	al
	out		VIA1_PORTB,		al		
	call	send_garbage

	mov		si, 32
	.loop:
		; first real data from card is the byte after 0xfe is read... usually the first byte
		call	spi_readbyte_port_b	
		; call	print_char_hex
		mov		ah,	0x02		; cmd02 = print hex
		call	spi_send_NanoSerialCmd
		dec		si
		jnz		.loop

		mov		ax,	0x010a		; cmd01 = print char - newline
		call	spi_send_NanoSerialCmd


	.out:
		call	send_garbage
		mov		al,				(SPI_CS1| SPI_CS2 |	SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS2 low to enable, start with MOSI high and CLK low
		mov		[spi_state_b],	al
		mov		bx,		cmd12_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

		mov		bx,		msg_sdcard_read_done
		call	print_string_to_serial

		pop		bx
		pop		si
		pop		ds
	ret

send_garbage:
	; when changing CS in SPI, a byte of (any) data should be sent just prior to and just following the CS change -- calling this a garbage byte
	; this might possibly only apply to SD Card CS  (?)
	push	ds
	call	to0000ds
	push	cx

	mov		cx,		0x08					; send 8 bits
	.loop:
		mov		al,				[spi_state_b]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
	.clock:
		; remove the following line
		and		al,				~SPI_CLK	;0b11111011	 low clock			to do: invert SPI_CLK instead of 0b... value		--use ~
		
		out		VIA1_PORTB,		al			; set MOSI (or not) first with SCK low
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		or		al,				SPI_CLK		; high clock
		out		VIA1_PORTB,		al			; raise CLK keeping MOSI the same, to send the bit
		nop
		nop
		nop
		nop
		nop
		nop
		nop

		loop	.loop						; loop if there are more bits to send

		; end on low clock
		mov		al,				[spi_state_b]	
		out		VIA1_PORTB,		al			
		
		pop		cx
		pop		ds
	ret

spi_sdcard_sendcommand:
	push	ds
	call	to0000ds

	call	send_garbage
	mov		al,				(SPI_CS1|			SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS2 low to enable, start with MOSI high and CLK low
	mov		[spi_state_b],	al
	out		VIA1_PORTB,		al		
	call	send_garbage

	nop									; nops might not be needed... test reducing/removing
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	mov		al,				ES:[bx+1]
	;call	print_char_hex
	call	spi_writebyte_port_b

	mov		al,				ES:[bx]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	mov		al,				ES:[bx+3]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	;call	lcd_line2

	mov		al,				ES:[bx+2]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	mov		al,				ES:[bx+5]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	mov		al,				ES:[bx+4]
	;call	print_char_hex
	call	spi_writebyte_port_b

	;call	delay

	call	spi_waitresult
	push	ax				; save result

	;call	delay

	call	send_garbage
	mov		al,				(SPI_CS1| SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)	
	mov		[spi_state_b],	al
	out		VIA1_PORTB,		al	
	call	send_garbage

	pop		ax				; retrieve result
	pop		ds
	.out:
  ret

spi_sdcard_sendcommand_noclose:
	; same as spi_sdcard_sendcommand, but leaves SPI_CS2 low (enabled)
	; used in cases such as READ_MULTIPLE_BLOCK, where CS should not be brought high until done reading blocks
	push	ds
	call	to0000ds

	call	send_garbage
	mov		al,				(SPI_CS1|			SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS2 low to enable, start with MOSI high and CLK low
	mov		[spi_state_b],	al
	out		VIA1_PORTB,		al		
	call	send_garbage

	nop									; nops might not be needed... test reducing/removing
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	mov		al,				ES:[bx+1]
	;call	print_char_hex
	call	spi_writebyte_port_b

	mov		al,				ES:[bx]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	mov		al,				ES:[bx+3]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	;call	lcd_line2

	mov		al,				ES:[bx+2]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	mov		al,				ES:[bx+5]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	mov		al,				ES:[bx+4]
	;call	print_char_hex
	call	spi_writebyte_port_b

	;call	delay

	call	spi_waitresult
	push	ax				; save result

	;call	delay

	;call	send_garbage
	;mov		al,				(SPI_CS1| SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)	
	;mov		[spi_state_b],	al
	;out		VIA1_PORTB,		al	
	;call	send_garbage

	pop		ax				; retrieve result
	pop		ds
	.out:
  ret

spi_waitresult:
	; Wait for the SD card to return something other than $ff
 
	call	spi_readbyte_port_b
	cmp		al,		0xff
	je		spi_waitresult
 
	ret

spi_init:
	; configure the port
	push	ds
	push	ax
	push	bx
	call	to0000ds

	mov		al,				0b01111111			; disable all interrupts on VIA
	out		VIA1_IER,		al

	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_CLK | SPI_MOSI)	; set bits as output -- other bits will be input
	out		VIA1_DDRB,		al
	nop
	nop
	nop
	nop
	nop
	nop
	out		VIA1_DDRA,	al
	
	; set initial values on the port
	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)	; start with all select lines high and clock low - mode 0
	
	push	ds
	call	to0000ds
	mov		[spi_state_b],	al
	mov		[spi_state_a],	al
	pop		ds

	out		VIA1_PORTB,		al		; set initial values - not CS's selected		;(this causes a low blip on port B lines)
	nop
	nop
	nop
	nop
	nop
	out		VIA1_PORTA,		al		; set initial values - not CS's selected
	
	mov		bx,		msg_spi_init
	call	print_string_to_serial

	pop		bx
	pop		ax
	pop		ds
	ret

spi_writebyte_port_b:
	; Value to write in al
	; CS values and MOSI high in spi_state

	; Tick the clock 8 times with descending bits on MOSI
	; Ignoring anything returned on MISO (use spi_readbyte if MISO is needed)
	push	ds
	push	ax
	push	bx
	push	cx
	call	to0000ds

	mov		cx,		0x08					; send 8 bits
	.loop:
		shl		al,				1			; shift next bit into carry
		mov		bl,				al			; save remaining bits for later
		jnc		.sendbit					; if carry clear, don't set MOSI for this bit and jump down to .sendbit
		mov		al,				[spi_state_b]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
		;or		al,				SPI_MOSI	; if value in carry, set MOSI
		jmp		.clock
	.sendbit:
		mov		al,				[spi_state_b]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
		and		al,				~SPI_MOSI	;0b11111101	; to do: invert SPI_MOSI instead of 0b... value
	.clock:
		; remove the following line
		and		al,				~SPI_CLK	;0b11111011	 low clock			to do: invert SPI_CLK instead of 0b... value		--use ~
		
		out		VIA1_PORTB,		al			; set MOSI (or not) first with SCK low
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		or		al,				SPI_CLK		; high clock
		out		VIA1_PORTB,		al			; raise CLK keeping MOSI the same, to send the bit
		nop
		nop
		nop
		nop
		nop
		nop
		nop

		mov		al,				bl			; restore remaining bits to send
		loop	.loop						; loop if there are more bits to send

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	
	;bring clock low
	mov		al,				[spi_state_b]			
	out		VIA1_PORTB,		al			


	pop		cx
	pop		bx
	pop		ax
	pop		ds
	ret

spi_writebyte_port_a:
	; Value to write in al
	; CS values and MOSI high in spi_state

	; Tick the clock 8 times with descending bits on MOSI
	; Ignoring anything returned on MISO (use spi_readbyte if MISO is needed)
  
	push	ds
	call	to0000ds
	push	ax
	push	bx
	push	cx

	mov		cx,		0x08					; send 8 bits
	.loop:
		shl		al,				1			; shift next bit into carry
		mov		bl,				al			; save remaining bits for later
		jnc		.sendbit					; if carry clear, don't set MOSI for this bit and jump down to .sendbit
		mov		al,				[spi_state_a]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
		;or		al,				SPI_MOSI	; if value in carry, set MOSI
		jmp		.clock
	.sendbit:
		mov		al,				[spi_state_a]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
		and		al,				~SPI_MOSI	;0b11111101	; to do: invert SPI_MOSI instead of 0b... value
	.clock:
		; remove the following line
		and		al,				~SPI_CLK	;0b11111011	 low clock			to do: invert SPI_CLK instead of 0b... value		--use ~
		
		out		VIA1_PORTA,		al			; set MOSI (or not) first with SCK low
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		or		al,				SPI_CLK		; high clock
		out		VIA1_PORTA,		al			; raise CLK keeping MOSI the same, to send the bit
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		
		mov		al,				bl			; restore remaining bits to send
		loop	.loop						; loop if there are more bits to send

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	;bring clock low
	mov		al,				[spi_state_a]			
	out		VIA1_PORTA,		al		

	pop		cx
	pop		bx
	pop		ax
	pop		ds
	ret

spi_writebyte_port_a_slow:
	; Value to write in al
	; CS values and MOSI high in spi_state

	; Tick the clock 8 times with descending bits on MOSI
	; Ignoring anything returned on MISO (use spi_readbyte if MISO is needed)
	push	ds
	push	ax
	push	bx
	push	cx
	call	to0000ds

	mov		cx,		0x08					; send 8 bits
	.loop:
		shl		al,				1			; shift next bit into carry
		mov		bl,				al			; save remaining bits for later
		jnc		.sendbit					; if carry clear, don't set MOSI for this bit and jump down to .sendbit
		mov		al,				[spi_state_a]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
		;or		al,				SPI_MOSI	; if value in carry, set MOSI
		jmp		.clock
	.sendbit:
		mov		al,				[spi_state_a]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
		and		al,				~SPI_MOSI	;0b11111101	; to do: invert SPI_MOSI instead of 0b... value
	.clock:
		; remove the following line
		and		al,				~SPI_CLK	;0b11111011	 low clock			to do: invert SPI_CLK instead of 0b... value		--use ~
		
		out		VIA1_PORTA,		al			; set MOSI (or not) first with SCK low
		
		push	cx
		push	si
		mov		cx,	SPI_SLOW_DELAY_LOW				; low word of counter
		mov		si,	0x0001				; high word of counter
		call	delay_configurable		; counts down from dword to zero
		pop		si
		pop		cx

		or		al,				SPI_CLK		; high clock
		out		VIA1_PORTA,		al			; raise CLK keeping MOSI the same, to send the bit

		push	cx
		push	si
		mov		cx,	SPI_SLOW_DELAY_LOW				; low word of counter
		mov		si,	0x0001				; high word of counter
		call	delay_configurable		; counts down from dword to zero
		pop		si
		pop		cx
		
		mov		al,				bl			; restore remaining bits to send
		dec		cx
		jne		.loop						; loop if there are more bits to send


	;bring clock low
	mov		al,				[spi_state_a]			
	out		VIA1_PORTA,		al		

	pop		cx
	pop		bx
	pop		ax
	pop		ds
	ret

spi_writebyte_port_a_mode_1:
	; Value to write in al
	; CS values and MOSI high in spi_state

	; Tick the clock 8 times with descending bits on MOSI
	; Ignoring anything returned on MISO (use spi_readbyte if MISO is needed)
  
	push	ds
	call	to0000ds
	push	ax
	push	bx
	push	cx
	
	mov		cx,		0x08					; send 8 bits
	.loop:
		shl		al,				1			; shift next bit into carry
		mov		bl,				al			; save remaining bits for later
		jnc		.sendbit					; if carry clear, don't set MOSI for this bit and jump down to .sendbit
		mov		al,				[spi_state_a]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
		jmp		.clock
	.sendbit:
		mov		al,				[spi_state_a]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
		and		al,				~SPI_MOSI	;0b11111101	; to do: invert SPI_MOSI instead of 0b... value
	.clock:
		; remove the following line
		or		al,				SPI_CLK		; high clock
		
		out		VIA1_PORTA,		al			; set MOSI (or not) first with SCK low
		nop
		nop
		and		al,				~SPI_CLK	; low clock
		out		VIA1_PORTA,		al			; lower CLK keeping MOSI the same, to send the bit
		nop
		nop
		
		mov		al,				bl			; restore remaining bits to send
		loop	.loop						; loop if there are more bits to send


	;bring clock low
	;mov		al,				[spi_state_a]			
	;out		VIA1_PORTA,		al		

	pop		cx
	pop		bx
	pop		ax
	pop		ds
	ret

spi_readbyte_port_b:
	push	ds
	push	cx
	push	bx
	call	to0000ds
	mov		cx,		0x08					; send 8 bits
	.loop:
		mov		al,				[spi_state_b]		; MOSI already high and CLK low
		out		VIA1_PORTB,		al

		or		al,				SPI_CLK		; toggle the clock high
		out		VIA1_PORTB,		al
		in		al,				VIA1_PORTB	; read next bit
		and		al,				SPI_MISO
		clc									; default to clearing the bottom bit
		je		.readyByteBitNotSet			; unless MISO was set
		stc									; in which case get ready to set the bottom bit

		.readyByteBitNotSet:
			mov		al,				bl		; transfer partial result from bl
			rcl		al,				1		; rotate carry bit into read result
			mov		bl,				al		; save partial result back to bl
			loop	.loop					; loop if more bits

	push	ax		;save read value
	; end clock high
	mov		al,				[spi_state_b]		; MOSI already high and CLK low
	out		VIA1_PORTB,		al
	pop		ax		;retrieve read value

	pop		bx
	pop		cx
	pop		ds
	ret

spi_readbyte_port_a:
	push	ds
	push	bx
	push	cx
	call	to0000ds
	mov		cx,		0x08					; send 8 bits
	.loop:
		
		;mov		al,				SPI_MOSI	; enable card (CS low), set MOSI (resting state), SCK low
		mov		al,				[spi_state_a]		; MOSI already high and CLK low
		out		VIA1_PORTA,		al
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		or		al,				SPI_CLK		; toggle the clock high
		out		VIA1_PORTA,		al
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		in		al,				VIA1_PORTA	; read next bit
		and		al,				SPI_MISO
		clc									; default to clearing the bottom bit
		je		.readyByteBitNotSet			; unless MISO was set
		stc									; in which case get ready to set the bottom bit

		.readyByteBitNotSet:
			mov		al,				bl		; transfer partial result from bl
			rcl		al,				1		; rotate carry bit into read result
			mov		bl,				al		; save partial result back to bl
			loop	.loop					; loop if more bits

	; bring clock low
	push	ax				; save return value
	mov		al,				[spi_state_a]			
	out		VIA1_PORTA,		al	

	pop		ax				; retrieve return value
	pop		cx
	pop		bx
	pop		ds

	ret

spi_readbyte_port_a_slow:
	push	ds
	push	bx
	push	cx
	call	to0000ds
	mov		cx,		0x08					; send 8 bits
	.loop:
		
		;mov		al,				SPI_MOSI	; enable card (CS low), set MOSI (resting state), SCK low
		mov		al,				[spi_state_a]		; MOSI already high and CLK low
		out		VIA1_PORTA,		al

		push	cx
		push	si
		mov		cx,	SPI_SLOW_DELAY_LOW				; low word of counter
		mov		si,	0x0001				; high word of counter
		call	delay_configurable		; counts down from dword to zero
		pop		si
		pop		cx	

		or		al,				SPI_CLK		; toggle the clock high
		out		VIA1_PORTA,		al

		push	cx
		push	si
		mov		cx,	SPI_SLOW_DELAY_LOW				; low word of counter
		mov		si,	0x0001				; high word of counter
		call	delay_configurable		; counts down from dword to zero
		pop		si
		pop		cx	

		in		al,				VIA1_PORTA	; read next bit
		and		al,				SPI_MISO
		clc									; default to clearing the bottom bit
		je		.readyByteBitNotSet			; unless MISO was set
		stc									; in which case get ready to set the bottom bit

		.readyByteBitNotSet:
			mov		al,				bl		; transfer partial result from bl
			rcl		al,				1		; rotate carry bit into read result
			mov		bl,				al		; save partial result back to bl
			loop	.loop					; loop if more bits

	; bring clock low
	push	ax				; save return value
	mov		al,				[spi_state_a]			
	out		VIA1_PORTA,		al	

	pop		ax				; retrieve return value
	pop		cx
	pop		bx
	pop		ds

	ret

spi_readbyte_port_a_slower:
	push	ds
	push	bx
	push	cx
	call	to0000ds
	mov		cx,		0x08					; send 8 bits
	.loop:
		
		;mov		al,				SPI_MOSI	; enable card (CS low), set MOSI (resting state), SCK low
		mov		al,				[spi_state_a]		; MOSI already high and CLK low
		out		VIA1_PORTA,		al

		push	cx
		push	si
		mov		cx,	0x0009				; low word of counter
		mov		si,	0x0001				; high word of counter
		call	delay_configurable		; counts down from dword to zero
		pop		si
		pop		cx	

		or		al,				SPI_CLK		; toggle the clock high
		out		VIA1_PORTA,		al

		push	cx
		push	si
		mov		cx,	0x0009				; low word of counter
		mov		si,	0x0001				; high word of counter
		call	delay_configurable		; counts down from dword to zero
		pop		si
		pop		cx	

		in		al,				VIA1_PORTA	; read next bit
		and		al,				SPI_MISO
		clc									; default to clearing the bottom bit
		je		.readyByteBitNotSet			; unless MISO was set
		stc									; in which case get ready to set the bottom bit

		.readyByteBitNotSet:
			mov		al,				bl		; transfer partial result from bl
			rcl		al,				1		; rotate carry bit into read result
			mov		bl,				al		; save partial result back to bl
			loop	.loop					; loop if more bits

	; bring clock low
	push	ax				; save return value
	mov		al,				[spi_state_a]			
	out		VIA1_PORTA,		al	

	pop		ax				; retrieve return value
	pop		cx
	pop		bx
	pop		ds

	ret

spi_readbyte_port_a_mode_1:
	push	ds
	call	to0000ds
	push	bx
	push	cx

	mov		cx,		0x08					; send 8 bits
	.loop:
		
		mov		al,				[spi_state_a]		; MOSI already high and CLK low
		or		al,				SPI_CLK			; toggle the clock high
		out		VIA1_PORTA,		al
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		and		al,				~SPI_CLK		; toggle the clock low
		out		VIA1_PORTA,		al
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		in		al,				VIA1_PORTA	; read next bit
		and		al,				SPI_MISO
		clc									; default to clearing the bottom bit
		je		.readyByteBitNotSet			; unless MISO was set
		stc									; in which case get ready to set the bottom bit

		.readyByteBitNotSet:
			mov		al,				bl		; transfer partial result from bl
			rcl		al,				1		; rotate carry bit into read result
			mov		bl,				al		; save partial result back to bl
			loop	.loop					; loop if more bits


	; bring clock low
	push	ax
	mov		al,				[spi_state_a]			
	out		VIA1_PORTA,		al	
	pop		ax

	pop		cx
	pop		bx
	pop		ds
	ret

spi_send_NanoSerialCmd:
	; using SPI mode 0 (cpol=0, cpha=0)
	push	bx
	push	ds
	push	ax
	call	to0000ds

	mov		al,				(			SPI_CS2	| SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS1 low to enable, start with MOSI high and CLK low
	mov		[spi_state_a],		al
	out		VIA1_PORTA,		al		

	pop		ax						; get back original ax
	push	ax						; save it again to stack

	mov		al,				ah		; digit 1
	call	spi_writebyte_port_a	; write high byte (i.e., SPI cmd)
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high, keep MOSI high, and CLK low
	out		VIA1_PORTA,		al	
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	mov		al,				[spi_state_a]
	out		VIA1_PORTA,		al	

	pop		ax						; get back original ax
	push	ax						; save it again to stack
	call	spi_writebyte_port_a	; using original al, write low byte (parameter data for previously-sent cmd above)

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high, keep MOSI high, and CLK low
	out		VIA1_PORTA,		al	

	pop		ax
	pop		ds
	pop		bx
	ret

print_char_spi:
	; char to print in al
	push	ax
	mov		ah,		0x01				; spi cmd 1 - print char
	call	spi_send_NanoSerialCmd
	pop		ax
	ret

print_char_hex_spi:
	; char to print in al
	push	ax
	mov		ah,		0x02				; spi cmd 2 - print hex
	call	spi_send_NanoSerialCmd
	pop		ax
	ret

print_word_hex_spi:
	xchg	ah, al
	call	print_char_hex_spi
	xchg	ah, al
	call	print_char_hex_spi
	ret

print_char_binary_spi:
	; char to print in al
	push	ax
	mov		ah,		0x03				; spi cmd 2 - print hex
	call	spi_send_NanoSerialCmd
	pop		ax
	ret

print_char_newline_spi:
	push	ax
	mov		ax,		0x010a
	call	spi_send_NanoSerialCmd
	pop		ax
	ret

spi_send_NanoSerialCmd_ReadResponse:
	; using SPI mode 0 (cpol=0, cpha=0)
	; sends one to initiative request
	; sends a second to queue up data
	; third gets the data
	push	ds
	call	to0000ds
	push	bx
	push	ax			

	mov		al,				(			SPI_CS2	| SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS1 low to enable, start with MOSI high and CLK low
	mov		[spi_state_a],		al
	out		VIA1_PORTA,		al		

	pop		ax						; get back original ax

	mov		al,				ah		; digit 1
	call	spi_writebyte_port_a	; write high byte (i.e., SPI cmd)
	
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
		
	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high, keep MOSI high, and CLK low
	out		VIA1_PORTA,		al	
	
	call	delay		; give Nano time to fetch data from PC --- soooooo slooooow  :(
	call	delay
	call	delay
	call	delay
	call	delay
	call	delay
	call	delay
	call	delay
	call	delay
	call	delay
	call	delay
	
	;*************************************************************************************
	mov		al,				[spi_state_a]
	out		VIA1_PORTA,		al	

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	call	spi_readbyte_port_a	
	
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high, keep MOSI high, and CLK low
	out		VIA1_PORTA,		al	
	
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	
	;*************************************************************************************
	mov		al,				[spi_state_a]
	out		VIA1_PORTA,		al	

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	call	spi_readbyte_port_a	
	push	ax	; save for returning later
	
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high, keep MOSI high, and CLK low
	out		VIA1_PORTA,		al	

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	pop		ax
	pop		bx
	pop		ds
	ret

spi_getKeyboardMouseData:
	; using SPI mode 0 (cpol=0, cpha=0), port A, SPI_CS5
	push	ds
	call	to0000ds
	push	bx		; TO DO doesn't appear to be needed... verify & remove (and pop)
	push	ax
	
	;call	lcd_clear
	
	mov		al,				( SPI_CS1 | SPI_CS2	| SPI_CS3 | SPI_CS4			  | SPI_MOSI)					; drop SPI_CS5 low to enable, start with MOSI high and CLK low
	mov		[spi_state_a],		al
	out		VIA1_PORTA,		al		

	pop		ax						; get back original ax
	push	ax						; save it again to stack

	mov		al,		CMD_GET_KEYBOARD_MOUSE_DATA		; get mouse data CMD #
	call	spi_writebyte_port_a_slow	; write high byte (i.e., SPI cmd)

	
	; keyboard data format (2 bytes from SPI call) with lower byte char value and upper byte modifiers, such as shift/ctl
	call	spi_readbyte_port_a_slow
	and		ax,		0b00000000_11111111			; probably not needed
	shl		ax,		8
	mov		[keyboard_data],		ax			; modifier data (ctll, shift, ...)

	call	spi_readbyte_port_a_slow
	and		ax,		0b00000000_11111111			; probably not needed
	or		[keyboard_data],		ax			; modifier data (ctll, shift, ...)

	
	; mouse data format (3 bytes from SPI call) 00xxxxxx_xxxxyyyy_yyyyylmr
	call	spi_readbyte_port_a_slow
	and		ax,		0b00000000_00111111
	shl		ax,		4
	mov		[mouse_pos_x],			ax			; fill the left 6 bits of x pos

	call	spi_readbyte_port_a_slow			
	push	ax
	and		ax,		0b00000000_11110000			; fill the right 4 bits of x pos
	shr		ax,		4							;
	or		[mouse_pos_x],	ax					;
	pop		ax								
	and		ax,		0b00000000_00001111			; fill the left 4 bits of y pos
	shl		ax,		5							;
	mov		[mouse_pos_y],	ax					;

	call	spi_readbyte_port_a_slow
	push	ax
	and		ax,		0b00000000_11111000			; fill the right 5 bits of y pos
	shr		ax,		3							;
	or		[mouse_pos_y],		ax				;
	pop		ax
	and		ax,					0b00000000_00000111		; fill the 3 bits of button data
	mov		[mouse_buttons],	al						;

	
	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high, keep MOSI high, and CLK low
	out		VIA1_PORTA,		al	
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop


	pop		ax
	pop		bx
	pop		ds
	ret

spi_write_RTC:
	; ah = address
	; al = data

	push	ds
	push	bx
	push	ax
	call	to0000ds

	mov		al,				( SPI_CS1 |			SPI_CS3	| SPI_CS4 | SPI_CS5 | SPI_MOSI)			; drop SPI_CS3 low to enable, start with MOSI high and CLK low
	mov		[spi_state_a],		al
	out		VIA1_PORTA,		al		

	pop		ax								; get back original ax
	push	ax								; save it again to stack

	mov		al,				ah				; hi byte
	call	spi_writebyte_port_a_mode_1

	pop		ax								; get back original ax
	push	ax								; save it again to stack
	call	spi_writebyte_port_a_mode_1		; using original al = lo byte


	mov		al,				( SPI_CS1 |			SPI_CS3	| SPI_CS4 | SPI_CS5 | SPI_MOSI)			; CLK low
	out		VIA1_PORTA,		al	

	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high
	out		VIA1_PORTA,		al	

	pop		ax
	pop		bx
	pop		ds
	ret

spi_read_RTC:
	; al = address
	push	ds
	call	to0000ds
	push	ax

	mov		al,				( SPI_CS1 |			SPI_CS3	| SPI_CS4 | SPI_CS5 | SPI_MOSI)			; drop SPI_CS3 low to enable, start with MOSI high and CLK low
	mov		[spi_state_a],		al
	out		VIA1_PORTA,			al	

	pop		ax								; get back original ax
	;push	ax								; save it again to stack
	call	spi_writebyte_port_a_mode_1		; using original al

	nop
	nop
	nop
	nop
	nop
	nop


	call	spi_readbyte_port_a_mode_1	
	push	ax
	; call	print_char_hex

	mov		al,				( SPI_CS1 |			SPI_CS3	| SPI_CS4 | SPI_CS5 | SPI_MOSI)			; CLK low
	out		VIA1_PORTA,		al	

	mov		al,				(SPI_CS1| SPI_CS2 |	SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)			; bring SPI_CS3 high to disable
	out		VIA1_PORTA,		al	

	pop		ax
	pop		ds
	ret

_load_image_from_sdcard:
	mov		bx,		msg_sdcard_init
	call	print_string_to_serial

	call	delay			;remove? ...test
	call	delay


	; using SPI mode 0 (cpol=0, cpha=0)
	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; SPI_CS2 high (not enabled), start with MOSI high and CLK low
	out		VIA1_PORTB,		al	
	
	mov		si,				0x00a0			;80 full clock cycles to give card time to initiatlize
	.init_loop:
		xor		al,				SPI_CLK
		out		VIA1_PORTB,		al
		nop									; nops might not be needed... test reducing/removing
		nop
		nop
		nop
		dec		si
		cmp		si,				0    
		jnz		.init_loop

    .try00:													; GO_IDLE_STATE
		;mov		bx,		msg_sdcard_try00
		;call	print_string_to_serial

		mov		bx,		cmd0_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x01
		jne		.try00

		;mov		bx,		msg_sdcard_try00_done
		;call	print_string_to_serial


		;mov		bx,		msg_garbage
		;call	print_string_to_serial

	call	delay

	.try08:													; SEND_IF_COND

		;mov		bx,		msg_sdcard_try08
		;call	print_string_to_serial

		mov		bx,		cmd8_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x01
		jne		.try08

		;mov		bx,		msg_sdcard_try08_done
		;call	print_string_to_serial
		
		call	spi_readbyte_port_b							; read four bytes
		call	spi_readbyte_port_b
		call	spi_readbyte_port_b
		call	spi_readbyte_port_b

	.try55:													; APP_CMD
		;mov		bx,		msg_sdcard_try55
		;call	print_string_to_serial

		mov		bx,		cmd55_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x01
		jne		.try55

		;mov		bx,		msg_sdcard_try55_done
		;call	print_string_to_serial

	.try41:													; SD_SEND_OP_COND
		;mov		bx,		msg_sdcard_try41
		;call	print_string_to_serial

		mov		bx,		cmd41_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x00
		jne		.try55

		;mov		bx,		msg_sdcard_try41_done
		;call	print_string_to_serial

	.try18:													; READ_MULTIPLE_BLOCK, starting at 0x0
		;mov		bx,		msg_sdcard_try18
		;call	print_string_to_serial

		mov		bx,		cmd18_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand_noclose				; start reading SD card at 0x0


		; ** to do --	read bytes until 0xfe is returned
		;				this is where the actual data begins
		;call	spi_readbyte_port_b	
		;cmp		al,		0xfe							; 0xfe = have data
		;jne		.nodata									; if data avail, continue, otherwise jump to .nodata

		;;;;;;call	spi_sdcard_readimage	

		;mov		bx,		msg_sdcard_try18_done
		;call	print_string_to_serial
	
		jmp		.out

	.nodata:
		;mov		bx,		msg_sdcard_nodata
		;call	print_string_to_serial
	
	.out:

		mov		bx,		msg_sdcard_init_out
		call	print_string_to_serial
	ret

_spi_sdcard_readimage:
	pusha

	call	send_garbage
	mov		al,				(SPI_CS1|			SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS2 low to enable, start with MOSI high and CLK low
	mov		[spi_state_b],	al
	out		VIA1_PORTB,		al		
	call	send_garbage


	.filehdr:					
		; first real data from card is the byte after 0xfe is read... usually the first byte
		call	spi_readbyte_port_b	
		mov		ah,	0x02		; cmd02 = print hex
		call	spi_send_NanoSerialCmd
		cmp		al,	0xfe
		jne		.filehdr		; keep reading until 0xfe init value is found

		mov		ax,	0x010a		; cmd01 = print char - newline
		call	spi_send_NanoSerialCmd
		mov		ax,	0x010a		; cmd01 = print char - newline
		call	spi_send_NanoSerialCmd

	mov		bp, 0x0
	mov		cx, 0x0
	mov		dx, 0x0
	mov		si, 0xa000				; segment start (i.e., 0xa000 as top of video ram)
	mov		es, si
	mov		si, 32768

	in		ax,	VGA_REG
	and		ax, 0b1111_1111_1111_0000
	or		ax, cx
	out		VGA_REG,		ax

	.loop:
		cmp		dx,		512
		jne		.cont
			call	spi_readbyte_port_b			; read byte into al		; token & CRC every 512 bytes - read and ignore
			call	spi_readbyte_port_b			; read byte into al
			call	spi_readbyte_port_b			; read byte into al
			call	spi_readbyte_port_b			; read byte into al
			call	spi_readbyte_port_b			; read byte into al
			mov		dx, 0

		.cont:

		call	spi_readbyte_port_b			; read byte into al
		xchg	al,		ah					; put al into ah
		call	spi_readbyte_port_b			; read another byte into al
		xchg	al,		ah					; TO DO update graphic conversion util to swap order of lo/hi bytes so this line of code isn't needed

		mov		word es:[bp],	ax
		add		bp, 2
		
		;mov		ah,	0x02		; cmd02 = print hex
		;call	spi_send_NanoSerialCmd

		add		dx, 2

		dec		si
		jnz		.loop

		mov		si, 32768
		inc		cx

		in		ax,	VGA_REG
		and		ax, 0b1111_1111_1111_0000
		or		ax, cx
		out		VGA_REG,		ax
		cmp		cx, 15
		jne		.loop

		call	vga_swap_frame
		call	es_point_to_rom

	.out:
		call	send_garbage
		mov		al,				(SPI_CS1| SPI_CS2 |	SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS2 low to enable, start with MOSI high and CLK low
		mov		[spi_state_b],	al
		mov		bx,		cmd12_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

		mov		bx,		msg_sdcard_read_done
		call	print_string_to_serial
	popa
	ret
