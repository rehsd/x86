/*
 Name:		Sketch1.ino
 Created:	10/6/2022
 Author:	rehsd
*/

#include <EEPROM.h>

#define LED4	13
#define LED1	12
#define LED2	11
#define LED3	10

//map ZIF PIN to Arduino PIN
#define PIN1	2
#define PIN2	3
#define PIN3	4
#define PIN4	5
#define PIN5	6
#define PIN6	7
#define PIN7	8
#define PIN8	9
#define PIN9	22
#define PIN10	23
#define PIN11	24
#define PIN12	25
#define PIN13	26
#define PIN14	27
#define PIN15	28
#define PIN16	29
#define PIN17	30
#define PIN18	31
#define PIN19	32
#define PIN20	33
#define PIN21	34
#define PIN22	35
#define PIN23	36
#define PIN24	37
#define PIN25	38
#define PIN26	39
#define PIN27	40
#define PIN28	41
#define PIN29	42
#define PIN30	43
#define PIN31	44
#define PIN32	45
#define PIN33	46
#define PIN34	47
#define PIN35	48
#define PIN36	49
#define PIN37	50
#define PIN38	51
#define PIN39	52
#define PIN40	53

//A0..A15 available to read analog values (manual jumper wires)

//Map specific IC pins to ZIF pins
int PINS_C64_PLA[33]={0
					,PIN1,PIN2,PIN3,PIN4,PIN5,PIN6,PIN7,PIN8,PIN9,PIN10,PIN11,PIN12,PIN13,PIN14,PIN15,PIN16
					,PIN25,PIN26,PIN27,PIN28,PIN29,PIN30,PIN31,PIN32,PIN33,PIN34,PIN35,PIN36,PIN37,PIN38,PIN39,PIN40};	//ignore 0, use 1-32

// the setup function runs once when you press reset or power the board
void setup() {
	

	pinMode(LED1, OUTPUT);
	pinMode(LED2, OUTPUT);
	pinMode(LED3, OUTPUT);
	pinMode(LED4, OUTPUT);

	digitalWrite(LED4, HIGH);
	delay(50);
	digitalWrite(LED3, HIGH);
	delay(50);
	digitalWrite(LED2, HIGH);
	delay(50);
	digitalWrite(LED1, HIGH);
	delay(50);
	digitalWrite(LED1, LOW);
	delay(50);
	digitalWrite(LED2, LOW);
	delay(50);
	digitalWrite(LED3, LOW);
	delay(50);
	digitalWrite(LED4, LOW);
	delay(50);

	Serial.begin(230400);

}

// the loop function runs over and over again until power down or reset
void loop() {
	String selection;
	Serial.println("\r\n\r\nWelcome to the IC Testing Utility!\r\n");
	Serial.print("Choose IC:\r\n1) Read Known Good C64 906114-01 PLA into EEPROM:\r\n2) Test C64 906114-01 PLA\r\n3) 6502 CPU\r\n4) 65816 CPU\r\n5) 6522 VIA\r\n6) AY-3-8910, YM2149\r\n>");
	while (Serial.available() == 0)
	{
		//sit and wait 
	}
	selection = Serial.readString();
	if (selection == "1")
	{
		Sample_C64_PLA();
		AnyKeyToContinue();
	}
	else if (selection == "2")
	{
		Test_C64_PLA();
		AnyKeyToContinue();
	}
	else if (selection == "3")
	{
		Serial.println("3");
	}
	else if (selection == "4")
	{
		Serial.println("4");
	}
	else if (selection == "5")
	{
		Serial.println("5");
	}
	else if (selection == "6")
	{
		Serial.println("6");
	}
	else
	{
		Serial.println("*** UNRECOGNIZED SELECTION ***\r\n");
	}
}

void AnyKeyToContinue()
{
	Serial.print("Press any key to continue");
	while (Serial.available() == 0)
	{
		//sit and wait 
	}
	Serial.readString();
}

void SetPinMode(String IC)
{
	if (IC == "C64_PLA")
	{
		pinMode(PINS_C64_PLA[1], INPUT);	//NC
		pinMode(PINS_C64_PLA[2], OUTPUT);	//I7
		pinMode(PINS_C64_PLA[3], OUTPUT);	//I6
		pinMode(PINS_C64_PLA[4], OUTPUT);	//I5
		pinMode(PINS_C64_PLA[5], OUTPUT);	//I4
		pinMode(PINS_C64_PLA[6], OUTPUT);	//I3
		pinMode(PINS_C64_PLA[7], OUTPUT);	//I2
		pinMode(PINS_C64_PLA[8], OUTPUT);	//I1
		pinMode(PINS_C64_PLA[9], OUTPUT);	//I0
		pinMode(PINS_C64_PLA[10], INPUT);	//F7
		pinMode(PINS_C64_PLA[11], INPUT);	//F6
		pinMode(PINS_C64_PLA[12], INPUT);	//F5
		pinMode(PINS_C64_PLA[13], INPUT);	//F4
		pinMode(PINS_C64_PLA[14], INPUT);	//VSS (Disconnected from Arduino)
		pinMode(PINS_C64_PLA[15], INPUT);	//F3
		pinMode(PINS_C64_PLA[16], INPUT);	//F2
		pinMode(PINS_C64_PLA[17], INPUT);	//F1
		pinMode(PINS_C64_PLA[18], INPUT);	//F0
		pinMode(PINS_C64_PLA[19], OUTPUT);	//#CE
		pinMode(PINS_C64_PLA[20], OUTPUT);	//I15
		pinMode(PINS_C64_PLA[21], OUTPUT);	//I14
		pinMode(PINS_C64_PLA[22], OUTPUT);	//I13
		pinMode(PINS_C64_PLA[23], OUTPUT);	//I12
		pinMode(PINS_C64_PLA[24], OUTPUT);	//I11
		pinMode(PINS_C64_PLA[25], OUTPUT);	//I10
		pinMode(PINS_C64_PLA[26], OUTPUT);	//I9
		pinMode(PINS_C64_PLA[27], OUTPUT);	//I8
		pinMode(PINS_C64_PLA[28], INPUT);	//VCC (Disconnected from Arduino)

	}
}
void Sample_C64_PLA()
{
	ResetLEDs();

	Serial.println("\r\nSample C64 PLA and Store in Arduino EEPROM\r\n");
	Serial.println("VCC  I8  I9 I10 I11 I12 I13 I14 I15 #CE  F0  F1  F2  F3");
	Serial.println(" 28  27  26  25  24  23  22  21  20  19  18  17  16  15");
	Serial.println("-------------------------------------------------------");
	Serial.println("|                    906114-01 PLA                    |");
	Serial.println("-------------------------------------------------------");
	Serial.println("  1   2   3   4   5   6   7   8   9  10  11  12  13  14");
	Serial.println(" NC  I7  I6  I5  I4  I3  I2  I1  I0  F7  F6  F5  F4 VSS");
	Serial.println();
	AnyKeyToContinue();
	Serial.println();
	digitalWrite(LED1, HIGH);

	SetPinMode("C64_PLA");

	int outValue = 0;
	long loc = 0;
	int inbits = 16;
	long combinations = ((long)1 << inbits);
	int step = combinations / EEPROM.length();
	Serial.print("Stepping:");
	Serial.println(step);
	int lowFour = 0;
	
	digitalWrite(PINS_C64_PLA[19], LOW);	//CE# - enable IC

	for (long i = 0; i<combinations; i+=step)
	{
		
		//set I pin values on PLA
		digitalWrite(PINS_C64_PLA[9], bitRead(lowFour, 0));
		digitalWrite(PINS_C64_PLA[8], bitRead(lowFour, 1));
		digitalWrite(PINS_C64_PLA[7], bitRead(lowFour, 2));
		digitalWrite(PINS_C64_PLA[6], bitRead(lowFour, 3));
		digitalWrite(PINS_C64_PLA[5], bitRead(i, 4));
		digitalWrite(PINS_C64_PLA[4], bitRead(i, 5));
		digitalWrite(PINS_C64_PLA[3], bitRead(i, 6));
		digitalWrite(PINS_C64_PLA[2], bitRead(i, 7));
		digitalWrite(PINS_C64_PLA[27], bitRead(i, 8));
		digitalWrite(PINS_C64_PLA[26], bitRead(i, 9));
		digitalWrite(PINS_C64_PLA[25], bitRead(i, 10));
		digitalWrite(PINS_C64_PLA[24], bitRead(i, 11));
		digitalWrite(PINS_C64_PLA[23], bitRead(i, 12));
		digitalWrite(PINS_C64_PLA[22], bitRead(i, 13));
		digitalWrite(PINS_C64_PLA[21], bitRead(i, 14));
		digitalWrite(PINS_C64_PLA[20], bitRead(i, 15));

		delay(30);

		//read output and store in EEPROM
		outValue = digitalRead(PINS_C64_PLA[10]) << 7 | digitalRead(PINS_C64_PLA[11]) << 6 | digitalRead(PINS_C64_PLA[12]) << 5 | digitalRead(PINS_C64_PLA[13]) << 4 | digitalRead(PINS_C64_PLA[15]) << 3 | digitalRead(PINS_C64_PLA[16]) << 2 | digitalRead(PINS_C64_PLA[17]) << 1 | digitalRead(PINS_C64_PLA[18]);

		Serial.print("INPUT: ");
		Serial.print(i+lowFour,BIN);
		Serial.print(" (");
		Serial.print(i+lowFour);
		Serial.print(")  OUTPUT: ");
		Serial.print(outValue, BIN);
		Serial.print(" (");
		Serial.print(outValue);
		Serial.print(")");
		Serial.println();

		//EEPROM.update(loc, outValue);

		loc++;

		lowFour++;
		if (lowFour > 15)
		{
			lowFour = 0;
		}
	}
	digitalWrite(PINS_C64_PLA[17], HIGH);	//CE# - disable IC

	Serial.print("Number of samples processed: ");
	Serial.println(loc);

	digitalWrite(LED1, LOW);
	digitalWrite(LED2, HIGH);

}
void Test_C64_PLA()
{
	//Only doing a spot check for now...
	ResetLEDs();

	Serial.println("\r\nTest C64 PLA\r\n");
	Serial.println("VCC  I8  I9 I10 I11 I12 I13 I14 I15 #CE  F0  F1  F2  F3");
	Serial.println(" 28  27  26  25  24  23  22  21  20  19  18  17  16  15");
	Serial.println("-------------------------------------------------------");
	Serial.println("|                    906114-01 PLA                    |");
	Serial.println("-------------------------------------------------------");
	Serial.println("  1   2   3   4   5   6   7   8   9  10  11  12  13  14");
	Serial.println(" NC  I7  I6  I5  I4  I3  I2  I1  I0  F7  F6  F5  F4 VSS");
	Serial.println();

	AnyKeyToContinue();
	Serial.println();
	digitalWrite(LED3, HIGH);
	Serial.println("PLA test starting...");
	SetPinMode("C64_PLA");

	//set I pin values on PLA
	long i = 0;
	bool pass = true;
	if (!C64_PAL_OutputMatches(4096, 240)) { pass = false; }
	if (!C64_PAL_OutputMatches(32768, 240)) { pass = false; }
	if (!C64_PAL_OutputMatches(40960, 240)) { pass = false; }
	if (!C64_PAL_OutputMatches(41216, 240)) { pass = false; }
	if (!C64_PAL_OutputMatches(42615, 240)) { pass = false; }
	//if (!C64_PAL_OutputMatches(44288, 112)) { pass = false; }
	if (!C64_PAL_OutputMatches(44543, 112)) { pass = false; }
	if (!C64_PAL_OutputMatches(50261, 240)) { pass = false; }
	//if (!C64_PAL_OutputMatches(52616, 112)) { pass = false; }
	if (!C64_PAL_OutputMatches(52735, 112)) { pass = false; }
	if (!C64_PAL_OutputMatches(57361, 240)) { pass = false; }
	//if (!C64_PAL_OutputMatches(60740, 112)) { pass = false; }

	if (!pass)
	{
		Serial.println("Result: FAIL");
	}
	else
	{
		Serial.println("Result: PASS");
	}

	digitalWrite(LED4, HIGH);
	digitalWrite(LED3, LOW);


}

bool C64_PAL_OutputMatches(int pins, int expectedValue)
{
	long outValue = 0;
	delay(30);
	digitalWrite(PINS_C64_PLA[9], bitRead(pins, 0));
	digitalWrite(PINS_C64_PLA[8], bitRead(pins, 1));
	digitalWrite(PINS_C64_PLA[7], bitRead(pins, 2));
	digitalWrite(PINS_C64_PLA[6], bitRead(pins, 3));
	digitalWrite(PINS_C64_PLA[5], bitRead(pins, 4));
	digitalWrite(PINS_C64_PLA[4], bitRead(pins, 5));
	digitalWrite(PINS_C64_PLA[3], bitRead(pins, 6));
	digitalWrite(PINS_C64_PLA[2], bitRead(pins, 7));
	digitalWrite(PINS_C64_PLA[27], bitRead(pins, 8));
	digitalWrite(PINS_C64_PLA[26], bitRead(pins, 9));
	digitalWrite(PINS_C64_PLA[25], bitRead(pins, 10));
	digitalWrite(PINS_C64_PLA[24], bitRead(pins, 11));
	digitalWrite(PINS_C64_PLA[23], bitRead(pins, 12));
	digitalWrite(PINS_C64_PLA[22], bitRead(pins, 13));
	digitalWrite(PINS_C64_PLA[21], bitRead(pins, 14));
	digitalWrite(PINS_C64_PLA[20], bitRead(pins, 15));
	delay(30);

	//read output and store in EEPROM
	outValue = digitalRead(PINS_C64_PLA[10]) << 7 | digitalRead(PINS_C64_PLA[11]) << 6 | digitalRead(PINS_C64_PLA[12]) << 5 | digitalRead(PINS_C64_PLA[13]) << 4 | digitalRead(PINS_C64_PLA[15]) << 3 | digitalRead(PINS_C64_PLA[16]) << 2 | digitalRead(PINS_C64_PLA[17]) << 1 | digitalRead(PINS_C64_PLA[18]);

	if (expectedValue == outValue)
	{
		Serial.println("match..");
		return true;
	}
	else
	{
		Serial.println("NO match!");
		return false;
	}
}

void ResetLEDs()
{
	digitalWrite(LED1, LOW);
	digitalWrite(LED2, LOW);
	digitalWrite(LED3, LOW);
	digitalWrite(LED4, LOW);
}

