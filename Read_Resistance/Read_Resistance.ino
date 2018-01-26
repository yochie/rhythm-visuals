#include <limits.h>

//*CONFIGURATION CONSTANTS*

//Sensor pins
//At least one plz...
unsigned const short NUM_SENSORS = 2;
unsigned const short PINS[NUM_SENSORS] = {1, 2};

const boolean DEBUG = true;

//the note corresponding to each sensor
unsigned const short NOTES[NUM_SENSORS] = {60, 64};

unsigned const short MIDI_CHANNEL = 1;

unsigned const short JUMP_THRESHOLD = 100;

//duration in microseconds after sending corresponding midi messages
//for which no more signals are sent for that sensor
//Filters out the noise when going across threshold and limits number of
//aftertouch messages sent
unsigned const long NOTE_ON_DELAY = 100000;
unsigned const long NOTE_OFF_DELAY = 100000;
unsigned const long AFTERTOUCH_DELAY = 20000;

//Delay in microseconds for printing
//Prevents overloading serial communications
unsigned const short PRINT_DELAY = 50;

//used in cycle dependent settings so that performance
//remains (vaguely) similar across different clocks
unsigned const short CLOCK_RATE = 180;

//Used to scale parameters based on configuration
//Will grow with clock speed and shrink with number of sensors to sample
const float SCALE_FACTOR = (float) CLOCK_RATE / NUM_SENSORS;

//amount of sensorReadings that we average baseline over
unsigned const short BASELINE_BUFFER_SIZE = (unsigned short) (64 * SCALE_FACTOR);

//After this amount of consecutive jumps is reached,
//the baseline is reset to that jump sequences avg velocity
unsigned const long MAX_CONSECUTIVE_JUMPS = (unsigned long) (2 * SCALE_FACTOR);

//*SYSTEM CONSTANTS*
//these shouldn't have to be modified

//Serial communication Hz
unsigned const long BAUD_RATE = 115200;

//Maximum value returned by AnalogRead()
//Always 1024 for arduino
unsigned const short MAX_READING = 1023;

//*GLOBAL VARIABLES*
//would love to make them static and local to loop(), but they need to be initialized to non-zero values
//std::vector allows non-zero initialization, but I'm not sure I should include it just for this purpose...

//current baseline for each pin
unsigned short baseline[NUM_SENSORS];

void setup() {
  Serial.begin(BAUD_RATE);

  memset(baseline, MAX_READING, sizeof(baseline));
}

void loop() {
  static bool justJumped[NUM_SENSORS];

  //used to average the baseline from non-jumping sensor readings
  static unsigned short baselineBuffer[NUM_SENSORS][BASELINE_BUFFER_SIZE];

  //used to add values in the baselineBuffer
  static unsigned short baselineCount[NUM_SENSORS];

  //number of consecutive jumps
  static unsigned long consecutiveJumpCount[NUM_SENSORS];

  //used to delay midi signals from one another
  static unsigned long toWaitForMidi[NUM_SENSORS];

  //used to compute delays in microseconds while waiting
  static unsigned long lastTime[NUM_SENSORS];

  unsigned short toPrint[NUM_SENSORS];
  memset(toPrint, 0, sizeof(toPrint));

  for (unsigned short currentSensor = 0; currentSensor < NUM_SENSORS; currentSensor++) {

    unsigned short sensorReading = (unsigned short) analogRead(PINS[currentSensor]);
    unsigned short distanceAboveBaseline = max(0, sensorReading - baseline[currentSensor]);

    if (DEBUG) {
      toPrint[currentSensor] = sensorReading;
    }

    //JUMPING
    if (distanceAboveBaseline >= JUMP_THRESHOLD) {
      //WAITING
      if (toWaitForMidi[currentSensor] > 0) {
        updateRemainingTime(toWaitForMidi[currentSensor], lastTime[currentSensor]);
      }
      //STAGNATION RESET
      else if (consecutiveJumpCount[currentSensor] == MAX_CONSECUTIVE_JUMPS) {
        baseline[currentSensor] = sensorReading;

        //reset counters
        baselineCount[currentSensor] = 0;
        consecutiveJumpCount[currentSensor] = 0;
      }
      //SIGNALING
      else {
        consecutiveJumpCount[currentSensor]++;

        //NOTE_ON
        if (consecutiveJumpCount[currentSensor] == 1) {
          usbMIDI.sendNoteOn(NOTES[currentSensor], map(constrain(distanceAboveBaseline, JUMP_THRESHOLD, 256), JUMP_THRESHOLD, 256, 96, 127), MIDI_CHANNEL);
          usbMIDI.send_now();
          lastTime[currentSensor] = micros();

          // MIDI Controllers should discard incoming MIDI messages.
          while (usbMIDI.read()) {}
          toWaitForMidi[currentSensor] = NOTE_ON_DELAY;
          justJumped[currentSensor] = true;
        }
        //AFTERTOUCH
        else {
          usbMIDI.sendPolyPressure(NOTES[currentSensor], map(constrain(distanceAboveBaseline, JUMP_THRESHOLD, 256), JUMP_THRESHOLD, 256, 96, 127), MIDI_CHANNEL);
          usbMIDI.send_now();
          lastTime[currentSensor] = micros();

          // MIDI Controllers should discard incoming MIDI messages.
          while (usbMIDI.read()) {}
          toWaitForMidi[currentSensor] = AFTERTOUCH_DELAY;
        }
      }
    }
    //BASELINING
    else {
      //WAIT FOR MIDI
      if (toWaitForMidi[currentSensor] > 0) {
        updateRemainingTime(toWaitForMidi[currentSensor], lastTime[currentSensor]);
      }
      //NOTE_OFF
      else if (justJumped[currentSensor]) {
        usbMIDI.sendNoteOff(NOTES[currentSensor], 0, MIDI_CHANNEL);
        usbMIDI.send_now();
        lastTime[currentSensor] = micros();

        // MIDI Controllers should discard incoming MIDI messages.
        while (usbMIDI.read()) {}

        justJumped[currentSensor] = false;

        //wait before sending more midi signals
        toWaitForMidi[currentSensor] = NOTE_OFF_DELAY;

        //reset counters
        consecutiveJumpCount[currentSensor] = 0;
      }
      //RESET BASELINE AND THRESHOLD
      else if (baselineCount[currentSensor] > (BASELINE_BUFFER_SIZE - 1)) {
        baseline[currentSensor] = bufferAverage(baselineBuffer[currentSensor], BASELINE_BUFFER_SIZE);

        //reset counters
        baselineCount[currentSensor] = 0;
        consecutiveJumpCount[currentSensor] = 0;
      }
      //SAVE
      else {
        baselineBuffer[currentSensor][baselineCount[currentSensor]] = sensorReading;
        baselineCount[currentSensor]++;

        //reset counters
        consecutiveJumpCount[currentSensor] = 0;
      }
    }
  }
  if (DEBUG) {
    printResults(toPrint, sizeof(toPrint) / sizeof(short));
  }
}

//*HELPERS*

unsigned short bufferAverage(unsigned short * a, unsigned long aSize) {
  unsigned long sum = 0;
  for (unsigned long i = 0; i < aSize; i++) {
    //makes sure we dont bust when filling up sum
    if (sum < (ULONG_MAX - a[i])) {
      sum = sum + a[i];
    }
    else {
      Serial.println("WARNING: Exceeded ULONG_MAX while running bufferAverage(). Check your parameters to ensure buffers aren't too large.");
      delay(3000);
      return (unsigned short) constrain(ULONG_MAX / aSize, (unsigned long) 0, (unsigned long) USHRT_MAX) ;
    }
  }
  return (unsigned short) (sum / aSize);
}

//updates time left to wait and lastTime
void updateRemainingTime(unsigned long (&left), unsigned long (&last)) {
  unsigned long thisTime = micros();
  unsigned long deltaTime = thisTime - last;
  last = thisTime;
  if (deltaTime < left) {
    left -= deltaTime;
  } else {
    left = 0;
  }
}

//print results for all sensors in Arduino Plotter format
//Note that running the debug slows down the rest of the script (requires delay to avoid overloading serial)
//so you'll have to compensate for the slowdown when setting parameters
void printResults(unsigned short toPrint[], unsigned short printSize) {
  for (unsigned short i = 0; i < printSize; i++) {
    Serial.print("0");
    Serial.print(" ");
    Serial.print(toPrint[i]);
    Serial.print(" ");
    Serial.print(baseline[i]);
    Serial.print(" ");
    Serial.print(baseline[i] + JUMP_THRESHOLD);
    Serial.print(" ");
  }
  Serial.println();
  delayMicroseconds(PRINT_DELAY);
}
