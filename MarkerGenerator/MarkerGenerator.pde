/*
** This sketch converts your Arduino into a frequency marker.
**
** Note that this is overkill, and it breaks parts of the standard
** Arduino software by grabbing the timer. You can get an ~ 1kHz
** marker by simply using the standard Arduino analogWrite(pin, duty)
** on a pwm enabled pin.  All the pwm generators are programmed
** to prescale by 64, so they're counting a 250kHz clock.  They
** transition the output pin on for duty/256 and off for (256-duty)/256.
** Or is it duty/255 on, (255-duty)/255 off
**
** A frequency marker generates harmonics of a base frequency.
** It's useful for testing a receiver's ability to receive and
** the frequency readout.
**
** We use Timer/Counter 0.  It can run off the system 16MHz clock
** with prescalers of 1, 8, 64, 256, or 1024, yielding frequencies
** of 16MHz, 2MHz, 250kHz, 62.5kHz, or 1.5625kHz.  We can output 
** these frequencies directly or divide them further by 2 through
** 255.
**
** The output marker frequencies will appear on OC0A, which is 
** PD6, or Arduino digital pin 6.
**
** So, starting from the 16MHz system clock, we can:
**   divide by 16 -> 1MHz
**   divide by 32 -> 500kHz
**   divide by 64 -> 250kHz
**   divide by 128 -> 125kHz
**   prescale to 2MHz, divide by 20 -> 100kHz
**   prescale to 2MHz, divide by 40 ->  50kHz
**   prescale to 2MHz, divide by 80 ->  25kHz
**   prescale to 2MHz, divide by 200 -> 10kHz
**   prescale to 250kHz, divide by 50 -> 5kHz
**   prescale to 250kHz, divide by 250 -> 1kHz
**
** Not sure if this works or not, need to write a tuner for the ensemble to see.
**
** It works, but not sure which frequencies it is actually generating, need to
** write the frequency counter to test.
*/

class MarkerGenerator {
  private:
    bool _isvalid;
    long _frequency;
    byte _prescaler, _count;
  public:
    MarkerGenerator(long frequency = 10000) {
      setFrequency(frequency);
    }
    void setFrequency(long frequency) {
      TCCR0B = 0;        // disable timer 0
      switch (frequency) {
        case 1000000: _prescaler = 1; _count = 16; _isvalid = true; break;
        case  500000: _prescaler = 1; _count = 32; _isvalid = true; break;
        case  250000: _prescaler = 1; _count = 64; _isvalid = true; break;
        case  125000: _prescaler = 1; _count = 128; _isvalid = true; break;
        case  100000: _prescaler = 8; _count = 20; _isvalid = true; break;
        case   50000: _prescaler = 8; _count = 40; _isvalid = true; break;
        case   25000: _prescaler = 8; _count = 80; _isvalid = true; break;
        case   10000: _prescaler = 8; _count = 200; _isvalid = true; break;
        case    5000: _prescaler = 64; _count = 50; _isvalid = true; break;
        case    1000: _prescaler = 64; _count = 250; _isvalid = true; break;
        default: _isvalid = false; break;
      }
      if (_isvalid) {
        _frequency = frequency;
        pinMode(6, OUTPUT);    // enable output
        // compute the correct count
        byte ocr = 16000000L / (_frequency * 2 * _prescaler) - 1;
        OCR0A = ocr;        // set the counts
        TCNT0 = 0;          // start count at zero
        TIMSK0 = 0;         // no interrupts
        if (_prescaler == 1)
          TCCR0B = 0x01;
        else if (_prescaler == 8)
          TCCR0B = 0x02;
        else if (_prescaler == 64)
          TCCR0B = 0x03;
        TCCR0A = 0x42;  // toggle OC0A on match, CTC mode
      }
    }
};

MarkerGenerator mk(100000);  // one hundred kilohertz marker

void setup() {
  long frequency = 100000;
  char line[128];
  byte n = 0;
  mk.setFrequency(frequency);
  Serial.begin(9600);
  Serial.print("MarkerGenerator at "); Serial.println(frequency, DEC);
  while (1) {
    char c = Serial.read();
    if (c != -1) {
      if (c != '\n') {
        line[n++] = c;
        continue;
      }
      line[n] = 0;
      if (strcmp(line, "on") == 0) {
        Serial.println("received on");
        n = 0;
        mk.setFrequency(frequency);
        continue;
      }
      if (strcmp(line, "off") == 0) {
        Serial.println("received off");
        n = 0;
        mk.setFrequency(0);
        continue;
      }
      if (line[0] >= '0' && line[0] <= '9') {
        long count = 0;
        for (int i = 0; i < n; i += 1) {
          if (line[i] >= '0' && line[i] <= '9') {
            count *= 10;
            count += line[i] - '0';
          } else {
            count = 0;
            break;
          }
        }
        Serial.print("received count "); Serial.println(count, DEC);
        mk.setFrequency(count);
        if (count != 0) {
          frequency = count;
          Serial.print("MarkerGenerator at "); Serial.println(frequency, DEC);
        }
        n = 0;
        continue;
      }
      Serial.print("received: '"); Serial.print(line); Serial.println("' which makes no sense");
      n = 0;
    }
  }
}

void loop() {}

  

