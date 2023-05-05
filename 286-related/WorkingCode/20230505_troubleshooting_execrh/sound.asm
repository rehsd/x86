test_sound_card:
	push	es
	push	ax

	push	0xb000
	pop		es
	
	;mov		word es:[0],		0xabcd
	;mov		ax,			word es:[0]
	; verify read back from dual-port SRAM correctly
	;call	print_char_hex
	;xchg	ah, al
	;call	print_char_hex

	mov		byte es:[2],		0x06		; song number to play
	mov		al,	1
	out		SOUND_CARD_REG,		al			; activate interrupt
	call	delay
	mov		al,	0
	out		SOUND_CARD_REG,		al			; release interrupt

	pop		ax
	pop		es

	ret

play_sound:
	push	ax
	push	dx

	mov		al,				CTL_CFG_PA_OUT				; Get config value - PA_OUT includes PB_OUT also
	mov		dx,				PPI1_CTL					; Get control port address
	out		dx,				al							; Write control register on PPI
	;mov		[ppi1_ccfg],	al							; Remember current config

	mov		bp, 0x01FF									; Number of "sine" waves (-1) - duration of sound
	.wave:
		.up:
			mov		al,		0x1
			mov		dx,		PPI1_PORTC					; Get C port address
			out		dx,		al							; Write data to port C
			mov		si,		0x0060						; Hold duration of "up"

			.uploop:
				nop
				dec		si
				cmp		si,	0
				jnz		.uploop

		.down:
			mov		al,		0x0
			mov		dx,		PPI1_PORTC					; Get C port address
			out		dx,		al							; Write data to port C
			mov		si,		0x0060						; Hold duration of "down"

			.downloop:
				nop
				dec		si
				cmp		si,	0
				jnz		.downloop

		dec		bp
		jnz		.wave

	mov		bp, 0x00FF				; Number of "sine" waves (-1) - duratin of sound
	.wave2:
		.up2:
			mov		al,		0x1
			mov		dx,		PPI1_PORTC			; Get C port address
			out		dx,		al					; Write data to port C
			mov		si,		0x0050				; Hold duration of "up"

			.uploop2:
				nop
				dec		si
				cmp		si,	0
				jnz		.uploop2

		.down2:
			mov		al,		0x0
			mov		dx,		PPI1_PORTC			; Get C port address
			out		dx,		al					; Write data to port C
			mov		si,		0x0050				; Hold duration of "down"

			.downloop2:
				nop
				dec		si
				cmp		si,	0
				jnz		.downloop2

		dec		bp
		jnz		.wave2

	.out:
		pop		dx
		pop		ax

		ret

play_error_sound:
	push	ax
	push	dx

	mov		al,				CTL_CFG_PA_OUT				; Get config value - PA_OUT includes PB_OUT also
	mov		dx,				PPI1_CTL					; Get control port address
	out		dx,				al							; Write control register on PPI
	;mov		[ppi1_ccfg],	al							; Remember current config

	mov		bp, 0x06FF									; Number of "sine" waves (-1) - duration of sound
	.wave:
		.up:
			mov		al,		0x1
			mov		dx,		PPI1_PORTC					; Get C port address
			out		dx,		al							; Write data to port C
			mov		si,		0x0070						; Hold duration of "up"

			.uploop:
				nop
				dec		si
				cmp		si,	0
				jnz		.uploop

		.down:
			mov		al,		0x0
			mov		dx,		PPI1_PORTC					; Get C port address
			out		dx,		al							; Write data to port C
			mov		si,		0x0070						; Hold duration of "down"

			.downloop:
				nop
				dec		si
				cmp		si,	0
				jnz		.downloop

		dec		bp
		jnz		.wave

	.out:
		pop		dx
		pop		ax

		ret