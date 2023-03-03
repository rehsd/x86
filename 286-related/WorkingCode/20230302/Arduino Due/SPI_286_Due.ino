/*
 Name:		SPI_286_Due.ino
 Created:	2/28/2023
 Author:	rehsd

Portions of Due SPI Slave adapted from https://github.com/MrScrith/arduino_due/blob/master/spi_slave.ino

*/

#include <SPI.h>
#include <Wire.h>
#include <DueFlashStorage.h>

#define ROM_BYTE_COUNT 262144         //256KB
#define SPI0_INTERRUPT_NUMBER (IRQn_Type)24     // SPI 0 interrupt for the SAM3XA chip
#define BUFFER_SIZE 256

DueFlashStorage dueFlashStorage;        //uses the upper 256KB of total 512KB onboard flash (code sits in the first 256KB)

//// volatile byte recvByte = '0';
volatile byte sendByte = '0';
volatile byte currentCommand;
volatile long bytesReceivedFromPC = 0;
volatile long bytesSent;
volatile long totalBytesToSend;
//volatile byte printScreenBytesReceived;

volatile bool BIOSbyteTransferStarted = false;
volatile bool showCompletion = false;

const byte CMD_RESET = 0;
const byte CMD_GETSTATUS = 1;
const byte CMD_GETTWOBYTES = 2;
const byte CMD_GET_BIOS = 3;
const byte CMD_FLUSH = 255;

const unsigned long BYTES_SENT_RESET_TIMER = 1000000;
volatile unsigned long bytesSentResetTimer;

#define SS 10
// D13 = SCK
// D12 = MISO
// D11 = MOSI
// D10 = CS
// Default chip select pin, not tested with any other pins

void SPI0_Handler(void);            // Define handler

void slaveBegin(uint8_t _pin) {
    // Setup the SPI Interrupt registers.
    NVIC_ClearPendingIRQ(SPI0_INTERRUPT_NUMBER);
    NVIC_EnableIRQ(SPI0_INTERRUPT_NUMBER);

    // Initialize the SPI device with Arduino default values
    SPI.begin(_pin);
    //SPI.setDataMode(10, SPI_MODE0);
    //REG_SPI0_CR |= 0x1;          // SPI enable (write only)
    //REG_SPI0_WPMR = 0x53504900;  // Write Protection disable
    //REG_SPI0_MR = 0x2;           // DLYBCS=0, PCS=0, PS=1, MSTR=0
    //REG_SPI0_CSR = 0xA;          // DLYBCT=0, DLYBS=0, SCBR=0, 8 bit transfer, Clock Phase = 1 for SPI mode 0

    REG_SPI0_CR = SPI_CR_SWRST;     // reset SPI
    SPI.setBitOrder(MSBFIRST);

    // Setup interrupt
    REG_SPI0_IDR = SPI_IDR_TDRE | SPI_IDR_MODF | SPI_IDR_OVRES | SPI_IDR_NSSR | SPI_IDR_TXEMPTY | SPI_IDR_UNDES;
    REG_SPI0_IER = SPI_IER_RDRF;

    // Setup the SPI registers.
    REG_SPI0_CR = SPI_CR_SPIEN;     // enable SPI
    REG_SPI0_MR = SPI_MR_MODFDIS;     // slave and no modefault
    REG_SPI0_CSR = SPI_MODE0;    // DLYBCT=0, DLYBS=0, SCBR=0, 8 bit transfer
}

void SPI0_Handler(void)
{
    byte b = 0;

    // Receive byte
    while ((REG_SPI0_SR & SPI_SR_RDRF) == 0);
    b = REG_SPI0_RDR;

    HandleSPIbyte(b);
}

void setup()
{
    //pinMode(VIA3_CB2_PIN, OUTPUT);
    //digitalWrite(VIA3_CB2_PIN, LOW);

    currentCommand = CMD_RESET;
    SerialUSB.begin(115200); //speed doesn't matter, runs at USB max (480Mbps)
    SerialUSB.flush();

    // Setup the SPI as Slave
    slaveBegin(SS);

    Serial.begin(115200);
    Serial.println("start");

    for (int i = 0; i < 16; i++)
    {
        Serial.print(i);
        Serial.print(":  ");
        Serial.println(dueFlashStorage.read(i), HEX);
    }
    for (int i = ROM_BYTE_COUNT - 16; i < ROM_BYTE_COUNT; i++)
    {
        Serial.print(i);
        Serial.print(":  ");
        Serial.println(dueFlashStorage.read(i), HEX);
    }

    bytesSent = 0;
    //bytesSentResetTimer = BYTES_SENT_RESET_TIMER;
}

void HandleSPIbyte(byte recvByte)   //Interrupt routine function
{
    //Serial.print("b");
    //send 256 KB to 286 (stored in SD Card)
    //to do add lots of safety / reset code
    if (bytesSent < ROM_BYTE_COUNT)
    {
        //Serial.print(".");
        //REG_SPI0_TDR = 0xdb;        //testing
        REG_SPI0_TDR = dueFlashStorage.read(bytesSent);
        bytesSent++;
        //bytesSentResetTimer = BYTES_SENT_RESET_TIMER;
    }
    else
    {
        REG_SPI0_TDR = 0xbe;
        bytesSent = 0;
        Serial.println("byteSent reset");
    }
}

void loop()
{
    // BUFFER_SIZE up top = 256
    if (SerialUSB.available() >= BUFFER_SIZE)
    {
        if (!BIOSbyteTransferStarted)
        {
            BIOSbyteTransferStarted = true;
            Serial.println("Transfer started...");
        }

        //Flash pagesize on Due is 256 bytes
        byte receiveBuffer[BUFFER_SIZE];
        SerialUSB.readBytes(receiveBuffer, BUFFER_SIZE);

        //Check for requested changes within the 256b page to see if data is dirty (new value != current value)
        //Only update the flash page if dirty
        bool dirty = false;
        for (int i = 0; i < BUFFER_SIZE; i++)
        {
            if (receiveBuffer[i] != dueFlashStorage.read(i + bytesReceivedFromPC))
            {
                dirty = true;
                break;
            }
        }

        if (dirty)
        {
            dueFlashStorage.write(bytesReceivedFromPC, receiveBuffer, 256);
        }

        bytesReceivedFromPC += 256;
        //Serial.println(bytesReceivedFromPC);

        if (bytesReceivedFromPC == ROM_BYTE_COUNT)
        {
            showCompletion = true;
        }
    }
    else if (showCompletion)
    {
        showCompletion = false;
        delay(1000);
        bytesReceivedFromPC = 0;
        BIOSbyteTransferStarted = false;
        Serial.println("Done!");
    }

    //if (bytesSentResetTimer > 0)
    //{
    //    bytesSentResetTimer--;
    //    if (bytesSentResetTimer == 0)
    //    {
    //        bytesSent = 0;
    //        Serial.println("bytesSent auto reset");
    //        bytesSentResetTimer = BYTES_SENT_RESET_TIMER;
    //    }
    //}
}

