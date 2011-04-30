/*
** If you want the highest speed I2C, then you'll want to use
** hardware I2C and push the transfer rate as high as you can.
**
** If, on the other hand, you're using I2C to control parts of
** the RF circuitry of a sensitive radio receiver, and you only
** need to send a few bits now and then, you can use a software
** implementation of I2C and slow the bit rate down so it doesn't
** generate a hash of RF noise.  
**
** You can also jitter the I2C clock so that it isn't producing
** a consistent frequency and all its harmonics.
**
** You can also add some capacitance to the SCL and SDA lines to 
** smooth out the rough edges of the clock and data pulses, the 
** protocol will wait for the lines to settle whatever their RC 
** constant is.
**
** This is wikipedia bitbang implementation of I2C configured to 
** run on a pair of Arduino pins with an option to jitter the 
** specified clock period between I2CSPEED-I2CJITTER and 
** I2CSPEED+I2CJITTER.
**
** As yet untested for its RF properties, but it works down with
** I2CSPEED and I2CJITTER specified, which is 2 bits/second on
** average with 0.5 bit/second jitter on an Arduino UNO bread
** boarded to a PCF8575 driving a bank of LEDs.
*/

/* Hardware-Specific Support Functions That MUST Be Customized */
/* These have been customized for an Arduino */
#define I2CSPEED  500000  // average clock period in microseconds
#define I2CJITTER 250000  // 
#define SCL 2      // digital pin 2 for clock
#define SDA 3      // digital pin 3 for data

void I2CDELAY() {
  delayMicroseconds(random(I2CSPEED-I2CJITTER, I2CSPEED+I2CJITTER));
}

/* Set SCL as input and return current level of line, 0 or 1 */
bool READSCL(void) { 
  pinMode(SCL, INPUT);
  digitalRead(SCL); 
}

/* Set SDA as input and return current level of line, 0 or 1 */
bool READSDA(void) { 
  pinMode(SDA, INPUT);
  digitalRead(SDA); 
}

/* Actively drive SCL signal low */
void CLRSCL(void) {
  pinMode(SCL, OUTPUT);
  digitalWrite(SCL, 0); 
}

/* Actively drive SDA signal low */
void CLRSDA(void) { 
  pinMode(SDA, OUTPUT);
  digitalWrite(SDA, 0); 
}

bool arbitration_lost = false;

void ARBITRATION_LOST(void) {
  arbitration_lost = true;
}

/* End of Hardware-Specific Support Functions */

/* Global Data */
bool started = false;

void i2c_start_cond(void)
{
  /* if started, do a restart cond */
  if (started) {
    /* set SDA to 1 */
    READSDA();
    I2CDELAY();
    /* Clock stretching */
    while (READSCL() == 0)
      ;  /* You should add timeout to this loop */
  }
  if (READSDA() == 0)
    ARBITRATION_LOST();
  /* SCL is high, set SDA from 1 to 0 */
  CLRSDA();
  I2CDELAY();
  CLRSCL();
  started = true;
}

void i2c_stop_cond(void)
{
  /* set SDA to 0 */
  CLRSDA();
  I2CDELAY();
  /* Clock stretching */
  while (READSCL() == 0)
    ;  /* You should add timeout to this loop */
  /* SCL is high, set SDA from 0 to 1 */
  if (READSDA() == 0)
    ARBITRATION_LOST();
  I2CDELAY();
  started = false;
}

/* Write a bit to I2C bus */
void i2c_write_bit(bool bit)
{
  if (bit) 
    READSDA();
  else 
    CLRSDA();
  I2CDELAY();
  /* Clock stretching */
  while (READSCL() == 0)
    ;  /* You should add timeout to this loop */
  /* SCL is high, now data is valid */
  /* If SDA is high, check that nobody else is driving SDA */
  if (bit && READSDA() == 0) 
    ARBITRATION_LOST();
  I2CDELAY();
  CLRSCL();
}

/* Read a bit from I2C bus */
bool i2c_read_bit(void)
{
  bool bit;
  /* Let the slave drive data */
  READSDA();
  I2CDELAY();
  /* Clock stretching */
  while (READSCL() == 0)
    ;  /* You should add timeout to this loop */
  /* SCL is high, now data is valid */
  bit = READSDA();
  I2CDELAY();
  CLRSCL();
  return bit;
}

/* Write a byte to I2C bus. Return 0 if ack by the slave */
bool i2c_write_byte(bool send_start, bool send_stop, unsigned char byte)
{
  unsigned bit;
  bool nack;
  if (send_start) 
    i2c_start_cond();
  for (bit = 0; bit < 8; bit++) {
    i2c_write_bit((byte & 0x80) != 0);
    byte <<= 1;
  }
  nack = i2c_read_bit();
  if (send_stop)
    i2c_stop_cond();
  return nack;
}

/* Read a byte from I2C bus */
unsigned char i2c_read_byte(bool nack, bool send_stop)
{
  unsigned char byte = 0;
  unsigned bit;
  for (bit = 0; bit < 8; bit++)
    byte = (byte << 1) | i2c_read_bit();              
  i2c_write_bit(nack);
  if (send_stop)
    i2c_stop_cond();
  return byte;
}

/* Begin Arduino specific sketch */
/* 
** count up from zero with random delays between 1 and 2 seconds
** and send the count to the attached pcf8575 for display on leds.
*/

#define PCF8575_ADDR 0x20
void setup() {
  Serial.begin(9600);
}

int count = 0;
void loop() {
  Serial.println(count, DEC);
  if (i2c_write_byte(true, false, (PCF8575_ADDR << 1) | 0)) {  // write data
    Serial.println("write address failed");
    delay(100);
    return;
  }
  if (arbitration_lost) {
    arbitration_lost = false;
    Serial.println("arbitration lost during address");
    delay(100);
    return;
  }
  if (i2c_write_byte(false, false, (count >> 8) & 0xff)) {
    Serial.println("write high byte failed");
    delay(100);
    return;
  }
  if (arbitration_lost) {
    arbitration_lost = false;
    Serial.println("arbitration lost during high byte");
    delay(100);
    return;
  }
  if (i2c_write_byte(false, true, count & 0xff)) {
    Serial.println("write high byte failed");
    delay(100);
    return;
  }
  count += 256;
  delay(100);
}


