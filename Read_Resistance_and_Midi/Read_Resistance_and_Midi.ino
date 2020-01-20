#include <limits.h>

#include "config.h"

//current baseline for each pin
int baseline[NUM_SENSORS];

//current threshold
int jumpThreshold[NUM_SENSORS];

//used to space motor activations from one another
int tapsToIgnore[NUM_SENSORS];

//For midi input sustains
unsigned long lastExternalMidiOn[NUM_SENSORS];


void setup() {

  Serial.begin(BAUD_RATE);
  delay(3000);
  Serial.println("Midi input only : ");
  if (READ_RESISTANCE) {
    Serial.println("yes");
  } else {
    Serial.println("no");
  }
  delay(10);
  
  Serial.println("Motors : ");
  if (WITH_MOTORS) {
    Serial.println("yes");
  } else {
    Serial.println("no");
  }
  delay(10);
  
  Serial.println("Midi out : " + WITH_MIDI_OUTPUT);
  if (WITH_MIDI_OUTPUT) {
    Serial.println("yes");
  } else {
    Serial.println("no");
  }
  delay(10);

  for (int sensor = 0; sensor < NUM_SENSORS; sensor++) {
    baseline[sensor] = analogRead(SENSOR_PINS[sensor]);
    jumpThreshold[sensor] = (MIN_THRESHOLD + MAX_THRESHOLD) / 2;
  }

  //write LOW to motors even if WITH_MOTORS is false
  //just to be sure they stay off if they are still plugged in
  if (NUM_MOTORS > 0) {
    pinMode(LED_PIN, OUTPUT);

    for (int motor = 0; motor < NUM_MOTORS; motor++) {
      pinMode(MOTOR_PINS[motor], OUTPUT);
      digitalWrite(MOTOR_PINS[motor], LOW);
    }
  }

  //MIDI INPUT CALLBACKS
  //  usbMIDI.setHandleNoteOn(ExternalNoteOn);
  //  usbMIDI.setHandleNoteOff(ExternalNoteOff);

  if (WITH_MIDI_OUTPUT) {
    //wait to ensure Midi mapper has had time to detect midi input
    delay(3000);

    //Set midi soundfont bank
    usbMIDI.sendControlChange(0, BANK, MIDI_CHANNEL);
    usbMIDI.send_now();

    //Set midi instrument
    usbMIDI.sendProgramChange(PROGRAM, MIDI_CHANNEL);
    usbMIDI.send_now();
  }

  //  randomSeed(analogRead(RANDOM_SEED_PIN));
}

void loop() {
  //*STATIC VARIABLES*

  //set to true after rising() signal
  static bool justJumped[NUM_SENSORS];

  //Sensor values while not jumping
  static int baselineBuffer[NUM_SENSORS][BASELINE_BUFFER_SIZE];
  static int baselineBufferIndex[NUM_SENSORS];

  //number of sustained() signals (minus two) sent for current jump
  //Also incremented when threshold is first traversed
  //and when rising() signal is sent thereafter
  //TODO:change default value for sustainCount to something negative (?) so that it
  //becomes 1 only when the first sustain() signal is sent
  static int sustainCount[NUM_SENSORS];

  //used to delay baseline calculation after coming out of jump and between samples
  static unsigned long toWaitBeforeBaseline[NUM_SENSORS];

  //used to delay midi signals from one another
  static unsigned long toWaitBeforeRising[NUM_SENSORS];
  static unsigned long toWaitBeforeFalling[NUM_SENSORS];
  static unsigned long toWaitBeforeSustaining[NUM_SENSORS];

  //used to calculate time difference in microseconds while waiting
  //lastRisingTime is used for both toWaitBeforeRising and toWaitBeforeFalling
  //since these never overlap
  //TODO: create additional variables to add readability and use them as their name suggests
  //right now the times stored in these isn't the last time the corresponding signal was sent,
  //rather the last time the remaining duration was checked. This is bad.
  static unsigned long lastRisingTime[NUM_SENSORS];
  static unsigned long lastSustainingTime[NUM_SENSORS];
  static unsigned long lastBaselineTime[NUM_SENSORS];
  
  delay(10);

  //for debug
  int toPrint[NUM_SENSORS];
  memset(toPrint, 0, sizeof(toPrint));

  //For MIDI input
  if (usbMIDI.read()) {

    Serial.println(usbMIDI.getType());
    delay(10);

    if (usbMIDI.getType() == usbMIDI.NoteOn) {

      Serial.println("MIDI ON");
      delay(10);
      //
      //      int note = usbMIDI.getData1();
      //      int velocity = usbMIDI.getData2();
      //      int sensorIndex = noteToSensor(note);
      //      if ( sensorIndex != -1) {
      //        rising(sensorIndex, velocity, false);
      //        lastExternalMidiOn[sensorIndex] = micros();
      //    }
    } else if (usbMIDI.getType() == usbMIDI.NoteOff) {

      Serial.println("MIDI OFF");
      delay(10);
      //
      //      int note = usbMIDI.getData1();
      //      int sensorIndex = noteToSensor(note);
      //      if ( sensorIndex != -1) {
      //        falling(sensorIndex, false);
      //        lastExternalMidiOn[sensorIndex] = 0;
      //      }
    }
  }

  //will call sustain for external midi signals that are held
  //turns off motor if held for too long
  //  externalMidiSustains();

  if (READ_RESISTANCE) {
    //For MIDI output and local planck gigger control
    for (int currentSensor = 0; currentSensor < NUM_SENSORS; currentSensor++) {
      int sensorReading = analogRead(SENSOR_PINS[currentSensor]);
      int distanceAboveBaseline = max(0, sensorReading - baseline[currentSensor]);

      if (DEBUG) {
        toPrint[currentSensor] = sensorReading;
      }

      //JUMPING
      if (distanceAboveBaseline >= jumpThreshold[currentSensor]) {
        //VELOCITY OFFSET
        if (sustainCount[currentSensor] == 0) {
          //WAIT
          //waiting is caused by recent falling() signal
          if (toWaitBeforeRising[currentSensor] > 0) {
            updateRemainingTime(toWaitBeforeRising[currentSensor], lastRisingTime[currentSensor]);
          }
          //TRIGGER DELAY
          else {
            lastRisingTime[currentSensor] = micros();
            toWaitBeforeRising[currentSensor] = NOTE_VELOCITY_DELAY;

            //increment sustain count to signify that threshold was crossed
            //this usage of sustainCount is counter intuitive since we haven't actually
            //sent any sustain() signals yet, but it does reduce number of static variables
            sustainCount[currentSensor]++;
          }
        }
        //RISING
        else if (sustainCount[currentSensor] == 1) {
          //WAIT
          //waiting is caused by velocity the velocity offset delay
          if (toWaitBeforeRising[currentSensor] > 0) {
            updateRemainingTime(toWaitBeforeRising[currentSensor], lastRisingTime[currentSensor]);
          }
          //SIGNAL
          else {
            rising(currentSensor, distanceAboveBaseline, true);

            lastRisingTime[currentSensor] = micros();
            toWaitBeforeFalling[currentSensor] = NOTE_ON_DELAY;

            lastSustainingTime[currentSensor] = micros();
            toWaitBeforeSustaining[currentSensor] = SUSTAIN_DELAY;

            justJumped[currentSensor] = true;
            sustainCount[currentSensor]++;
          }
        }
        //SUSTAINING
        else {
          //RESET
          if (sustainCount[currentSensor] > MAX_CONSECUTIVE_SUSTAINS) {
            baseline[currentSensor] = sensorReading;

            //reset counters
            baselineBufferIndex[currentSensor] = 0;
            sustainCount[currentSensor] = 0;
          }
          //WAIT
          else if (toWaitBeforeSustaining[currentSensor] > 0) {
            updateRemainingTime(toWaitBeforeSustaining[currentSensor], lastSustainingTime[currentSensor]);
          }
          //SIGNAL
          else {
            sustained(currentSensor, distanceAboveBaseline, NOTE_VELOCITY_DELAY + ((sustainCount[currentSensor] - 1) * SUSTAIN_DELAY), true);

            lastSustainingTime[currentSensor] = micros();
            toWaitBeforeSustaining[currentSensor] = SUSTAIN_DELAY;
            sustainCount[currentSensor]++;
          }
        }
      }
      //NOT JUMPING
      else {
        //FALLING
        if (justJumped[currentSensor]) {
          //WAIT
          if (toWaitBeforeFalling[currentSensor]) {
            updateRemainingTime(toWaitBeforeFalling[currentSensor], lastRisingTime[currentSensor]);
          }
          //SIGNAL
          else {
            falling(currentSensor, true);

            //wait before sending more midi signals
            //debounces falling edge
            lastRisingTime[currentSensor] = micros();
            toWaitBeforeRising[currentSensor] = NOTE_OFF_DELAY;

            //wait before buffering baseline
            //this is to ignore the sensor "blowback" (erratic readings after jumps)
            //and remove falling edge portion of signal that is below threshold
            lastBaselineTime[currentSensor] = micros();
            toWaitBeforeBaseline[currentSensor] = BASELINE_BLOWBACK_DELAY;

            justJumped[currentSensor] = false;

            //backtrack baseline count to remove jump start
            //(might not do anything if we just updated baseline)
            baselineBufferIndex[currentSensor] = max( 0, baselineBufferIndex[currentSensor] - RETRO_JUMP_BLOWBACK_SAMPLES);

            //reset jump counter
            sustainCount[currentSensor] = 0;
          }
        }
        //BASELINING
        else {
          //reset jump counter
          sustainCount[currentSensor] = 0;

          //RESET
          if (baselineBufferIndex[currentSensor] > (BASELINE_BUFFER_SIZE - 1)) {
            jumpThreshold[currentSensor] = updateThreshold(baselineBuffer[currentSensor], baseline[currentSensor], jumpThreshold[currentSensor]);
            int maxBaseline = MAX_READING - jumpThreshold[currentSensor] - MIN_JUMPING_RANGE;
            baseline[currentSensor] = min(bufferAverage(baselineBuffer[currentSensor], BASELINE_BUFFER_SIZE), maxBaseline);

            //reset counter
            baselineBufferIndex[currentSensor] = 0;
          }
          //WAIT
          else if (toWaitBeforeBaseline[currentSensor] > 0) {
            updateRemainingTime(toWaitBeforeBaseline[currentSensor], lastBaselineTime[currentSensor]);
          }
          //SAMPLE
          else {
            baselineBuffer[currentSensor][baselineBufferIndex[currentSensor]] = sensorReading;
            baselineBufferIndex[currentSensor]++;

            //reset timer
            lastBaselineTime[currentSensor] = micros();
            toWaitBeforeBaseline[currentSensor] = BASELINE_SAMPLE_DELAY;
          }
        }
      }
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
    int toAdd = pow( (a[i] - target), 2);
    if (sum < ULONG_MAX - toAdd) {
      sum += toAdd;
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
    Serial.print(i * MAX_READING);
    Serial.print(" ");
    Serial.print(i * MAX_READING + toPrint[i]);
    Serial.print(" ");
    Serial.print(i * MAX_READING + baseline[i]);
    Serial.print(" ");
    Serial.print(i * MAX_READING + baseline[i] + jumpThreshold[i]);
    Serial.print(" ");
  }
  Serial.print(printSize * MAX_READING + MAX_READING);
  Serial.println();
  delayMicroseconds(PRINT_DELAY);
}

int sensorToMotor(int sensorIndex) {
  if (SENSOR_TO_MOTOR[sensorIndex] == -1) {
    //Turn on LED instead of motor
    return LED_PIN;
  }
  else {
    return MOTOR_PINS[SENSOR_TO_MOTOR[sensorIndex]];
  }
}

//given note number, returns sensor number that normally produces that note
//returns -1 when note is not found
int noteToSensor(int note) {
  for (int i = 0; i < NUM_SENSORS; i++) {
    if (NOTES[i] == note) {
      return i;
    }
  }
  return -1;
}


void rising(int sensor, int velocity, bool isLocal) {
  if (WITH_MOTORS) {
    if (tapsToIgnore[sensor] == 0) {
      tapsToIgnore[sensor] = TAPS_PER_PULSE - 1;
      digitalWrite(sensorToMotor(sensor), HIGH);
      delay(10);
    } else {
      tapsToIgnore[sensor]--;
    }
  }
  if (WITH_MIDI_OUTPUT && isLocal) {
    int maxVelocity = MAX_READING - baseline[sensor];
    int constrainedVelocity = constrain(velocity, jumpThreshold[sensor], maxVelocity);
    int scaledVelocity =  map(constrainedVelocity, jumpThreshold[sensor], maxVelocity, 64, 127);

    usbMIDI.sendNoteOn(NOTES[sensor], scaledVelocity, MIDI_CHANNEL);

    if (IS_CLOCKING_PAD[sensor]) {
      usbMIDI.sendRealTime(usbMIDI.Clock);
      usbMIDI.send_now();
      delay(10);

    }
  }
}

void falling(int sensor, bool isLocal) {
  if (WITH_MOTORS) {
    if ((tapsToIgnore[sensor]) == TAPS_PER_PULSE - 1) {
      digitalWrite(sensorToMotor(sensor), LOW);
      delay(10);
    }
  }

  if (WITH_MIDI_OUTPUT && isLocal) {
    usbMIDI.sendNoteOff(NOTES[sensor], 0, MIDI_CHANNEL);
    usbMIDI.send_now();
    delay(10);
  }
}

void sustained(int sensor, int velocity, unsigned long duration, bool isLocal) {
  if (WITH_MOTORS) {
    if (duration >= MAX_MOTOR_PULSE_DURATION) {
      digitalWrite(sensorToMotor(sensor), LOW);
      delay(10);
    }
  }
  //  if (WITH_MIDI_OUTPUT && isLocal) {
  //    usbMIDI.sendPolyPressure(NOTES[sensor], map(constrain(velocity, jumpThreshold[sensor], 512), jumpThreshold[sensor], 512, 64, 127), MIDI_CHANNEL);
  //    usbMIDI.send_now();
}

//MIDI INPUT CALLBACKS
//void ExternalNoteOn(byte channel, byte note, byte velocity) {
//  Serial.println("1");
//
//  //  rising(0, 64, false);
//
//  //  int sensorIndex = noteToSensor(note);
//  //  if ( sensorIndex != -1) {
//  //    rising(sensorIndex, velocity, false);
//  //    lastExternalMidiOn[sensorIndex] = micros();
//  //  }
//}
//
//void ExternalNoteOff(byte channel, byte note, byte velocity) {
//  Serial.println("0");
//
//  //  falling(0, false);
//
//  //
//  //  int sensorIndex = noteToSensor(note);
//  //  if ( sensorIndex != -1) {
//  //    falling(sensorIndex, false);
//  //    lastExternalMidiOn[sensorIndex] = 0;
//  //  }
//}

void externalMidiSustains() {
  for (int sensorIndex = 0; sensorIndex < NUM_SENSORS; sensorIndex++) {
    if (lastExternalMidiOn[sensorIndex] != 0) {
      unsigned long deltaTime = micros() - lastExternalMidiOn[sensorIndex];
      sustained(sensorIndex, 64, deltaTime, false);
    }
  }
}

