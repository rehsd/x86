; EQU's

	;PPI1 (1602 LCD)						BUS_ADDR (BUS addresses are shifted one A2-->pin A1, A1-->pin A0)
	;Base address: 0x00E0					11100000
	;PPI1 pin values
	;A1=0, A0=0		PORTA					11100000	0x00E0
	;A1=0, A0=1		PORTB					11100010	0x00E2
	;A1=1, A0=0		PORTC					11100100	0x00E4
	;A1=1, A0=1		CONTROL REGISTER		11100110	0x00E6

	PPI1_PORTA	equ	0x00E0
	PPI1_PORTB	equ	0x00E2
	PPI1_PORTC	equ 0x00E4
	PPI1_CTL	equ	0x00E6

	;PPI2 (PS/2 Keyboard)
	PPI2_PORTA	equ	0x00E8
	PPI2_PORTB	equ	0x00EA
	PPI2_PORTC	equ 0x00EC
	PPI2_CTL	equ	0x00EE
	
	
	; ***** PPI1 Configuration *****
	;							1=I/O Mode	|	00=Mode 0	|	1=PA In		|	0=PC (upper 4) Out	|	0=Mode 0	|	0=PB Out	|	0=PC (lower 4) Out
	CTL_CFG_PA_IN		equ		0b10010000		;0x90

	;							1=I/O Mode	|	00=Mode 0	|	0=PA Out	|	0=PC (uppper 4) Out	|	0=Mode 0	|	0=PB Out	|	0=PC (lower 4) Out
	CTL_CFG_PA_OUT		equ		0b10000000		;0x80

	;							1=I/O Mode	|	00=Mode 0	|	0=PA Out	|	0=PC (uppper 4) Out	|	0=Mode 0	|	1=PB In		|	0=PC (lower 4) Out
	CTL_CFG_PB_IN		equ		0b10000010		;0x82

	RS	equ 0b00000001
	RW 	equ 0b00000010
	E 	equ 0b00000100

	; ***** Interrupt Controller *****
	;Base address: 0x0010						; BUS_A1 connected to pin A0 of PIC
	PICM_P0				equ	0x0010				; PIC Master Port 0		ICW1				OCW2, OCW3
	PICM_P1				equ	0x0012				; PIC Master Port 1		ICW2, ICW3, ICW4	OCW1
	; ********************************

	; ***** Video register *****
	VGA_REG				equ 0x00a0				; Control register for VGA 640 card
	; **************************
	SOUND_CARD_REG		equ 0x00b0

	KBD_BUFSIZE			equ 32					; Keyboard Buffer length. Must be a power of 2
		
	; ***** Interrupts ****						https://stanislavs.org/helppc/int_table.html
	DIVIDE_ER_IVT_OFFSET	equ 0x00*4				; Divide error (divide by zero)
	IVT_INT_01H				equ 0x01*4
	IVT_INT_02H				equ 0x02*4
	IVT_INT_03H				equ 0x03*4
	OVERFLOW_IVT_OFFSET		equ 0x04*4				; Overflow
	IVT_INT_05H				equ 0x05*4
	INVALID_OP_IVT_OFFSET	equ	0x06*4				; Invalid opcode
	IVT_INT_07H				equ 0x07*4
	MULTIPLE_XCP_IVT_OFFSET equ 0x08*4				; Multiple exceptions
	KBD_IVT_OFFSET			equ 0x09*4				; Base address of keyboard interrupt in IVT  // 9*4=36=0x24
													; Keyboard: IRQ1, interrupt number 0x09 (* 4 bytes per INT)
	MOUSE_IVT_OFFSET		equ 0x0A*4				; Base address of mouse interrupt in IVT  // 9*4=36=0x24
													; Keyboard: IRQ2, interrupt number 0x0A (10) (* 4 bytes per INT)
	IVT_INT_0BH				equ 0x0B*4
	IVT_INT_0CH				equ 0x0C*4
	IVT_INT_0DH				equ 0x0D*4
	IVT_INT_0EH				equ 0x0E*4
	IVT_INT_0FH				equ 0x0F*4
	INT10H_IVT_OFFSET		equ 0x10*4				; Video sevices			- Interrupt 0x10 (16)
	IVT_INT_11H				equ 0x11*4
	IVT_INT_12H				equ 0x12*4
	INT13H_IVT_OFFSET		equ 0x13*4				; Disk services
	IVT_INT_14H				equ 0x14*4
	IVT_INT_15H				equ 0x15*4
	IVT_INT_16H				equ 0x16*4
	IVT_INT_17H				equ 0x17*4
	IVT_INT_19H				equ 0x19*4
	IVT_INT_1AH				equ 0x1A*4
	IVT_INT_1BH				equ 0x1B*4
	IVT_INT_1CH				equ 0x1C*4
	IVT_INT_1DH				equ 0x1D*4
	IVT_INT_1EH				equ 0x1E*4
	IVT_INT_1FH				equ 0x1F*4
	IVT_INT_20H				equ 0x20*4
	INT21H_IVT_OFFSET		equ 0x21*4				; DOS Services
	IVT_INT_22H				equ 0x22*4
	IVT_INT_23H				equ 0x23*4
	IVT_INT_24H				equ 0x24*4
	IVT_INT_25H				equ 0x25*4
	IVT_INT_26H				equ 0x26*4
	IVT_INT_27H				equ 0x27*4
	IVT_INT_28H				equ 0x28*4
	IVT_INT_29H				equ 0x29*4
	IVT_INT_2AH				equ 0x2A*4
	IVT_INT_2BH				equ 0x2B*4
	IVT_INT_2CH				equ 0x2C*4
	IVT_INT_2DH				equ 0x2D*4
	IVT_INT_2EH				equ 0x2E*4
	IVT_INT_2FH				equ 0x2F*4
	INT33H_IVT_OFFSET		equ 0x33*4				; Mouse Services
	INT34H_IVT_OFFSET		equ 0x34*4				; Mouse button (to C++ app)

	; Bits for kb_flags
	RELEASE				equ		0b00000001
	SHIFT				equ		0b00000010
	KBD_DOS_LINE_READY	equ		0b10000000		; DOS COM controlling keyboard input

	; Bits for mouse_flags
	MOUSE_CURSOR_VISIBLE	equ	0b00000001
	CURSOR_INITIALIZED_ODD	equ 0b01000000
	CURSOR_INITIALIZED_EVEN	equ 0b10000000

	VIA1_PORTB	equ		0x0020			; read and write to port pins on port B
	VIA1_PORTA	equ		0x0022			; read and write to port pins on port A
	VIA1_DDRB	equ		0x0024			; configure read/write on port B
	VIA1_DDRA	equ		0x0026			; configure read/write on port A
	VIA1_IER	equ		0x003c			; modify interrupt information, such as which interrupts are processed


	; ****** SPI Configuration ******
	SPI_MISO    equ		0b00000001     
	SPI_MOSI    equ		0b00000010     
	SPI_CLK     equ		0b00000100     
											; support for 5 SPI devices per VIA port
											; *** PORT B ***								*** PORT A ***
	SPI_CS1     equ		0b10000000			; 8-digit 7-segment display						Arduino Nano serial output with I2C OLED
	SPI_CS2		equ		0b01000000			; SD card										tbd
	SPI_CS3		equ		0b00100000			; tbd											tbd
	SPI_CS4		equ		0b00010000			; tbd											Arduino Due with BIOS cache in onboard flash memory
	SPI_CS5		equ		0b00001000			; tbd											USB mouse

	CMD_DUE_RESET						equ 0x00		; General Reset of Due
	CMD_DUE_GETSTATUS					equ 0x01		; Retrieve status of Due (should be a 0x01 return)
	CMD_DUE_GETTWOBYTES					equ	0x02		; Not implemented
	CMD_DUE_GETBIOS					equ 0x03		; Get BIOS from Due flash
	CMD_DUE_FLUSH						equ 0xff		

	; *** Serial Debug Nano ***
	CMD_RESET							equ 0x0000		; General Reset of Nano
	CMD_PRINT_CHAR						equ 0x0100      ; Print to Serial
	CMD_PRINT_HEX8						equ 0x0200      ; Print to Serial
	CMD_PRINT_BINARY8					equ 0x0300      ; Print to Serial
	CMD_PRINT_HEX16						equ 0x0400      ; Print to Serial
	CMD_PRINT_BINARY16					equ 0x0500		; Print to Serial
	CMD_OLED_RESET						equ	0x0600		; Reset OLED
	CMD_PRINT_CHAR_OLED					equ 0x0700		; Print to OLED
	CMD_PRINT_STATUS_OLED				equ 0x0800		; Print to OLED
	CMD_CLEAR_OLED						equ 0x0900		; Clear OLED
	CMD_GET_BIOS						equ 0x0A00		; (10) Get BIOS from PC to Nano I2C Flash
	CMD_DISPLAY_CACHED_BIOS				equ	0x0B00		; (11) Display portions of cached BIOS for manual validation
	CMD_Get_BIOS_BYTE					equ	0x0C0C		; (12) Retrieves a single byte of a BIOS file on PC
	CMD_RESET_286						equ 0x0D00		; (13) Reset entire 286 system
	CMD_PRINT_INTERRUPT					equ 0x0E00		; (14) Print details based on interrupt 0x21, function number
	CMD_PRINT_INTERRUPT_10				equ 0x0F00		; (15) Print details based on interrupt 0x10, function number
	;xxx								equ 0x0B00		; ...

	; *** Keyboard, Mouse Nano ***
	CMD_GET_KEYBOARD_MOUSE_DATA		equ 0x01		; Get keyboard & mouse data from Nano (5 bytes of data)

	OLED_STATUS_RAM_TEST_BEGIN			equ	1;
	OLED_STATUS_RAM_TEST_FINISH			equ	2;
	OLED_STATUS_PPI1_TEST_BEGIN			equ 3;
	OLED_STATUS_PPI1_TEST_FINISH		equ 4;
	OLED_STATUS_PPI2_TEST_BEGIN			equ 5;
	OLED_STATUS_PPI2_TEST_FINISH		equ 6;
	OLED_STATUS_VIA1_TEST_BEGIN			equ 7;
	OLED_STATUS_VIA1_TEST_FINISH		equ 8;
	OLED_STATUS_MATHCO_TEST_BEGIN		equ 9;
	OLED_STATUS_MATHCO_TEST_FINISH		equ 10;
	OLED_STATUS_PIC_TEST_BEGIN			equ 11;
	OLED_STATUS_PIC_TEST_FINISH			equ 12;
	OLED_STATUS_VRAM_TEST_BEGIN			equ	13;
	OLED_STATUS_VRAM_TEST_FINISH		equ	14;
	OLED_STATUS_VGA_REG_TEST_BEGIN		equ	15;
	OLED_STATUS_VGA_REG_TEST_FINISH		equ	16;

	OLED_STATUS_RAM_TEST_FAIL			equ 20;
	OLED_STATUS_PPI1_TEST_FAIL			equ 21;
	OLED_STATUS_PPI2_TEST_FAIL			equ 22;
	OLED_STATUS_VIA1_TEST_FAIL			equ 23;
	OLED_STATUS_MATHCO_TEST_FAIL		equ 24;
	OLED_STATUS_PIC_TEST_FAIL			equ 25;
	OLED_STATUS_VRAM_TEST_FAIL			equ 26;
	OLED_STATUS_VGA_REG_TEST_FAIL		equ 27;

	OLED_STATUS_POST_COMPLETE			equ 50;
	OLED_STATUS_EXCEPTION				equ 100;

	PIXEL_COL1							equ	0b10000000
	PIXEL_COL2							equ 0b01000000
	PIXEL_COL3							equ 0b00100000
	PIXEL_COL4							equ 0b00010000
	PIXEL_COL5							equ 0b00001000

	SPI_SLOW_DELAY_LOW					equ	0x0001		; increase to add delay to slow SPI calls

	; IDE Controller Card				;base address 0x0040 (through 0x007f)
	;										0b01000000	(base)
	;								bit values:
	IDE_DA2								equ 0b00100000
	IDE_DA1								equ 0b00010000
	IDE_DA0								equ 0b00001000
	IDE_CS3								equ 0b00000100
	IDE_CS1								equ 0b00000010

	;Registers - Task File					0b01???10-		;CS3 high, CS1 low
	IDE_REG_DATA						equ 0b01000100		;RW						; 0x0044	(usually 0x01F0)
	IDE_REG_ERROR						equ 0b01001100		;R						; 0x004c
	IDE_REG_FEATURES					equ 0b01001100		;W						; 0x004c
	IDE_REG_SECT_COUNT					equ 0b01010100		;RW						; 0x0054
	IDE_REG_SECT_NUMBER					equ 0b01011100		;RW						; 0x005c
	IDE_REG_CYL_LOW						equ 0b01100100		;RW						; 0x0064
	IDE_REG_CYL_HIGH					equ 0b01101100		;RW						; 0x006c
	IDE_REG_DRIVE_HEAD					equ	0b01110100		;RW						; 0x0074	
	IDE_REG_STATUS						equ	0b01111100		;R						; 0x007c	(usually 0x01F7)
	IDE_REG_COMMAND						equ	0b01111100		;W

	;Registers - Alternate, Device Control	0b01???01-		;CS3 low, CS1 high
	;IDE_REG2_xxx						equ 0b01000010		;						; 0x0042	(usually 0x03f6)
	;...

; VARs
varstart:
	ivt times 1024			db		0x00				; prevent writing in the same space as the IVT
	mem_test_tmp			dw		0x0					; used for RAM testing
	ppi1_ccfg				db		0x0					; current config for PPI1
	ppi2_ccfg				db		0x0					; current config for PPI2
	spi_state_b				db		0x0					; track CS state for spi on via port b
	spi_state_a				db		0x0					; track CS state for spi on via port a

	AREA					dd		0x0					; store result of area calculation

	dec_num					db		0x0
	dec_num100s				db		0x0
	dec_num10s				db		0x0
	dec_num1s				db		0x0

	kb_flags				dw		0x0					; track status of keyboard input
	kb_wptr					dw		0x0					; keyboard buffer write pointer
	kb_rptr					dw		0x0					; keyboard buffer read pointer
	;dummy1					dw		0x0					; keep even boundary -- should the assembler take care of this?
	
	kb_buffer times 128		dw      0x0					; 128-word keyboard buffer
	os_buffer times 128		dw      0x0					; 128-word buffer for operating system keyboard input (i.e., commands)
	os_buffer_wptr			dw		0x0					; os keyboard input write pointer

	current_char			dw		0x0					; current char for VGA output
	cursor_pos_h			dw		0x0					; horizontal position (pixel #) of text cursor
	cursor_pos_v			dw		0x0					; vertical position (pixel #) of text cursor
	pixel_offset_h			dw		0x0
	pixel_offset_v			dw		0x0
	
	charPixelRowLoopCounter	dw		0x0					; row pos when processing a char
	charpix_line1			db		0x0
	charpix_line2			db		0x0
	charpix_line3			db		0x0
	charpix_line4			db		0x0
	charpix_line5			db		0x0
	charpix_line6			db		0x0
	charpix_line7			db		0x0
	sprite_inc				db		0x0
	vga_param_color			dw		0x0
	vga_rect_start_x		dw		0x0
	vga_rect_start_y		dw		0x0
	vga_rect_end_x			dw		0x0
	vga_rect_end_y			dw		0x0
	print_char_options		dw		0x0			;bit0=1=single frame only

	mouse_buttons			dw		0x0
	mouse_buttons_prev		dw		0x0
	mouse_pos_x				dw		0x0			; horizontal position (pixel #) of mouse pointer
	mouse_pos_y				dw		0x0			; vertical position (pixel #) of mouse pointer 
	mouse_pos_x_prev_e		dw		0x0
	mouse_pos_y_prev_e		dw		0x0
	mouse_pos_x_prev_o		dw		0x0
	mouse_pos_y_prev_o		dw		0x0
	mouse_flags				dw		0x0
	tile5e_backup times 25	dw		0x0			; 4x4, word per pixel for color = 16 words (even frame)
	tile5o_backup times 25	dw		0x0			; 4x4, word per pixel for color = 16 words (odd frame)

	keyboard_data			dw		0x0
		
	; line drawing temps
	temp_w					dw		0x0
	pointX					dw		0x0 
	pointY					dw		0x0
		
	; disk drive
	drive_buffer times 256	dw		0x0			; buffer to hold the drive identification inf
	; disk drive info							; [index in identy drive data, in words]
	di_d0_num_cyl			dw		0x0			; [1] default number of cylinders for disk 0
	di_d0_num_heads			dw		0x0			; [3] default number of heads
	di_d0_bytes_sect		dw		0x0			; [5] default number of bytes per sector
	di_d0_curr_num_cyl		dw		0x0			; [54] current number of cylinders
	di_d0_curr_num_heads	dw		0x0			; [55] current number of heads
	di_d0_curr_capacity_lo	dw		0x0			; [57] current capacity in sectors (LBAs) lsw
	di_d0_curr_capacity_hi	dw		0x0			; [58] current capacity in sectors (LBAs) msw
	di_d0_sectors_addressbl dd		0x0			; [60-61] total number of sectors addressable in LBA Mode

	marker times 16		db		0xbb			; just for visibility in the rom
varend: