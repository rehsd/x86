/*
 Name:		Arduino_PSG_Controller_XL__Mega.ino
 Created:	5/9/2022 8:33:00 AM
 Author:	rehsd
*/


#define PSG1_BC1	22			//PA0
#define PSG1_BDIR	23			//PA1
#define PSG2_BC1	24			//PA2
#define PSG2_BDIR	25			//PA3
#define PSG3_BC1	26			//PA4
#define PSG3_BDIR	27			//PA5
#define PSG4_BC1	28			//PA6
#define PSG4_BDIR	29			//PA7
#define PSG5_BC1	37			//PC0
#define PSG5_BDIR	36			//PC1
#define PSG6_BC1	35			//PC2
#define PSG6_BDIR	34			//PC3

#define RESB		41

#define D7			42			//PL7
#define D6			43			//PL6
#define D5			44			//PL5
#define D4			45			//PL4
#define D3			46			//PL3
#define D2			47			//PL2
#define D1			48			//PL1
#define D0			49			//PL0

//const int STD_DELAY = 10;

const int R00_ChA_Fine = 0;
const int R01_ChA_Course = 1;
const int R02_ChB_Fine = 2;
const int R03_ChB_Course = 3;
const int R04_ChC_Fine = 4;
const int R05_ChC_Course = 5;
const int R06_NoisePeriod = 6;
const int R07_EnableB = 7;
const int R08_ChA_Amplitude = 8;
const int R09_ChB_Amplitude = 9;
const int R10_ChC_Amplitude = 10;
const int R11_EnvPeriod_Fine = 11;
const int R12_EnvPeriod_Course = 12;
const int R13_EnvShape = 13;
const int R14_IO_PortA = 14;
const int R15_IO_PortB = 15;

const int PSG1 = 1;
const int PSG2 = 2;
const int PSG3 = 3;
const int PSG4 = 4;
const int PSG5 = 5;
const int PSG6 = 6;

const byte BIT_PSG1_BC1		= 0b00000001;		//PA0
const byte BIT_PSG1_BDIR	= 0b00000010;		//PA1
const byte BIT_PSG2_BC1		= 0b00000100;		//PA2
const byte BIT_PSG2_BDIR	= 0b00001000;		//PA3
const byte BIT_PSG3_BC1		= 0b00010000;		//PA4
const byte BIT_PSG3_BDIR	= 0b00100000;		//PA5
const byte BIT_PSG4_BC1		= 0b01000000;		//PA6
const byte BIT_PSG4_BDIR	= 0b10000000;		//PA7

const byte BIT_PSG5_BC1		= 0b00000001;		//PC0
const byte BIT_PSG5_BDIR	= 0b00000010;		//PC1
const byte BIT_PSG6_BC1		= 0b00000100;		//PC2
const byte BIT_PSG6_BDIR	= 0b00001000;		//PC3

const byte BIT_PSG1_ANDMASK = 0b11111100;
const byte BIT_PSG2_ANDMASK = 0b11110011;
const byte BIT_PSG3_ANDMASK = 0b11001111;
const byte BIT_PSG4_ANDMASK = 0b00111111;

const byte BIT_PSG5_ANDMASK = 0b11111100;
const byte BIT_PSG6_ANDMASK = 0b11110011;


// the setup function runs once when you press reset or power the board
void setup() {
	pinMode(RESB, OUTPUT);
	pinMode(PSG1_BC1, OUTPUT);
	pinMode(PSG1_BDIR, OUTPUT);
	pinMode(PSG2_BC1, OUTPUT);
	pinMode(PSG2_BDIR, OUTPUT);
	pinMode(PSG3_BC1, OUTPUT);
	pinMode(PSG3_BDIR, OUTPUT);
	pinMode(PSG4_BC1, OUTPUT);
	pinMode(PSG4_BDIR, OUTPUT);
	pinMode(PSG5_BC1, OUTPUT);
	pinMode(PSG5_BDIR, OUTPUT);
	pinMode(PSG6_BC1, OUTPUT);
	pinMode(PSG6_BDIR, OUTPUT);
	pinMode(D7, OUTPUT);
	pinMode(D6, OUTPUT);
	pinMode(D5, OUTPUT);
	pinMode(D4, OUTPUT);
	pinMode(D3, OUTPUT);
	pinMode(D2, OUTPUT);
	pinMode(D1, OUTPUT);
	pinMode(D0, OUTPUT);

	Serial.begin(115200);
	Serial.println();
	resetPSGs();
}

void loop() {
	String selection;
	Serial.println("Choose Action:\n('R') Reset PSG\n(0xPRVV) PSG+Register+Value\n(0xV0..VF) Values of all registers\n>\n");
	while (Serial.available() == 0)
	{
		//sit and wait 
	}
	selection = Serial.readString();
	//Serial.println("You selected '" + selection + "'");
	if (selection == "X" || selection == "x")
	{
		Serial.println("Welcome to the Arduino PSG Controller!");
	}
	else if (selection == "R" || selection == "r")
	{
		resetPSGs();
		Serial.println("PSG reset complete!\n\n");
	}
	else if (selection.length() == 4)
	{
		//TO DO Improve validation. Assuming good inputs for now.
		int psg = ((strtol(selection.c_str(), NULL, 16) & 0xF000) >> 12);
		int reg = (strtol(selection.c_str(), NULL, 16) & 0x0F00) >> 8;
		int val = (strtol(selection.c_str(), NULL, 16) & 0x00FF);
		setRegAndValue(psg, reg, val);
		Serial.println("Register set complete!\n\n");
	}
	//else if (selection.length() == 32)			//single-PSG
	//{
	//	for (int v = 0, r = 0; v < 32; v += 2, r++)
	//	{
	//		setRegAndValue(r, strtol(selection.substring(v, v + 2).c_str(), NULL, 16));
	//	}
	//	Serial.println("All registers set!\n\n");
	//}
	else if (selection.length() == 192)			//single-PSG
	{
		//Serial.println("here");
		for (int psg = 1; psg < 7; psg++)			//for (int psg = 1; psg < 7; psg++)
		{
			for (int v = 0, r = 0; v < 32; v += 2, r++)
			{
				setRegAndValue(psg, r, strtol(selection.substring(v+(psg-1)*32, v+(psg-1)*32 + 2).c_str(), NULL, 16));
			}
		}
		Serial.println("All registers set!\n\n");
	}
	else
	{
		Serial.println("*** UNRECOGNIZED SELECTION ***\n\n");
	}
}
void resetPSGs()
{
	digitalWrite(RESB, LOW);
	digitalWrite(RESB, HIGH);
	

	for (int p = 1; p < 7; p++)
	{
		inactive(p);
		setRegAndValue(p, R00_ChA_Fine, 0x00);
		setRegAndValue(p, R01_ChA_Course, 0x00);
		setRegAndValue(p, R02_ChB_Fine, 0x00);
		setRegAndValue(p, R03_ChB_Course, 0x00);
		setRegAndValue(p, R04_ChC_Fine, 0x00);
		setRegAndValue(p, R05_ChC_Course, 0x00);
		setRegAndValue(p, R06_NoisePeriod, 0x00);
		setRegAndValue(p, R07_EnableB, 0b00111000);
		setRegAndValue(p, R08_ChA_Amplitude, 0b00001111);	//max volume of 15
		setRegAndValue(p, R09_ChB_Amplitude, 0b00001111);	//max volume of 15
		setRegAndValue(p, R10_ChC_Amplitude, 0b00001111);	//max volume of 15
		setRegAndValue(p, R11_EnvPeriod_Fine, 0x00);
		setRegAndValue(p, R12_EnvPeriod_Course, 0x00);
		setRegAndValue(p, R13_EnvShape, 0x00);
		setRegAndValue(p, R14_IO_PortA, 0x00);
		setRegAndValue(p, R15_IO_PortB, 0x00);
	}

	//for (int p = 5; p < 6; p++)
	//{
	//	inactive(p);
	//	setRegAndValue(p, R00_ChA_Fine, 0x00);
	//	setRegAndValue(p, R01_ChA_Course, 0x00);
	//	setRegAndValue(p, R02_ChB_Fine, 0x00);
	//	setRegAndValue(p, R03_ChB_Course, 0x00);
	//	setRegAndValue(p, R04_ChC_Fine, 0x00);
	//	setRegAndValue(p, R05_ChC_Course, 0x00);
	//	setRegAndValue(p, R06_NoisePeriod, 0x00);
	//	setRegAndValue(p, R07_EnableB, 0b00111000);
	//	setRegAndValue(p, R08_ChA_Amplitude, 0b00001111);	//max volume of 15
	//	setRegAndValue(p, R09_ChB_Amplitude, 0b00001111);	//max volume of 15
	//	setRegAndValue(p, R10_ChC_Amplitude, 0b00001111);	//max volume of 15
	//	setRegAndValue(p, R11_EnvPeriod_Fine, 0x00);
	//	setRegAndValue(p, R12_EnvPeriod_Course, 0x00);
	//	setRegAndValue(p, R13_EnvShape, 0x00);
	//	setRegAndValue(p, R14_IO_PortA, 0x00);
	//	setRegAndValue(p, R15_IO_PortB, 0x00);
	//}
}
void setRegAndValue(int psg, byte reg, byte val)
{
	Serial.print("PSG:");
	Serial.print(psg);
	Serial.print("\t");
	Serial.print("Register:");
	Serial.print(reg);
	Serial.print("\t");
	Serial.print("Value:");
	Serial.println(val);
	setReg(psg, reg);
	writeData(psg, val);
}
void setReg(int psg, byte reg)
{
	inactive(psg);
	writeByte(reg);
	latch(psg);
	inactive(psg);
}
//byte readData()
//{
//	//TO DO change the direction of the pins, and return direction to original when done
//	byte tmp = 0;
//	inactive();
//	read();
//	tmp = readByte();
//	inactive();
//	return tmp;
//}
void writeData(int psg, byte data)
{
	inactive(psg);
	writeByte(data);
	write(psg);
	inactive(psg);
}
void inactive(int psg)
{
	//BDIR  LOW
	//BC1   LOW
	setBusControl(psg, false, false);
}
void latch(int psg)	//INTAK
{
	//BDIR  HIGH
	//BC1   HIGH
	setBusControl(psg, true, true);
}
//void read(int psg)		//DTB
//{
//	//BDIR  LOW
//	//BC1   HIGH
//  setBusControl(psg, false, true);
//}
void write(int psg)	//DWS
{
	//BDIR  HIGH
	//BC1   LOW
	setBusControl(psg, true, false);
}
void setBusControl(int psg, bool bdir, bool bc1)
{
	//Have to set both BDIR and BC1 simultaneously, so digitalWrite is not an option.
	//Use port

	int ibdir = 0;
	int ibc1 = 0;

	switch (psg)
	{
	case 1:
		if (bdir == true) { ibdir = BIT_PSG1_BDIR; }
		if (bc1 == true) { ibc1 = BIT_PSG1_BC1; }
		PORTA = ((PORTA & BIT_PSG1_ANDMASK) | ibdir | ibc1);		
		break;
	case 2:
		if (bdir == true) { ibdir = BIT_PSG2_BDIR; }
		if (bc1 == true) { ibc1 = BIT_PSG2_BC1; }
		PORTA = ((PORTA & BIT_PSG2_ANDMASK) | ibdir | ibc1);
		break;
	case 3:
		if (bdir == true) { ibdir = BIT_PSG3_BDIR; }
		if (bc1 == true) { ibc1 = BIT_PSG3_BC1; }
		PORTA = ((PORTA & BIT_PSG3_ANDMASK) | ibdir | ibc1);		
		break;
	case 4:
		if (bdir == true) { ibdir = BIT_PSG4_BDIR; }
		if (bc1 == true) { ibc1 = BIT_PSG4_BC1; }
		PORTA = ((PORTA & BIT_PSG4_ANDMASK) | ibdir | ibc1);
		break;
	case 5:
		if (bdir == true) { ibdir = BIT_PSG5_BDIR; }
		if (bc1 == true) { ibc1 = BIT_PSG5_BC1; }
		PORTC = ((PORTC & BIT_PSG5_ANDMASK) | ibdir | ibc1);
		break;
	case 6:
		if (bdir == true) { ibdir = BIT_PSG6_BDIR; }
		if (bc1 == true) { ibc1 = BIT_PSG6_BC1; }
		PORTC = ((PORTC & BIT_PSG6_ANDMASK) | ibdir | ibc1);
		break;
	}

}
void writeByte(byte data)
{
	//Common data bus, so PSG# doesn't matter
	
	//PORTL = data;

	if ((data & 0b10000000) == 0b10000000) {
		digitalWrite(D7, HIGH);
	}
	else
	{
		digitalWrite(D7, LOW);
	}

	if ((data & 0b01000000) == 0b01000000) {
		digitalWrite(D6, HIGH);
	}
	else
	{
		digitalWrite(D6, LOW);
	}

	if ((data & 0b00100000) == 0b00100000) {
		digitalWrite(D5, HIGH);
	}
	else
	{
		digitalWrite(D5, LOW);
	}

	if ((data & 0b00010000) == 0b00010000) {
		digitalWrite(D4, HIGH);
	}
	else
	{
		digitalWrite(D4, LOW);
	}

	if ((data & 0b00001000) == 0b00001000) {
		digitalWrite(D3, HIGH);
	}
	else
	{
		digitalWrite(D3, LOW);
	}

	if ((data & 0b00000100) == 0b00000100) {
		digitalWrite(D2, HIGH);
	}
	else
	{
		digitalWrite(D2, LOW);
	}

	if ((data & 0b00000010) == 0b00000010) {
		digitalWrite(D1, HIGH);
	}
	else
	{
		digitalWrite(D1, LOW);
	}

	if ((data & 0b00000001) == 0b00000001) {
		digitalWrite(D0, HIGH);
	}
	else
	{
		digitalWrite(D0, LOW);
	}
}
//byte readByte()
//{
//	byte tmp = 0;
//	tmp |= (digitalRead(D7) << 7);
//	tmp |= (digitalRead(D6) << 6);
//	tmp |= (digitalRead(D5) << 5);
//	tmp |= (digitalRead(D4) << 4);
//	tmp |= (digitalRead(D3) << 3);
//	tmp |= (digitalRead(D2) << 2);
//	tmp |= (digitalRead(D1) << 1);
//	tmp |= (digitalRead(D0));
//	return tmp;
//}
