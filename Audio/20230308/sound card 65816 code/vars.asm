;************************* General Addressing Overview ***********************************
;   RAM			                0x000000-0x006FFF           28K
;   DPRAM                       0x007000-0x0077FF            2K
;   I/O 10:0000                 0x007800-0x007AF           
;     VIA1 (SPI)		        0x007800
;     VIA2 (PSG_CTL, LCD)       0x007900
;     VIA3 (PSG_DATA, PSG_CTL)  0x007A00
;   UNUSED                      0x007B00-0x007FFF
;   ROM			                0x008000-0x00FFFF           32K
;************************* /General Addressing Overview **********************************

;************************* Basic RAM Use Summary ($0000 to $06FF) ************************
;   $0000 to $000E          VIA ports numbers
;   $0020 to $002F          Sound
;   $00A0 to #00AF          Misc
;   $2000 to $2FFF          Sound
;
;************************* /Basic RAM Use Summary*****************************************



;************************* VIAs *************************************
    ;These addresses are never to be used by themselves, rather to add to specific VIA base addresses
    ;VIA Registers
    VIA_PORTB = $00
    VIA_PORTA = $01
    VIA_DDRB  = $02
    VIA_DDRA  = $03
    VIA_T1C_L = $04
    VIA_T1C_H = $05
    VIA_T1L_L = $06
    VIA_T1L_H = $07
    VIA_T2C_L = $08
    VIA_T2C_H = $09
    VIA_SR    = $0A
    VIA_ACR   = $0B
    VIA_PCR   = $0C
    VIA_IFR   = $0D
    VIA_IER   = $0E

    ;VIA1 $7800
    VIA1_ADDR  = $7800
    VIA1_PORTB = VIA1_ADDR + VIA_PORTB
    VIA1_PORTA = VIA1_ADDR + VIA_PORTA
    VIA1_DDRB  = VIA1_ADDR + VIA_DDRB
    VIA1_DDRA  = VIA1_ADDR + VIA_DDRA
    VIA1_IFR   = VIA1_ADDR + VIA_IFR
    VIA1_IER   = VIA1_ADDR + VIA_IER

    ;VIA2 $7900
    VIA2_ADDR  = $7900
    VIA2_PORTB = VIA2_ADDR + VIA_PORTB
    VIA2_PORTA = VIA2_ADDR + VIA_PORTA
    VIA2_DDRB  = VIA2_ADDR + VIA_DDRB
    VIA2_DDRA  = VIA2_ADDR + VIA_DDRA
    VIA2_IFR   = VIA2_ADDR + VIA_IFR
    VIA2_IER   = VIA2_ADDR + VIA_IER

    ;VIA3 $7A00
    VIA3_ADDR  = $7A00
    VIA3_PORTB = VIA3_ADDR + VIA_PORTB
    VIA3_PORTA = VIA3_ADDR + VIA_PORTA
    VIA3_DDRB  = VIA3_ADDR + VIA_DDRB
    VIA3_DDRA  = VIA3_ADDR + VIA_DDRA
    VIA3_IFR   = VIA3_ADDR + VIA_IFR
    VIA3_IER   = VIA3_ADDR + VIA_IER
;************************* /VIAs *************************************

;************************* LCD *************************************
    E   = %01000000
    RW  = %00100000
    RS  = %00010000
;************************* /LCD *************************************

;**** MISC
  delayDuration     = $1100       ;Count from this number (high byte) to FF - higher number results in shorter delay
  TMP               = $A0                     ;Used by LCD routines for temporary storage


;**** SOUND
    TUNE_PTR_LO             = $0020
    TUNE_PTR_HI             = $0021
    zp_sd_cmd_address       = $0022       ;Two-byte pointer
    SPI_SDCard_Next_Command = $0024
    SPI_Timer               = $0026
    CMDtoProcess            = $0028     ;Set by interrupt to indicate DPRAM has queud commands to process; Set to 0 when finished processing queue on interrupt.

    toneDelayDuration       = $2000
    //Sound_ROW               = $2001     ;track with 'row' we are in for a sound sequence
    audio_data_to_write     = $2002       ;used to track when audio config data has been received from Arduino and should be processed in loop:

    SND_PSG                 = $2003     ;which programmable sound generator (i.e., AY) to use for CMD
    SND_CMD                 = $2004     ;when reading from SD Card, used to capture the current command number to process
    SND_VAL                 = $2005     ;used to capture the value to use with the current command

    SND_ROM_POS             = $2006     ;used to track media ROM read location MSB POS3_POS2_POS to LSB (19 bits req'd to access full 512KB of ROM)
    SND_ROM_POS2            = $2007
    SND_ROM_POS3            = $2008

    SND_SDCARD_POS          = $2009     ;used to track SD Card read location
    SND_SDCARD_POS2         = $200A     ;five bytes for addressing will give access to cards up to 128GB -- this shoud suffice :)
    SND_SDCARD_POS3         = $200B
    SND_SDCARD_POS4         = $200C
    SND_SDCARD_POS5         = $200D
    
    SND_ABORT_MUSIC         = $200E     ;If set to 1, abort playback of current song
    SND_MUSIC_PLAYING       = $2010

    TonePeriodCourseLA      = $2100     ;0
    TonePeriodCourseLB      = $2101
    TonePeriodCourseLC      = $2102
    TonePeriodCourseLD      = $2103
    TonePeriodCourseLE      = $2104
    TonePeriodCourseLF      = $2105
    TonePeriodFineLA        = $2106
    TonePeriodFineLB        = $2107
    TonePeriodFineLC        = $2108
    TonePeriodFineLD        = $2109
    TonePeriodFineLE        = $210A     ;10
    TonePeriodFineLF        = $210B
    VolumeLA                = $210C
    VolumeLB                = $210D
    VolumeLC                = $210E
    VolumeLD                = $210F
    VolumeLE                = $2110
    VolumeLF                = $2111
    TonePeriodCourseRA      = $2112
    TonePeriodCourseRB      = $2113
    TonePeriodCourseRC      = $2114     ;20
    TonePeriodCourseRD      = $2115
    TonePeriodCourseRE      = $2116
    TonePeriodCourseRF      = $2117
    TonePeriodFineRA        = $2118
    TonePeriodFineRB        = $2119
    TonePeriodFineRC        = $211A
    TonePeriodFineRD        = $211B
    TonePeriodFineRE        = $211C
    TonePeriodFineRF        = $211D
    VolumeRA                = $211E     ;30
    VolumeRB                = $211F     ;31
    VolumeRC                = $2120
    VolumeRD                = $2121
    VolumeRE                = $2122
    VolumeRF                = $2123
    NoisePeriodL1           = $2124
    EnvelopePeriodCourseL1  = $2125
    EnvelopePeriodFineL1    = $2126
    EnvelopeShapeCycleL1    = $2127
    EnableLeft1             = $2128     ;40
    EnableRight1            = $2129
    EnableLeft2             = $212A
    EnableRight2            = $212B
    NoisePeriodR1           = $212C
    EnvelopePeriodCourseR1  = $212D
    EnvelopePeriodFineR1    = $212E
    EnvelopeShapeCycleR1    = $212F
    NoisePeriodL2           = $2130
    EnvelopePeriodCourseL2  = $2131
    EnvelopePeriodFineL2    = $2132     ;50
    EnvelopeShapeCycleL2    = $2133
    NoisePeriodR2           = $2134
    EnvelopePeriodCourseR2  = $2135
    EnvelopePeriodFineR2    = $2136
    EnvelopeShapeCycleR2    = $2137
    SoundDelay              = $2138
    Sound_Future1           = $2139
    Sound_Future2           = $213A
    Sound_Future3           = $213B
    Sound_Future4           = $213C     ;60
    Sound_Future5           = $213D     
    Sound_Future6           = $213E
    Sound_EOF               = $213F     ;63 (64th byte... END)
    
    AY1_BC1                 = %00000001     //VIA3 Port B pins
    AY1_BDIR                = %00000010 
    AY2_BC1                 = %00000100    
    AY2_BDIR                = %00001000
    AY3_BC1                 = %00010000    
    AY3_BDIR                = %00100000
    AY4_BC1                 = %01000000    
    AY4_BDIR                = %10000000

    AY5_BC1                 = %00000001     //VIA 2 Port A pins  
    AY5_BDIR                = %00000010
    AY6_BC1                 = %00000100    
    AY6_BDIR                = %00001000

    ;VIA1 PORTB - SPI (VIA1 PORTA: Data)
    SPI_MISO                = %00000001     
    SPI_MOSI                = %00000010     
    SPI_SCK                 = %00000100     
    SPI_CS                  = %10000000     