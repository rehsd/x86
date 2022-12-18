/*
 Name:		SPI_80286_Nano.ino
 Created:	11/27/2022
 Author:	rich
*/

#include <SPI.h>

volatile int packetNumber;
volatile byte currentCommand;
const byte CMD_RESET = 0;
const byte CMD_PRINT_CHAR = 1;
const byte CMD_PRINT_HEX16 = 2;
const byte CMD_PRINT_BINARY16 = 3;
volatile byte recvByte = '0';
volatile byte sendByte = '0';
volatile byte dataByte0 = 0;
volatile byte dataByte1 = 0;
byte buffer[50];
volatile byte i;

void setup() {
    packetNumber = 0;
    currentCommand = CMD_RESET;
    ; Serial.begin(115200);
    Serial.begin(3*115200);
    SPCR |= 0b11000000;           //enable SPI with interrupt
    SPSR |= 0x00;   //SPI Status Register
    pinMode(MISO, OUTPUT);
    pinMode(SS, INPUT_PULLUP);
    pinMode(MOSI, INPUT);
    pinMode(SCK, INPUT);
    //SPI.attachInterrupt();
    Serial.println("Initialization complete. Ready to receive data.");
    Serial.flush();
}

ISR(SPI_STC_vect)   //Interrupt routine function
{
    recvByte = SPDR;

    if (packetNumber == 0)
    {
        currentCommand = recvByte;
        packetNumber++;
    }
    else if (packetNumber == 1)
    {
        dataByte0 = recvByte;
        processCommand();           //to do - add to queue & move to loop()
        packetNumber = 0;
    }

    Serial.flush();
}


void processCommand()
{
    switch (currentCommand)
    {
    case CMD_PRINT_CHAR:
        if (dataByte1 == 27)   //escape
        {
        }
        else
        {
            Serial.print((char)dataByte0);
        }
        break;
    case CMD_PRINT_HEX16:
        printHex16(dataByte1 << 8 + dataByte0);
        break;
    case CMD_PRINT_BINARY16:
        printBits8(dataByte0);
        Serial.print(":");
        printBits8(dataByte1);
        Serial.println();
        break;
    }
}

void printHex16(int val)
{
    Serial.print("0x");
    val = val & 0xFFFF;  //ignore higher bytes
    Serial.println(val, HEX);
}

String printBits8(int n) {
    byte numBits = 8;  // 2^numBits must be big enough to include the number n
    char b;

    for (byte i = 0; i < numBits; i++) {
        // shift 1 and mask to identify each bit value
        b = (n & (1 << (numBits - 1 - i))) > 0 ? '1' : '0'; // slightly faster to print chars than ints (saves conversion)
        Serial.print(b);
    }
}

void loop() {
}
