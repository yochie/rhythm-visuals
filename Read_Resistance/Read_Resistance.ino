#include <limits.h>

//*CONFIGURATION CONSTANTS*

//Sensor pins
//At least one plz...
const int NUM_SENSORS = 1;
const int SENSOR_PINS[NUM_SENSORS] = {1};

const boolean DEBUG = true;

/*MIDI CONFIG*/
const boolean WITH_MIDI = true;
const int NOTES[NUM_SENSORS] = {60};
const int MIDI_CHANNEL = 1;

/*MOTOR CONFIG*/
const boolean WITH_MOTORS = true;
const int NUM_MOTORS = 1;
const int MOTOR_PINS[NUM_MOTORS] = {13};
unsigned const long MAX_MOTOR_PULSE_DURATION = 100000;

//MAX_THRESHOLD is used when the baseline is very unstable
const int MAX_THRESHOLD = 150;

//MIN_THRESHOLD is used when the baseline is very stable
const int MIN_THRESHOLD = 150;

//Time between threshold traversal and rising() signal
//Allows for velocity measurment and ignoring very short jumps
unsigned const long NOTE_VELOCITY_DELAY = 2000;

//Delay in microseconds after sending falling signal
//for which no more signals are sent for that sensor
unsigned const long NOTE_OFF_DELAY = 10000;

//Delay in microseconds between sustain signals
unsigned const long SUSTAIN_DELAY = 50000;

//Delay in micro seconds between baseline samples
unsigned const long BASELINE_SAMPLE_DELAY = 500;

//Delay in microseconds adter each line of debug messages
//Blocking (uses delay() function)
//Prevents overloading serial communications
const int PRINT_DELAY = 50;

//number of microseconds after jump during which baseline update is paused
unsigned const long BASELINE_BLOWBACK_DELAY = 2000;

//amount of baseline samples that we average baseline over
//Multiply with BASELINE_SAMPLE_DELAY to get baseline update duration.
const int BASELINE_BUFFER_SIZE = 1000;

//number of samples removed from baseline buffer when jump is over
//This is used to prevent by removing rising edge portion of signal
//that is below threshold from weighing in on baseline.
//Making too large would prevent baseline update while fast-tapping.
//Multiply with BASELINE_SAMPLE_DELAY  to get the rise time to reach the threshold.
const int RETRO_JUMP_BLOWBACK_SAMPLES = 3000 / BASELINE_SAMPLE_DELAY;

//After this amount of sustains
//the baseline is reset to that jump sequences avg velocity
unsigned const long MAX_CONSECUTIVE_SUSTAINS = 10 * 1000000 / SUSTAIN_DELAY;

//*SYSTEM CONSTANTS*
//these shouldn't have to be modified

//Serial communication Hz
const int BAUD_RATE = 115200;

//Maximum value returned by AnalogRead()
//Always 1023 for arduino
const int MAX_READING = 1023;

//*GLOBAL VARIABLES*
//would love to make them static and local to loop(), but they need to be initialized to non-zero values
//std::vector allows non-zero initialization, but I'm not sure I should include it just for this purpose...

//current baseline for each pin
int baseline[NUM_SENSORS];

//current threshold
int jumpThreshold[NUM_SENSORS];

void setup() {
  if (DEBUG || WITH_MIDI) {
    Serial.begin(BAUD_RATE);
  }
  for (int sensor = 0; sensor < NUM_SENSORS; sensor++) {
    baseline[sensor] = analogRead(SENSOR_PINS[sensor]);
    jumpThreshold[sensor] = (MIN_THRESHOLD + MAX_THRESHOLD) / 2;
  }

  if (WITH_MOTORS) {
    for (int motor = 0; motor < NUM_MOTORS; motor++) {
      pinMode(MOTOR_PINS[motor], OUTPUT);
    }
  }
}

void loop() {
  //*STATIC VARIABLES*

  //used to send falling() signal
  //set to true after rising() signal
  static bool justJumped[NUM_SENSORS];

  //filled with the average value computed at each loop() for each sensor
  static int baselineBuffer[NUM_SENSORS][BASELINE_BUFFER_SIZE];
  static int baselineBufferIndex[NUM_SENSORS];

  static int sustainCount[NUM_SENSORS];

  //used to delay baseline calculation after coming out of jump and between samples
  static unsigned long toWaitBeforeBaseline[NUM_SENSORS];

  //used to delay midi signals from one another
  static unsigned long toWaitBeforeSignal[NUM_SENSORS];

  //used to calculate time difference in microseconds while waiting
  static unsigned long lastSignalTime[NUM_SENSORS];
  static unsigned long lastBaselineTime[NUM_SENSORS];

  //*STACK VARIABLES*
  int toPrint[NUM_SENSORS];
  memset(toPrint, 0, sizeof(toPrint));

  //process buffer content for each sensor
  for (int currentSensor = 0; currentSensor < NUM_SENSORS; currentSensor++) {
    int sensorReading = analogRead(SENSOR_PINS[currentSensor]);
    int distanceAboveBaseline = max(0, sensorReading - baseline[currentSensor]);

    if (DEBUG) {
      toPrint[currentSensor] = sensorReading;
    }

    //JUMPING
    if (distanceAboveBaseline >= jumpThreshold[currentSensor]) {
      //WAITING
      if (toWaitBeforeSignal[currentSensor] > 0) {
        updateRemainingTime(toWaitBeforeSignal[currentSensor], lastSignalTime[currentSensor]);
      }
      //STAGNATION RESET
      else if (sustainCount[currentSensor] > MAX_CONSECUTIVE_SUSTAINS) {
        baseline[currentSensor] = sensorReading;

        //reset counters
        baselineBufferIndex[currentSensor] = 0;
        sustainCount[currentSensor] = 0;
      }
      //SIGNALING
      else {
        //VELOCITY_DELAY
        if (sustainCount[currentSensor] == 0) {
          lastSignalTime[currentSensor] = micros();
          toWaitBeforeSignal[currentSensor] = NOTE_VELOCITY_DELAY;
        }
        //RISING
        else if (sustainCount[currentSensor] == 1) {
          rising(currentSensor, distanceAboveBaseline);
                    
          lastSignalTime[currentSensor] = micros();
          toWaitBeforeSignal[currentSensor] = SUSTAIN_DELAY;          
          justJumped[currentSensor] = true;
          sustainCount[currentSensor]++;
        }
        //SUSTAIN
        else {
          sustained(currentSensor, distanceAboveBaseline, NOTE_VELOCITY_DELAY + ((sustainCount[currentSensor] - 1) * SUSTAIN_DELAY));
          
          lastSignalTime[currentSensor] = micros();
          toWaitBeforeSignal[currentSensor] = SUSTAIN_DELAY;
          sustainCount[currentSensor]++;
        }

        //jump counter
        sustainCount[currentSensor]++;
      }
    }
    //BASELINING
    else {
      //FALLING
      if (justJumped[currentSensor]) {
        falling(currentSensor);
        
        //wait before sending more midi signals
        //debounces falling edge
        lastSignalTime[currentSensor] = micros();
        toWaitBeforeSignal[currentSensor] = NOTE_OFF_DELAY;

        //wait before buffering baseline
        //this is to ignore the sensor "blowback" (erratic readings after jumps)
        //and remove falling edge portion of signal that is below threshold
        lastBaselineTime[currentSensor] = micros();
        toWaitBeforeBaseline[currentSensor] = BASELINE_BLOWBACK_DELAY;

        justJumped[currentSensor] = false;

        //backtrack baseline count to remove jump start 
        //(might not do anything if we just updated baseline)
        baselineBufferIndex[currentSensor] = max( 0, baselineBufferIndex[currentSensor] - RETRO_JUMP_BLOWBACK_SAMPLES);
      }
      //WAIT BEFORE BASELINING
      else if (toWaitBeforeBaseline[currentSensor] > 0) {
        updateRemainingTime(toWaitBeforeBaseline[currentSensor], lastBaselineTime[currentSensor]);
      }
      //RESET BASELINE AND THRESHOLD
      else if (baselineBufferIndex[currentSensor] > (BASELINE_BUFFER_SIZE - 1)) {
        jumpThreshold[currentSensor] = updateThreshold(baselineBuffer[currentSensor], baseline[currentSensor], jumpThreshold[currentSensor]);
        baseline[currentSensor] = bufferAverage(baselineBuffer[currentSensor], BASELINE_BUFFER_SIZE);

        //reset counter
        baselineBufferIndex[currentSensor] = 0;
      }
      //SAMPLE BASELINE
      else {
        baselineBuffer[currentSensor][baselineBufferIndex[currentSensor]] = sensorReading;
        baselineBufferIndex[currentSensor]++;

        //reset timer
        lastBaselineTime[currentSensor] = micros();
        toWaitBeforeBaseline[currentSensor] = BASELINE_SAMPLE_DELAY;
      }

      //reset jump counter
      sustainCount[currentSensor] = 0;
    }

    if (DEBUG) {
      printResults(toPrint, sizeof(toPrint) / sizeof(int));
    }
  }
}

//*HELPERS*

int bufferAverage(int * a, int aSize) {
  unsigned long sum = 0;
  int i;
  for (i = 0; i < aSize; i++) {
    //makes sure we dont bust when filling up sum
    if (sum < (ULONG_MAX - a[i])) {
      sum += a[i];
    }
    else {
      Serial.println("WARNING: Exceeded ULONG_MAX while running bufferAverage(). Check your parameters to ensure buffers aren't too large.");
      delay(1000);
      break;
    }
  }
  return (int) (sum / i);
}

int varianceFromTarget(int * a, int aSize, int target) {
  unsigned long sum = 0;
  int i;
  for (i = 0; i < aSize; i++) {
    //makes sure we dont bust when filling up sum
    if (sum < ULONG_MAX - a[i]) {
      sum += pow( (a[i] - target), 2);
    }
    else {
      Serial.println("WARNING: Exceeded ULONG_MAX while running varianceFromTarget(). Check your parameters to ensure buffers aren't too large.");
      delay(1000);
      break;
    }
  }

  return (int) (sum / i);
}

//updates time left to wait and given last time that are both passed by reference
void updateRemainingTime(unsigned long (&left), unsigned long (&last)) {
  unsigned long thisTime = micros();
  unsigned long deltaTime = thisTime - last;

  if (deltaTime < left) {
    left -= deltaTime;
  } else {
    left = 0;
  }

  last = thisTime;
}

//Single use function to improve readability
int updateThreshold(int (&baselineBuff)[BASELINE_BUFFER_SIZE], int oldBaseline, int oldThreshold) {

  int varianceFromBaseline = varianceFromTarget(baselineBuff, BASELINE_BUFFER_SIZE, oldBaseline);
  int newThreshold = constrain(varianceFromBaseline, MIN_THRESHOLD, MAX_THRESHOLD);

  int deltaThreshold = newThreshold - oldThreshold;
  if (deltaThreshold < 0) {
    //split the difference to slow down threshold becoming more sensitive
    newThreshold = constrain(oldThreshold + ((deltaThreshold) / 4), MIN_THRESHOLD, MAX_THRESHOLD);
  }

  return newThreshold;
}


//print results for all sensors in Arduino Plotter format
//Note that running the debug slows down the rest of the script (requires delay to avoid overloading serial)
//so you'll have to compensate for the slowdown when setting parameters
void printResults(int toPrint[], int printSize) {
  for (int i = 0; i < printSize; i++) {
    Serial.print("0");
    Serial.print(" ");
    Serial.print(toPrint[i]);
    Serial.print(" ");
    Serial.print(baseline[i]);
    Serial.print(" ");
    Serial.print(baseline[i] + jumpThreshold[i]);
    Serial.print(" ");
    Serial.print(MAX_READING);
    Serial.print(" ");

  }
  Serial.println();
  delayMicroseconds(PRINT_DELAY);
}

int sensorToMotor(int sensorPin) {
  return MOTOR_PINS[0];
}

void rising(int sensor, int velocity) {
  if (WITH_MOTORS) {
    digitalWrite(sensorToMotor(sensor), HIGH);
  }
  if (WITH_MIDI) {
    usbMIDI.sendNoteOn(NOTES[sensor], map(constrain(velocity, jumpThreshold[sensor], 512), jumpThreshold[sensor], 512, 64, 127), MIDI_CHANNEL);
    usbMIDI.send_now();

    // MIDI Controllers should discard incoming MIDI messages.
    while (usbMIDI.read()) {}
  }
}

void falling(int sensor) {
  if (WITH_MOTORS) {
    digitalWrite(sensorToMotor(sensor), LOW);
  }

  if (WITH_MIDI) {
    usbMIDI.sendNoteOff(NOTES[sensor], 0, MIDI_CHANNEL);
    usbMIDI.send_now();

    // MIDI Controllers should discard incoming MIDI messages.
    while (usbMIDI.read()) {}
  }
}

void sustained(int sensor, int velocity, unsigned long duration) {
  if (WITH_MOTORS) {
    if (duration >= MAX_MOTOR_PULSE_DURATION) {
      digitalWrite(sensorToMotor(sensor), LOW);
    }
  }
  if (WITH_MIDI) {
    //    usbMIDI.sendPolyPressure(NOTES[sensor], map(constrain(velocity, jumpThreshold[sensor], 512), jumpThreshold[sensor], 512, 64, 127), MIDI_CHANNEL);
    //    usbMIDI.send_now();
    //
    //    // MIDI Controllers should discard incoming MIDI messages.
    //    while (usbMIDI.read()) {}
  }
}

