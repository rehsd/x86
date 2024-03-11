via_init:
	; configure the port
	push	ax
	push	bx
	
	ds0000	; set ds to 0x0 (pushes original to stack)

	mov		al,				0b01111111			; disable all interrupts on VIA
	out		VIA1_IER,		al

	mov		al,				0b11111111			; set port pins to output
	out		VIA1_DDRB,		al
	out		VIA1_DDRA,	al
	
	mov		al,				0b00000000			; set initial port values to 0
	out		VIA1_PORTB,		al		
	out		VIA1_PORTA,		al		

	ds0000out	; returns ds to original state
	pop		bx
	pop		ax
	ret

via_test:
	push	eax
	push	ecx
	mov		al,				0b00000001
	out		VIA1_PORTB,		al		
	out		VIA1_PORTA,		al		
	
	mov		ecx, 7
	shift_loop:				; shift bit left & output -- repeat 7 times
		shl		ax, 1
		out		VIA1_PORTB,		al		
		out		VIA1_PORTA,		al		
		loop	shift_loop

	;mov		al,				0xff
	;out		VIA1_PORTB,		al		
	;out		VIA1_PORTA,		al		

	mov		al,				0x00
	out		VIA1_PORTB,		al		
	out		VIA1_PORTA,		al	

	pop		ecx
	pop		eax

	jmp		via_test		; infinite loop
	ret