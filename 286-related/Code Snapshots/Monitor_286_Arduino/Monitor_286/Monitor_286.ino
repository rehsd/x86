/*
 Name:		Monitor_286.ino
 Created:	20 October 2022
 Author:	rehsd
*/

/*
	//Build #1
	const char ADDR[] = { A7,A6,A5,A4,A3,A2,A1,A0,37,36,35,34,33,32,31,30,29,28,27,26,25,24,23,22 };		//A7=A23 <--> A0=A16, 37=A15 <--> 22=A0
	const char DATA[] = { 53,52,51,50,49,48,47,46,45,44,43,42,41,40,39,38 };		//53=D15 <--> 38=D0
	//GND!
	#define CLOCK			2

	#define RAM_READ		13
	#define RAM_WRITE		12
	#define ROM_READ		11
	#define IO_READ_0x02	10
	#define IO_WRITE_0x02	9
	#define IO_WRITE_0x04	8

	#define CODINTA			7
	#define MIO				6
	#define S1				5
	#define S0				4
	#define BHE				3
*/

#include "Processor286.h"

//Build #2
const char ADDR[] = { A15,A14,A13,A12,A11,A10,A9,A8,23,22,25,24,27,26,29,28,31,30,33,32,35,34,37,36 };	//A15=BUS_A23 <--> A8=BUS_A16, 23=BUS_A15 <--> 36=BUS_A0	
const char DATA[] = { 39,38,41,40,43,42,45,44,47,46,49,48,51,50,53,52 };								// 39=BUS_D15 <--> 52=BUS_D0

//GND!
#define CLOCK			2
#define CODINTA			3
#define MIO				4
#define S1				5
#define S0				6
#define BHE				7
#define RAM_OE			8	//RAM read
#define ROM_OE			9	//ROM read
#define MWTC			10	//Memory write (assuming RAM write for now)
#define MRDC			11	//Memory read
#define IOWC			12	//IO write
#define IORC			13	//IO read
#define PPI1_CS			A0
#define PPI2_CS			A1
#define IRQ_CTLR_CS		A2
#define MATH_CO_EN		A3
#define	DTR				A5
#define	DEN				A6
#define ALE				A7


bool CYCLE_CODINTA;
bool CYCLE_MIO;
bool CYCLE_S1;
bool CYCLE_S0;
bool BUS_HIGH_ENABLE;
bool ACTIVE_MATH_CO;
bool ACTIVE_IRQ;
bool ACTIVE_PPI1;
bool ACTIVE_PPI2;
const bool DECODE_INSTRUCTION = true;
bool FirstPass = true;

bool CYCLE_Prev_IsInstructionRead;
int InstructionBytesRemaining=0;

String currentInstruction = "xxxxxx:xxxxxx";
bool activeIO = false;

void setup() {
	for (int n = 0; n < 24; n++)
	{
		pinMode(ADDR[n], INPUT);
	}

	for (int n = 0; n < 16; n++)
	{
		pinMode(DATA[n], INPUT);
	}

	pinMode(CLOCK, INPUT);
	
	pinMode(CODINTA, INPUT);
	pinMode(MIO, INPUT);
	pinMode(S1, INPUT);
	pinMode(S0, INPUT);
	pinMode(BHE, INPUT);
	pinMode(RAM_OE, INPUT);
	pinMode(ROM_OE, INPUT);
	pinMode(MWTC, INPUT);
	pinMode(MRDC, INPUT);
	pinMode(PPI1_CS, INPUT);
	pinMode(PPI2_CS, INPUT);
	pinMode(IRQ_CTLR_CS, INPUT);
	pinMode(MATH_CO_EN, INPUT);
	pinMode(ALE, INPUT);
	pinMode(DEN, INPUT);
	pinMode(DTR, INPUT);
	pinMode(IOWC, INPUT);
	pinMode(IORC, INPUT);

	//attachInterrupt(digitalPinToInterrupt(CLOCK), onClock, RISING);
	attachInterrupt(digitalPinToInterrupt(CLOCK), onClock, FALLING);
	
	//Serial.begin(230400);
	Serial.begin(921600);

	Serial.println("Loading...");
}

void onClock()
{
	char output[200];
	unsigned int address = 0;
	unsigned int addressTop8 = 0;
	unsigned int data = 0;

	Serial.print("A:");
	for (int n = 0; n < 8; n++)
	{
		int bit = digitalRead(ADDR[n]) ? 1 : 0;
		Serial.print(bit);
		addressTop8 = (addressTop8 << 1) + bit;
	}
	for (int n = 8; n < 24; n++)
	{
		int bit = digitalRead(ADDR[n]) ? 1 : 0;
		Serial.print(bit);
		address = (address << 1) + bit;
	}

	Serial.print(" D:");
	for (int n = 0; n < 16; n++)
	{
		int bit = digitalRead(DATA[n]) ? 1 : 0;
		Serial.print(bit);
		data = (data << 1) + bit;
	}
	
	CYCLE_CODINTA = digitalRead(CODINTA) ? true : false;
	CYCLE_MIO = digitalRead(MIO) ? true : false;
	CYCLE_S1 = digitalRead(S1) ? true : false;
	CYCLE_S0 = digitalRead(S0) ? true : false;
	BUS_HIGH_ENABLE = digitalRead(BHE) ? true : false;

	if (digitalRead(IOWC) == LOW || digitalRead(IORC) == LOW)
	{
		activeIO = true;
	}
	else
	{
		activeIO = false;
	}

	if (digitalRead(PPI1_CS) == LOW && activeIO)
	{
		ACTIVE_PPI1 = true;
	}
	else
	{
		ACTIVE_PPI1 = false;
	}

	if (digitalRead(PPI2_CS) == LOW && activeIO)
	{
		ACTIVE_PPI2 = true;
	}
	else
	{
		ACTIVE_PPI2 = false;
	}

	if (digitalRead(MATH_CO_EN) == LOW && activeIO)
	{
		ACTIVE_MATH_CO = true;
	}
	else
	{
		ACTIVE_MATH_CO = false;
	}

	if (digitalRead(IRQ_CTLR_CS) == LOW && activeIO)
	{
		ACTIVE_IRQ = true;
	}
	else
	{
		ACTIVE_IRQ = false;
	}

	if (DECODE_INSTRUCTION&& InstructionBytesRemaining <= 0 && CYCLE_Prev_IsInstructionRead && !FirstPass)
	{
		if (CYCLE_MIO && CYCLE_S1 && CYCLE_S0)
		{
			if (!BUS_HIGH_ENABLE && !(address & 1))	//word transfer
			{
				currentInstruction = "       " + operands[(data & 0x00FF)].mnemonic;
				InstructionBytesRemaining = operands[(data & 0x00FF)].bytes;
			}
			else if (!BUS_HIGH_ENABLE && (address & 1))	//byte transfer upper
			{
				currentInstruction = operands[(data & 0xFF00) >> 8].mnemonic + "       ";
				InstructionBytesRemaining = operands[(data & 0xFF00) >> 8].bytes;
			}
			else if (BUS_HIGH_ENABLE && !(address & 1))	//byte transfer lower
			{
				currentInstruction = "       " + operands[(data & 0x00FF)].mnemonic;
				InstructionBytesRemaining = operands[(data & 0x00FF)].bytes;
			}
			else //reserved
			{
				currentInstruction = "             ";
			}
		}
		else //not an instruction read
		{
			currentInstruction = "             ";
			InstructionBytesRemaining = 2;
		}
	}
	else //not decoding instructions
	{
		currentInstruction = "             ";
		if(FirstPass)
		{
			InstructionBytesRemaining = 2;
		}
	}

	sprintf(output, "  0x:%02x%04x:%04x  %s  %s %s %s  CYCLE:%s%s%s%s  BHE:%s MWTC:%s MRDC:%s IORC:%s IOWC:%s ALE:%s DEN:%s DTR:%s  ENABLE: %s %s %s %s  debug:%i", addressTop8, address, data, currentInstruction.c_str(), 
		digitalRead(RAM_OE) ? "----" : "RAMR", digitalRead(MWTC) ? "----" : "RAMW", digitalRead(ROM_OE) ? "----" : "ROMR",
		CYCLE_CODINTA ? "1" : "0", CYCLE_MIO ? "1" : "0", CYCLE_S1 ? "1" : "0", CYCLE_S0 ? "1" : "0", BUS_HIGH_ENABLE ? "1" : "0",
		digitalRead(MWTC) ? "1" : "0", digitalRead(MRDC) ? "1" : "0", digitalRead(IORC) ? "1" : "0", digitalRead(IOWC) ? "1" : "0",
		digitalRead(ALE) ? "1" : "0", digitalRead(DEN) ? "1" : "0", digitalRead(DTR) ? "1" : "0",
		ACTIVE_PPI1 ? "PPI1" : "----", ACTIVE_PPI2 ? "PPI2" : "----", ACTIVE_IRQ ? "IRQ" : "---", ACTIVE_MATH_CO ? "MATH" : "----",
		InstructionBytesRemaining);

	Serial.println(output);
	Serial.flush();

	if ((CYCLE_CODINTA && CYCLE_MIO && !CYCLE_S1 && CYCLE_S0))
	{
		CYCLE_Prev_IsInstructionRead = true;
		FirstPass = false;
	}
	else
	{
		CYCLE_Prev_IsInstructionRead = false;
	}

	InstructionBytesRemaining=InstructionBytesRemaining-2;
}

void loop() {

}

