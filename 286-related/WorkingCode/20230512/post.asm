post_tests:
	;call	post_RAM
	;call	post_VideoRegister
	;call	post_VRAM
	;call	post_PPIs
	call	post_VIA
	call	post_MathCo
	call	post_PIC
	call	post_Complete

	ret

_post_VideoRegister:
	push	ax

	mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_VGA_REG_TEST_BEGIN
	call	spi_send_NanoSerialCmd

	mov		ax,				0b0000_1111_1110_0000			
	out		VGA_REG,		ax
	in		ax,				VGA_REG
	and		ax,				0b0111_1111_1111_1111	; ignore first bit - it is read only from the 286
	cmp		ax,				0b0000_1111_1110_0000
	je		.pass

	.fail:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_VGA_REG_TEST_FAIL
		call	spi_send_NanoSerialCmd
		jmp		.out
	.pass:
		mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_VGA_REG_TEST_FINISH
		call	spi_send_NanoSerialCmd
		; fall into .out
	.out:
		mov		ax,				0b1000_0000_0000_0000			; set proper starter values (bit 15 is read only)
		out		VGA_REG,		ax
		pop		ax
		ret

_post_VRAM:
	; VRAM		Accessed through 0xA0000-0xAFFFF segment
	;			Two frames - each at 1 MB,	with lower 0.5 MB of each used by VGA output
	;										upper 0.5 MB can be used as general memory
	;			Each frame contains 16 segments of 64 KB
	;			Active frame set via I/O register at A0
	;			Active segment also set via I/O register at A0. Register bits:
	;				5=System Frame Number
	;				4=VGA Out Frame Number (5#)
	;				3=Segment_bit3
	;				2=Segment_bit2
	;				1=Segment_bit1
	;				0=Segment_bit0

	; !! Currently testing the first 64 KB of VRAM frame 1 only !!

	push	ax
	push	bp
	push	si

	mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_VRAM_TEST_BEGIN
	call	spi_send_NanoSerialCmd


	; TO DO - Set VRAM frame & segment with register (I/O 0xA0)
		; assuming frame 0 and segment 0 for now

	mov		bp, 0xfffe				; offset within segment - will start by subtracting 0x01 (i.e., 0xffff down to 0x0000)
	mov		si, 0xa000				; segment start (i.e., 0x9000 as top)
	mov		es, si

	.offset:
		mov		ax,				es:[bp]			; backup test location
		mov		[mem_test_tmp],	ax

		mov		word es:[bp],	0xdbdb			; write a test value to the location
		mov		ax,				es:[bp]			; read the test value back
		cmp		ax,				0xdbdb			; make sure the value read matches what was written
		mov		ax,				[mem_test_tmp]	; put the original value back in the location being tested
		mov		es:[bp],		ax				; -
		jne		.fail							; if no match, fail

		sub		bp,				2				; if pass, drop down a word
		cmp		bp,				0xfffe			; if equal, it wrapped around - done with this segment
		jnz		.offset

		sub		si,	0x1000						; process segment 0xa0000
		mov		es, si

		cmp		si,	0x9000						; if equal, done with all segment
		jnz		.offset
		jmp		.pass

	.fail:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_VRAM_TEST_FAIL
		call	spi_send_NanoSerialCmd
		jmp		.out
	.pass:
		mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_VRAM_TEST_FINISH
		call	spi_send_NanoSerialCmd
	.out:
		call	es_point_to_rom

		pop		si
		pop		bp
		pop		ax
		ret

_post_RAM:
	; RAM  (640 KB) = 0x00000-0x9FFFF
	; assuming ds=0x0000

	push	ax
	push	bx
	push	bp
	push	si

	mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_RAM_TEST_BEGIN
	call	spi_send_NanoSerialCmd

	mov		bx,	0x0009				; counter for LED output
	mov		bp, 0xfffe				; offset within segment - will start by subtracting 0x01 (i.e., 0xffff down to 0x0000)
	mov		si, 0x9000				; segment start (i.e., 0x9000 as top)
	mov		es, si

	;mov		ax,						0b00000101_00001001			; digit (0-)4 = '9'
	;call	spi_send_LEDcmd

	.offset:
		mov		ax,				es:[bp]			; backup test location
		mov		[mem_test_tmp],	ax

		mov		word es:[bp],	0xdbdb			; write a test value to the location
		mov		ax,				es:[bp]			; read the test value back
		cmp		ax,				0xdbdb			; make sure the value read matches what was written
		mov		ax,				[mem_test_tmp]	; put the original value back in the location being tested
		mov		es:[bp],		ax				; -
		jne		.fail							; if no match, fail

		sub		bp,				2				; if pass, drop down a word
		cmp		bp,				0xfffe			; if equal, it wrapped around - done with this segment
		jnz		.offset

		dec		bx								; shift to the next segment
		sub		si,	0x1000						; process segments 0x9000 down to 0x0000
		mov		es, si

		mov		ax,				0x0500			; desired LED character position
		add		ax,	bx							; add value to display (in al)
		;call	spi_send_LEDcmd

		;cmp		si,	0xf000						; if equal, it wrapped around- done with all segments
		cmp		si,	0x8000						; only testing one segment for now
		jnz		.offset
		jmp		.pass

	.fail:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_RAM_TEST_FAIL
		call	spi_send_NanoSerialCmd
		jmp		.out
	.pass:
		mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_RAM_TEST_FINISH
		call	spi_send_NanoSerialCmd
	.out:
		mov		ax,				0b00000101_00001010	; desired LED character position
		;call	spi_send_LEDcmd
		mov		ax,				0b00000100_00001010	; desired LED character position
		;call	spi_send_LEDcmd

		call	es_point_to_rom

		pop		si
		pop		bp
		pop		bx
		pop		ax
		ret

post_PPIs:
	; this testing requires a PPI that supports reading the configuration
	; Intersil 82c55a - yes (to verify)
	; Harris - yes (to verify)
	; Renesas - yes (to verify)
	; OKI 82c55a - no
	; NEC pd8255a - no

	push	ax
	push	dx

	; *** PPI1 ***
	mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_PPI1_TEST_BEGIN
	call	spi_send_NanoSerialCmd
	
	; do not currently have a PPI that supports reading control register
	jmp		.pass1

	mov		dx,			PPI1_CTL			; Get control port address
	mov		al,			CTL_CFG_PA_IN		; 0b10010000
	call	print_char_hex					; for debugging
	out		dx,			al					; Write control register on PPI
	in		al,			dx					; Read control register on PPI
	call	print_char_hex					; for debugging
	cmp		al,			CTL_CFG_PA_IN		; Compare to latest config
	
	mov		al,			[ppi1_ccfg]			; Restore value from prior to testing

	jne		.fail1
	jmp		.pass1

	.fail1:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PPI1_TEST_FAIL
		call	spi_send_NanoSerialCmd
		jmp		.out1
	.pass1:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PPI1_TEST_FINISH
		call	spi_send_NanoSerialCmd
	.out1:


	; *** PPI2 ***
	mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PPI2_TEST_BEGIN
	call	spi_send_NanoSerialCmd

	; do not currently have a PPI that supports reading control register
	jmp		.pass2

	mov		dx,			PPI2_CTL			; Get control port address
	in		al,			dx					; Read control register on PPI
	cmp		al,			[ppi2_ccfg]			; Compare to latest config
	jne		.fail2
	jmp		.pass2

	jmp		.pass2
	.fail2:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PPI2_TEST_FAIL
		call	spi_send_NanoSerialCmd
		jmp		.out2
	.pass2:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PPI2_TEST_FINISH
		call	spi_send_NanoSerialCmd
	.out2:
		pop		dx
		pop		ax
		ret

post_VIA:
	push	ax

	mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_VIA1_TEST_BEGIN
	call	spi_send_NanoSerialCmd

	mov		al,				0b11111111			
	out		VIA1_IER,		al					; enable all interrupts on VIA
	in		al,				VIA1_IER			
	add		al,				0x01				; should be all ones... add one, should be all zeros
	jnz		.fail								; if not all zeros, fail
	mov		al,				0b01111111			
	out		VIA1_IER,		al					; disable all interrupts on VIA
	in		al,				VIA1_IER			; bit 7 will be 1, then 1 for all bits enabled
	cmp		al,				0b10000000			; if all interrupts disabled, should be 0b10000000
	jne		.fail
	jmp		.pass

	.fail:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_VIA1_TEST_FAIL
		call	spi_send_NanoSerialCmd
		jmp		.out
	.pass:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_VIA1_TEST_FINISH
		call	spi_send_NanoSerialCmd
	.out:
		pop		ax
		ret

post_MathCo:
	push	ax
	push	ds
	call	to0000ds
	
	mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_MATHCO_TEST_BEGIN						; cmd08 = print status, 9 = MathCo test begin
	call	spi_send_NanoSerialCmd

	; To test the math coprocessor, calculate the area of a circle
	; R = radius, stored in .rodata =  91.67 = 42b7570a (0a57b742 in ROM)
	
	;mov		ax,		ES:[R+3]				; 42
	;mov		ax,		ES:[R+2]				; b7
	;mov		ax,		ES:[R+1]				; 57
	;mov		ax,		ES:[R]					; 0a

	finit									; Initialize math coprocessor
	fld		dword ES:[R]					; Load radius
	fmul	st0,st0							; Square radius
	fldpi									; Load pi
	fmul	st0,st1							; Multiply pi by radius squared
	
	fstp	dword [AREA]					; Store calculated area
											; Should be 26400.0232375 = 46ce400c (0c40ce46 in RAM)
	
	call	delay							; Some delay required here
	call	delay							; Some delay required here

	; Compare actual result with expected result
	mov		ax,		[AREA+2]
	cmp		ax,		0x46ce
	jne		.fail

	mov		ax,		[AREA]
	cmp		ax,		0x400c
	jne		.fail

	jmp		.pass
	
	.fail:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_MATHCO_TEST_FAIL			; cmd08 = print status, 24 = MathCo test fail
		call	spi_send_NanoSerialCmd
		jmp		.out
	.pass:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_MATHCO_TEST_FINISH		; cmd08 = print status, 10 (0x0A) = MathCo test finish
		call	spi_send_NanoSerialCmd
	.out:
		pop		ax
		pop		ds
		ret

post_PIC:
	push	dx
	push	ax

	mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PIC_TEST_BEGIN
	call	spi_send_NanoSerialCmd

	; write/read warm-up
	mov		dx,		PICM_P1			; address for port 1 (will use ocw1)
	mov		al,		0x0				; set IMR to zero (unmask all interrupts)
	out		dx,		al		
	in		al,		dx				; read IMR
	mov		al,		0xff			; set IMR to zero (unmask all interrupts)
	out		dx,		al		
	in		al,		dx				; read IMR

	
	; *** Test procedure from IBM BIOS Technical Reference
	mov		dx,		PICM_P1			; address for port 1 (will use ocw1)
	mov		al,		0x0				; set IMR to zero (unmask all interrupts)
	out		dx,		al		
	in		al,		dx				; read IMR
	or		al,		al
	jnz		.fail					; if not zero, error
	mov		al,		0xff			
	out		dx,		al				; mask (disable) all interrupts
	in		al,		dx				; read IMR
	; to do replace the following line with inc instead of add
	add		al,		0x01			; should be all ones... +1 = all zeros
	jnz		.fail					; if not all zeros, error
	jmp		.pass

	.fail:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PIC_TEST_FAIL
		call	spi_send_NanoSerialCmd
		jmp		.out
	.pass:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PIC_TEST_FINISH
		call	spi_send_NanoSerialCmd
	.out:
		; to do: restore IMR to pre-test state (currently, enabling all interrupts -- could change in the future)
		pop		ax
		pop		dx
		ret

post_Complete:
	mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_POST_COMPLETE
	call	spi_send_NanoSerialCmd
	ret
