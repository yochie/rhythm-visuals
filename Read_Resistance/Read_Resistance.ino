#include <limits.h>

//*CONFIGURATION CONSTANTS*

//Sensor pins
//At least one plz...
unsigned const short NUM_SENSORS = 1;
unsigned const short PINS[NUM_SENSORS] = {0};
unsigned const short NOTES[NUM_SENSORS] = {61};

unsigned const short MIDI_CHANNEL = 0;

//Controller clock rate in MHz
//to be used in cycle dependent settings so that performance
//remains consistent with different clocks
unsigned const short CLOCK_RATE = 180;

//to avoid sending signals for noise spikes
unsigned const short MIN_JUMPS_FOR_SIGNAL = (CLOCK_RATE / 18) / NUM_SENSORS;

//jumpThreshold is the difference in value from baseline that qualifies as a jump
//It will vary in the defined range based on how unstable the reading is.
//MAX_THRESHOLD is used when baseline varies across wide range
//MIN_THRESHOLD is used when baseline is flat
unsigned const short MAX_THRESHOLD = 150;
unsigned const short MIN_THRESHOLD = 75;

//amount of sensorReadings that we average baseline over
unsigned const short BASELINE_BUFFER_SIZE = (unsigned const short) CLOCK_RATE / NUM_SENSORS;

//Amount of sensor readings used to average press velocity.
//Avoid making too large as then you might miss short jumps and add too much latency
//Setting it lower would reduce latency but also allow for more noise
unsigned const short JUMP_BUFFER_SIZE = CLOCK_RATE * 4 / NUM_SENSORS;

//stagnant jumps we average over when resetting baseline after getting stuck in jump
//Make sure its in the range [1,MAX_STAGNANT_JUMPS - STAGNATION_BUFFER_DELAY]
unsigned const short SJUMP_BUFFER_SIZE = 128 / NUM_SENSORS;

//After this amount of stagnant (consecutive and non-varying) jumps is reached,
//the baseline is reset to that jump sequences avg velocity
unsigned const long MAX_STAGNANT_JUMPS = CLOCK_RATE * 4 / NUM_SENSORS;

//Used to ignore first part of stagnant jump when resetting baseline
unsigned const long STAGNATION_BUFFER_DELAY = MAX_STAGNANT_JUMPS / 3;

//number of loop() cycles after jump during which baseline update is paused
unsigned const short JUMP_BLOWBACK_DURATION = (CLOCK_RATE / 8) / NUM_SENSORS;

//number of cycles removed from baseline when jump is over
//this is used to prevent jump beginning from weighing in on baseline
//making too large would prevent baseline update while fast-tapping
unsigned const short RETRO_BASELINE_CUTOFF = 10;

//*SYSTEM CONSTANTS*
//these shouldn't have to be modified

//Serial communication Hz
unsigned const long BAUD_RATE = 115200;

//Maximum value returned by AnalogRead()
//Always 1024 for arduino
unsigned const short MAX_READING = 1024;

//How often  should westore stagnant jump values to the sJumpBuffer
//*DO NOT MODIFY*
unsigned const long CYCLES_PER_SJUMP = max(((MAX_STAGNANT_JUMPS - STAGNATION_BUFFER_DELAY) / SJUMP_BUFFER_SIZE), 1);

//*GLOBAL VARIABLES*
//would love to make them static but they need to be initialized to non-zero values...
//TODO: find another way to not have these global (maybe using a boolean "first" to initialize)
//or any other way to ensure that the first operation is a write
//TODO: Move a few of these back to static

//current baseline for each pin
unsigned short baseline[NUM_SENSORS];

//last read value for each pin
unsigned short lastSensorReading[NUM_SENSORS];

//current threshold
unsigned short jumpThreshold[NUM_SENSORS];

//number of stagnant jumps (not all are stored)
unsigned long sJumpCount[NUM_SENSORS];

//number of stored stagnant jumps
unsigned short sJumpIndex[NUM_SENSORS];

//number of cycles left to recuperate from blowback
static unsigned short toWait[NUM_SENSORS];

void setup() {
  Serial.begin(BAUD_RATE);

  memset(baseline, MAX_READING, sizeof(baseline));
  memset(lastSensorReading, MAX_READING * 2, sizeof(lastSensorReading));
  memset(jumpThreshold, (MIN_THRESHOLD + MAX_THRESHOLD / 2), sizeof(jumpThreshold));
}

void loop() {
  //*STATIC VARIABLES*

  //used to initiate blowback waiting
  static bool justJumped[NUM_SENSORS];

  //used to average the baseline
  //gets the average value computed at each loop()
  static unsigned short baselineBuffer[NUM_SENSORS][BASELINE_BUFFER_SIZE];

  //counts the number of loop() executions without jumps
  //used to add values in the baselineBuffer
  static unsigned short baselineCount[NUM_SENSORS];

  //used to reset baseline after getting stuck in jump
  static unsigned short sJumpBuffer[NUM_SENSORS][SJUMP_BUFFER_SIZE];

  //*LOCAL VARIABLES*

  //small buffer used to smooth signal
  unsigned short jumpBuffer[NUM_SENSORS][JUMP_BUFFER_SIZE];
  memset(jumpBuffer, 0, sizeof(jumpBuffer));

  unsigned short toPrint[NUM_SENSORS];
  memset(toPrint, 0, sizeof(toPrint));

  //*PROCESS SIGNAL*

  fillJumpBuffer(jumpBuffer);

  //process buffer content
  for (unsigned short currentSensor = 0; currentSensor < NUM_SENSORS; currentSensor++) {

    unsigned short sensorReadingAvg = bufferAverage(jumpBuffer[currentSensor], JUMP_BUFFER_SIZE);
    unsigned short distanceFromBaseline = max(0, sensorReadingAvg - baseline[currentSensor]);

    //for debug
    toPrint[currentSensor] = constrain(sensorReadingAvg, 0, MAX_READING);

    //JUMPING
    if (distanceFromBaseline >= jumpThreshold[currentSensor]) {

      //TOO LONG
      if (sJumpIndex[currentSensor] == SJUMP_BUFFER_SIZE) {

        unsigned short sJumpAvg = bufferAverage(sJumpBuffer[currentSensor], SJUMP_BUFFER_SIZE);

        //raise average a little to ensure we get out of jump
        baseline[currentSensor] = min(MAX_READING, sJumpAvg * 1.1);

        baselineCount[currentSensor] = 0;
        sJumpCount[currentSensor] = 0;
        sJumpIndex[currentSensor] = 0;
        lastSensorReading[currentSensor] = MAX_READING * 2;
      }

      //INCREMENT
      if (sJumpCount[currentSensor] > STAGNATION_BUFFER_DELAY &&
          (sJumpCount[currentSensor] - STAGNATION_BUFFER_DELAY) % CYCLES_PER_SJUMP == 0) {
        sJumpBuffer[currentSensor][sJumpIndex[currentSensor]] = sensorReadingAvg;
        sJumpIndex[currentSensor]++;
      }
      sJumpCount[currentSensor]++;
      lastSensorReading[currentSensor] = sensorReadingAvg;

      //NOTE_ON
      if (sJumpCount[currentSensor] == MIN_JUMPS_FOR_SIGNAL) {
        justJumped[currentSensor] = true;
        usbMIDI.sendNoteOn(NOTES[currentSensor], map(constrain(distanceFromBaseline, 0, 512), 0, 512, 0, 127), 1);
        usbMIDI.send_now();
        // MIDI Controllers should discard incoming MIDI messages.
        while (usbMIDI.read()) {
        }
      }
      //AFTERTOUCH
      else if (sJumpCount[currentSensor] > MIN_JUMPS_FOR_SIGNAL) {
        usbMIDI.sendPolyPressure(NOTES[currentSensor], map(constrain(distanceFromBaseline, 0, 512), 0, 512, 0, 127), 1);
        usbMIDI.send_now();
        // MIDI Controllers should discard incoming MIDI messages.
        while (usbMIDI.read()) {
        }
      }
    }

    //BASELINING
    else {
      //NOTE_OFF
      if (justJumped[currentSensor]) {
        usbMIDI.sendNoteOff(NOTES[currentSensor], 0, 1);
        usbMIDI.send_now();
        Serial.println("OFF");
        // MIDI Controllers should discard incoming MIDI messages.
        while (usbMIDI.read()) {}
        justJumped[currentSensor] = false;
        baselineCount[currentSensor] = max(0, baselineCount[currentSensor] - RETRO_BASELINE_CUTOFF);
        toWait[currentSensor] = JUMP_BLOWBACK_DURATION;
        lastSensorReading[currentSensor] = MAX_READING * 2;
        sJumpCount[currentSensor] = 0;
        sJumpIndex[currentSensor] = 0;
      }
      //WAIT
      else if (toWait[currentSensor] > 0) {
        toWait[currentSensor]--;
      }
      //RESET
      else if (baselineCount[currentSensor] > (BASELINE_BUFFER_SIZE - 1)) {

        resetThreshold(baselineBuffer[currentSensor], currentSensor, baseline[currentSensor]);

        baseline[currentSensor] = bufferAverage(baselineBuffer[currentSensor], BASELINE_BUFFER_SIZE);
        baselineCount[currentSensor] = 0;
      }
      //SAVE
      else {
        baselineBuffer[currentSensor][baselineCount[currentSensor]] = sensorReadingAvg;
        baselineCount[currentSensor]++;
        lastSensorReading[currentSensor] = MAX_READING * 2;
        sJumpCount[currentSensor] = 0;
        sJumpIndex[currentSensor] = 0;
      }
    }
  }
  printResults(toPrint, sizeof(toPrint) / sizeof(short));
}

//*HELPERS*

//returns array average
//If sum is over max size, will return ULONG_MAX/aSize and print warning
unsigned short bufferAverage(unsigned short * a, unsigned long aSize) {
  unsigned long sum = 0;
  for (unsigned long i = 0; i < aSize; i++) {
    //makes sure we dont bust when filling up sum
    if (sum < ULONG_MAX - a[i]) {
      sum = sum + a[i];
    }
    else {
      Serial.println("WARNING: Exceeded ULONG_MAX while running bufferAverage(). Check your parameters to ensure buffers aren't too large.");
      delay(3000);
      return (unsigned short) constrain(ULONG_MAX/aSize,0, USHRT_MAX) ;
    }
  }

  return (unsigned short) (sum / aSize);
}

//If sum is over max size, will return ULONG_MAX and print warning
unsigned short bufferStdDev(unsigned short * a, unsigned long aSize, unsigned short avg) {
  unsigned long sum = 0;
  for (unsigned long i = 0; i < aSize; i++) {
    //makes sure we dont bust when filling up sum
    if (sum < ULONG_MAX - a[i]) {
      sum = sum + abs((int) a[i] - avg);
    }
    else {
      Serial.println("WARNING: Exceeded ULONG_MAX while running bufferStdDev(). Check your parameters to ensure buffers aren't too large.");
      delay(3000);
      return (unsigned short) constrain(ULONG_MAX/aSize,0, USHRT_MAX);
    }
  }

  return (unsigned short) (sum / aSize);
}

void fillJumpBuffer(unsigned short (&jumpBuffer)[NUM_SENSORS][JUMP_BUFFER_SIZE]) {
  for (unsigned short sample = 0; sample < JUMP_BUFFER_SIZE; sample++) {
    for (unsigned short sensor = 0; sensor < NUM_SENSORS; sensor++) {
      jumpBuffer[sensor][sample] = (unsigned short) analogRead(PINS[sensor]);
    }
  }
}

void resetThreshold(unsigned short (&baselineBuffer)[BASELINE_BUFFER_SIZE], unsigned short sensor, unsigned short average) {
  unsigned short standardDeviation = bufferStdDev(baselineBuffer, BASELINE_BUFFER_SIZE, average);
  unsigned short newThreshold = min(max(pow(standardDeviation, 2), MIN_THRESHOLD), MAX_THRESHOLD);

  int deltaThreshold = jumpThreshold[sensor] - newThreshold;

  if (deltaThreshold > 0) {
    jumpThreshold[sensor] =  newThreshold;
  }
  else {
    //split the difference to slow down threshold becoming more sensitive
    jumpThreshold[sensor] = max(jumpThreshold[sensor] - (deltaThreshold) / 4, MIN_THRESHOLD);
  }
}

void printResults(unsigned short toPrint[], unsigned short printSize) {
  //print results for all sensors in Arduino Plotter format
  for (unsigned short i = 0; i < printSize; i++) {

    Serial.print("0");
    Serial.print(" ");
    Serial.print(toPrint[i]);
    Serial.print(" ");
    Serial.print(baseline[i]);
    Serial.print(" ");
    Serial.print(baseline[i] + jumpThreshold[i]);
    Serial.print(" ");
    Serial.print(sJumpIndex[i]);
    Serial.print(" ");
    if (toWait[i] > 0) {
      Serial.print(100);
    }
    else {
      Serial.print(0);
    }
    Serial.print(" ");
    Serial.print(1000);
  }
  Serial.println();
  //delay(1);
}
