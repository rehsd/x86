; EQU's

	GLOBAL_ALIGNMENT	equ		2

	ROM_START				equ	0xE000

	; ***** Interrupt Controller *****
	;Base address: 0x0010						; BUS_A2 connected to pin A0 of PIC
	PICM_P0				equ	0x0010				; PIC Master Port 0		ICW1				OCW2, OCW3
	PICM_P1				equ	0x0014				; PIC Master Port 1		ICW2, ICW3, ICW4	OCW1
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
	IVT_INT_08H				equ 0x08*4				; Timer
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

	VIA1_PORTB	equ		0x0040			; read and write to port pins on port B
	VIA1_PORTA	equ		0x0044			; read and write to port pins on port A
	VIA1_DDRB	equ		0x0048			; configure read/write on port B
	VIA1_DDRA	equ		0x004C			; configure read/write on port A
	VIA1_T1C_L	equ		0x0050			; T1 low-order counter	(timer 1)
	VIA1_T1C_H	equ		0x0054			; T1 high-order counter
	VIA1_T1L_L	equ		0x0058			; T1 low-order latches
	VIA1_T1L_H	equ		0x005C			; T1 high-order latches
	VIA1_T2L_L	equ		0x0060			; T2 low-order counter	(timer 2)
	VIA1_T2L_H	equ		0x0064			; T2 high-order counter
	VIA1_SR		equ		0x0068			; shift register
	VIA1_ACR	equ		0x006C			; auxiliary control register
	VIA1_PCR	equ		0x0070			; peripheral control register
	VIA1_IFR	equ		0x0074			; interrupt flag register
	VIA1_IER	equ		0x0078			; modify interrupt information, such as which interrupts are processed
	VIA1_PORTAN	equ		0x007C			; read and write to port pins on port A, no handshake
	
	VIA1_TIMER	equ		0xec18			; value to set for T1, target is 18.2 times per second, or ~55ms
	VIA1_T_CMP	equ		10				; 1 / PCLK * VIA1_TIMER = ~5.494 ==> * 10 (VIA1_T_CMP) = 54.945 (where 10 is the # of interrupts, given a value for VIA1_TIMER1 - used in isr_int_08h CMP)
										; VIA1_TIMER = 5.4945 * PCLK / 1000
										; For 11 MHz PCLK, VIA1_TIMER = 60440 (0xec18)
										; For 10 MHz PCLK, VIA1_TIMER = 54945 (0xd6a1)
										; For 8 MHz PCLK,  VIA1_TIMER = 43956 (0xabb4)

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

	; IDE Controller Card				;base address 0x0080 (through 0x009f)
	;IDE_BASE							equ 0b100xxxx0		;set with jumpers a7..a5		-b0 is always even to support 286 odd/even byte transfer
	IDE_CS1_3							equ 0b00001000
	IDE_DA2								equ 0b00000100
	IDE_DA1								equ 0b00000010
	IDE_DA0								equ 0b00000001

	;Registers - Task File					0b100_0_???_0		;CS3 high, CS1 low			jjjcaaa0   j=jumper, c=cs1/3, a=addr3..1, b0 always 0

	IDE_REG_DATA						equ 0b10000000		;RW						; 0x0080	(usually 0x01F0)
	IDE_REG_ERROR						equ 0b10000010		;R						; 0x0082	(usually 0x01F1)
	IDE_REG_FEATURES					equ 0b10000010		;W						; 0x0082	(usually 0x01F1)
	IDE_REG_SECT_COUNT					equ 0b10000100		;RW						; 0x0084	(usually 0x01F2)
	IDE_REG_SECT_NUMBER					equ 0b10000110		;RW						; 0x0086	(usually 0x01F3)
	IDE_REG_CYL_LOW						equ 0b10001000		;RW						; 0x0088	(usually 0x01F4)
	IDE_REG_CYL_HIGH					equ 0b10001010		;RW						; 0x008a	(usually 0x01F5)
	IDE_REG_DRIVE_HEAD					equ	0b10001100		;RW						; 0x008c	(usually 0x01F6)
	IDE_REG_STATUS						equ	0b10001110		;R						; 0x008e	(usually 0x01F7)
	IDE_REG_COMMAND						equ	0b10001110		;W						; 0x008e	(usually 0x01F7)

	;Registers - Alternate, Device Control	0b100_1_???_0		;CS3 low, CS1 high		jjjcaaa0   j=jumper, c=cs1/3, a=addr3..1, b0 always 0
	;IDE_REG2_xxx						equ 0b10010000		;						; 0x0090	(usually 0x03f6)
	;...
	;IDE_REG2_xxx						equ 0b10011110		;						; 0x009e	(usually 0x03f6)

	;IDE LBA 
	DAPACK								equ 0x00
	BLKCNT								equ 0x02
	DB_ADD								equ 0x04
	D_LBA								equ 0x08

	RAM_CARD_REGISTER					equ	0x60			; 6-bit value to select 64K segment in RAM card (4MB max) -- 16 segments per 1MB (pair of 512KB SRAMs)


