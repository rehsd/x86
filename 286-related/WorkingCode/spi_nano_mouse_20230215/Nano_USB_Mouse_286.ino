//References
//https://isdaman.com/alsos/hardware/mouse/ps2interface.htm
//https://github.com/kristopher/PS2-Mouse-Arduino
//https://forum.digikey.com/t/ps-2-mouse-interface-vhdl/12617
//http://www.burtonsys.com/ps2_chapweske.htm

#include <SPI.h>
#include <Wire.h>

#define   pin_clock   4
#define   pin_data    3
#define   pin_irq     A5

#define   CLOCK_DELAY   20
#define   SCREEN_WIDTH                640
#define   SCREEN_HEIGHT               480    
//SPI: 10 (CS), 11 (MOSI), 12 (MISO), 13 (SCK)

uint32_t screen_pos_x = 320;            //start at center
uint32_t screen_pos_y = 240;            //start at center
volatile uint32_t dwordToSend = 0;      //value of mouse data to be sent back to 286    00xxxxxxxxxxyyyyyyyyymrl
volatile byte recvByte = '0';
volatile int packetNumber;
volatile byte currentCommand;
volatile bool newData = false;
volatile int16_t prevData[3];

void setup()
{
    pinMode(pin_irq, OUTPUT);
    digitalWrite(pin_irq, LOW);
    pinMode(MISO, OUTPUT);
    pinMode(SS, INPUT_PULLUP);
    pinMode(MOSI, INPUT);
    pinMode(SCK, INPUT);
    SPCR |= 0b11000000;           //enable SPI with interrupt

    Serial.begin(230400);
    Serial.println("Sending 0xF4 init...");

    //init
    PullHigh(pin_clock);
    PullHigh(pin_data);
    delay(CLOCK_DELAY);
    WriteByte(0xff);
    ReadByte();   // ACK
    delay(CLOCK_DELAY);
    ReadByte();   // garbage
    ReadByte();   // garbage
    delay(CLOCK_DELAY);   // needed?

    WriteByte(0xf4);  // Send enable data reporting
    ReadByte();       // ACK

    Serial.println("Init complete");
}

ISR(SPI_STC_vect)   //Interrupt routine function
{
    // assuming only SPI call is for mouse data
    recvByte = SPDR;
    if (packetNumber < 3)
    {
        SPDR = dwordToSend >> ((2 - packetNumber) * 8);   //send back a byte
        packetNumber++;
    }
    else
    {
        SPDR = 0;
        packetNumber = 0;
    }
}

void PullLow(int pin) {
    pinMode(pin, OUTPUT);
    digitalWrite(pin, LOW);
}
void PullHigh(int pin) {
    pinMode(pin, INPUT);
    digitalWrite(pin, HIGH);
}
void WriteByte(int data)
{
    char i;
    char parity = 1;
    PullHigh(pin_data);
    PullHigh(pin_clock);
    delayMicroseconds(300);
    PullLow(pin_clock);
    delayMicroseconds(300);
    PullLow(pin_data);
    delayMicroseconds(10);
    PullHigh(pin_clock);  // start bit

    while (digitalRead(pin_clock));   //wait for mouse to pull clock low

    for (i = 0; i < 8; i++)
    {
        if (data & B00000001)
        {
            PullHigh(pin_data);
        }
        else
        {
            PullLow(pin_data);
        }

        while (!digitalRead(pin_clock));    //wait for mouse to pull clock high
        while (digitalRead(pin_clock));     //wait for mouse to pull clock low
        parity ^= (data & B00000001);       //calculate parity bit
        data = data >> 1;
    }

    // set parity bit
    if (parity)
    {
        PullHigh(pin_data);
    }
    else
    {
        PullLow(pin_data);
    }

    while (!digitalRead(pin_clock));    //wait for mouse to pull clock high
    while (digitalRead(pin_clock));     //wait for mouse to pull clock low

    PullHigh(pin_data);
    delayMicroseconds(50);

    while (digitalRead(pin_clock));     //wait for mouse to pull clock high
    while ((!digitalRead(pin_clock)) || (!digitalRead(pin_data))); // wait for mouse to switch modes

    PullLow(pin_clock);                 //pause incoming data
}
int ReadBit()
{
    while (digitalRead(pin_clock));
    int bit = digitalRead(pin_data);
    while (!digitalRead(pin_clock));
    return bit;
}
int8_t ReadByte()
{
    int8_t data = 0;
    PullHigh(pin_clock);
    PullHigh(pin_data);
    delayMicroseconds(50);
    while (digitalRead(pin_clock));
    delayMicroseconds(5);         // needed?
    while (!digitalRead(pin_clock)); // discard start bit
    for (int i = 0; i < 8; i++)
    {
        bitWrite(data, i, ReadBit());
    }
    ReadBit();  // parity bit
    ReadBit();  // stop bit = 1

    PullLow(pin_clock);

    return data;
}
int16_t* report(int16_t data[]) {
    WriteByte(0xeb); // Send Read Data
    ReadByte(); // Read Ack Byte
    data[0] = read(); // Status bit
    data[1] = GetMovementX(data[0]); // X Movement Packet
    data[2] = GetMovementY(data[0]); // Y Movement Packet
    return data;
}
int read() {
    return ReadByte();
}
int16_t GetMovementX(int status) {
    int16_t x = read();
    if (bitRead(status, 4)) {
        for (int i = 8; i < 16; ++i) {
            x |= (1 << i);
        }
    }
    return x;
}
int16_t GetMovementY(int status) {
    int16_t y = read();
    if (bitRead(status, 5)) {
        for (int i = 8; i < 16; ++i) {
            y |= (1 << i);
        }
    }
    return y;
}

void loop()
{
    int16_t data[3];
    report(data);
    //data[0]     Status Byte
    //data[1]     X Movement Data
    //data[2]     Y Movement Data

    if (data[0] == prevData[0] && data[1] == prevData[1] && data[2] == prevData[2])
    {
        //nothing has changed
        return;
    }

    int x = screen_pos_x + data[1];
    if (x < 0)
    {
        screen_pos_x = 0;
    }
    else if (x > SCREEN_WIDTH - 1)
    {
        screen_pos_x = SCREEN_WIDTH - 1;
    }
    else
    {
        screen_pos_x = x;
    }

    int y = screen_pos_y - data[2];
    if (y < 0)
    {
        screen_pos_y = 0;
    }
    else if (y > SCREEN_HEIGHT - 1)
    {
        screen_pos_y = SCREEN_HEIGHT - 1;
    }
    else
    {
        screen_pos_y = y;
    }

    //00xxxxxxxxxxyyyyyyyyymrl
    dwordToSend = ((screen_pos_x & 0B01111111111) << 12) | ((screen_pos_y & 0B0111111111) << 3) | (data[0] & 0B00000111);
    prevData[0] = data[0];
    prevData[1] = data[1];
    prevData[2] = data[2];
    newData = true;

    pinMode(pin_irq, HIGH);
    //delay(25);
    pinMode(pin_irq, LOW);

    //Debug... serial.prints
    /*Serial.print(screen_pos_x);
    Serial.print(",");
    Serial.print(screen_pos_y);
    Serial.print("\t");
    Serial.print(data[0] & 0B00000111);
    Serial.print("\t");
    Serial.print((0x00ff0000 & dwordToSend)>>16, HEX);
    Serial.print(":");
    Serial.print((0x0000ff00 & dwordToSend)>>8, HEX);
    Serial.print(":");
    Serial.print(0x000000ff & dwordToSend, HEX);
    Serial.print("\t\t");
    Serial.println(dwordToSend, BIN); */
}