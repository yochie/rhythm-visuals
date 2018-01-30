#include <limits.h>

//*CONFIGURATION CONSTANTS*

//Sensor pins
//At least one plz...
const int NUM_SENSORS = 1;
const int SENSOR_PINS[NUM_SENSORS] = {1};

const int NUM_MOTORS = 1;
const int MOTOR_PINS[NUM_MOTORS] = {13};

const boolean DEBUG = true;

//the note corresponding to each sensor
const int NOTES[NUM_SENSORS] = {60};

const int MIDI_CHANNEL = 0;

//MAX_THRESHOLD is used when the baseline is very unstable
const int MAX_THRESHOLD = 150;

//MIN_THRESHOLD is used when the baseline is very stable
const int MIN_THRESHOLD = 150;

//duration in microseconds after sending corresponding midi messages
//for which no more signals are sent for that sensor
//Filters out the noise when going across threshold and limits number of
//aftertouch messages sent
unsigned const long NOTE_ON_DELAY = 100000;
unsigned const long NOTE_OFF_DELAY = 100000;
unsigned const long AFTERTOUCH_DELAY = 20000;

//Delay in microseconds for printing
//Prevents overloading serial communications
const int PRINT_DELAY = 50;

//number of microseconds after jump during which baseline update is paused
//this delay occurs after the NOTE_OFF delay, but only avoids baseline buffering, not jumping
unsigned const long BASELINE_BLOWBACK_DELAY = 0;

//used in cycle dependent settings so that performance
//remains (vaguely) similar across different clocks
const int CLOCK_RATE = 180;

//Used to scale parameters based on configuration
//Will grow with clock speed and shrink with number of sensors to sample
const float SCALE_FACTOR = (float) CLOCK_RATE / NUM_SENSORS;

//amount of sensorReadings that we average baseline over
const int BASELINE_BUFFER_SIZE = 64 * SCALE_FACTOR;

//to avoid sending signals for noise spikes, will add latency
//similar to what JUMP_BUFFER_SIZE does, but it is even more restrictive because
//short spikes are guaranteed to not send midi messages, no matter how high they go
const int MIN_JUMPS_FOR_SIGNAL = max((0.2 * SCALE_FACTOR), 1);

//After this amount of consecutive jumps is reached,
//the baseline is reset to that jump sequences avg velocity
const int MAX_CONSECUTIVE_JUMPS = 2 * SCALE_FACTOR;

//number of values removed from baseline buffer when jump is over
//this is used to prevent jump beginning from weighing in on baseline
//making too large would prevent baseline update while fast-tapping
const int RETRO_JUMP_BLOWBACK_CYCLES = 0.1 * SCALE_FACTOR;

//*SYSTEM CONSTANTS*
//these shouldn't have to be modified

//Serial communication Hz
const int BAUD_RATE = 115200;

//Maximum value returned by AnalogRead()
//Always 1024 for arduino
const int MAX_READING = 1023;

//*GLOBAL VARIABLES*
//would love to make them static and local to loop(), but they need to be initialized to non-zero values
//std::vector allows non-zero initialization, but I'm not sure I should include it just for this purpose...

//current baseline for each pin
int baseline[NUM_SENSORS];

//current threshold
int jumpThreshold[NUM_SENSORS];

void setup() {
  Serial.begin(BAUD_RATE);

  for (int motor = 0; motor < NUM_MOTORS; motor++) {
    pinMode(MOTOR_PINS[motor], OUTPUT);
  }

  memset(baseline, MAX_READING, sizeof(baseline));
  memset(jumpThreshold, (MIN_THRESHOLD + MAX_THRESHOLD / 2), sizeof(jumpThreshold));
}

void loop() {
  //*STATIC VARIABLES*

  //used to initiate blowback waiting
  //set to true after MIN_JUMPS_FOR_SIGNAL consecutive jumps
  static bool justJumped[NUM_SENSORS];

  //used to average the baseline
  //filled with the average value computed at each loop() for each sensor
  static int baselineBuffer[NUM_SENSORS][BASELINE_BUFFER_SIZE];

  //counts the number of loop() executions without jumps
  //used to add values in the baselineBuffer
  static int baselineCount[NUM_SENSORS];

  //number of consecutive jumps
  static int consecutiveJumpCount[NUM_SENSORS];

  //used to delay baseline calculation after coming out of jump
  static unsigned long toWaitForBaseline[NUM_SENSORS];

  //used to delay midi signals from one another
  static unsigned long toWaitBeforeSignal[NUM_SENSORS];

  //used to compute delays in microseconds while waiting
  static unsigned long lastTime[NUM_SENSORS];

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
        updateRemainingTime(toWaitBeforeSignal[currentSensor], lastTime[currentSensor]);
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
        if (consecutiveJumpCount[currentSensor] == MIN_JUMPS_FOR_SIGNAL) {
          digitalWrite(sensorToMotor(currentSensor), HIGH);
          toWaitBeforeSignal[currentSensor] = NOTE_ON_DELAY;
          justJumped[currentSensor] = true;
        }
      }
    }
    //BASELINING
    else {
      //WAIT FOR SIGNAL
      if (toWaitBeforeSignal[currentSensor] > 0) {
        updateRemainingTime(toWaitBeforeSignal[currentSensor], lastTime[currentSensor]);
      }
      //NOTE_OFF
      else if (justJumped[currentSensor]) {
        digitalWrite(sensorToMotor(currentSensor), LOW);

        justJumped[currentSensor] = false;

        //backtrack baseline count to remove jump start
        baselineCount[currentSensor] = max( 0, baselineCount[currentSensor] - RETRO_JUMP_BLOWBACK_CYCLES);

        //wait before sending more midi signals
        toWaitBeforeSignal[currentSensor] = NOTE_OFF_DELAY;

        //after waiting for midi, add an extra delay before buffering baseline
        //this is to ignore the sensor "blowback" (low readings) after jumps
        toWaitForBaseline[currentSensor] = BASELINE_BLOWBACK_DELAY;

        //reset counters
        consecutiveJumpCount[currentSensor] = 0;
      }
      //WAIT FOR BASELINING
      else if (toWaitForBaseline[currentSensor] > 0) {
        updateRemainingTime(toWaitForBaseline[currentSensor], lastTime[currentSensor]);

        //reset counters
        consecutiveJumpCount[currentSensor] = 0;
      }
      //RESET BASELINE AND THRESHOLD
      else if (baselineCount[currentSensor] > (BASELINE_BUFFER_SIZE - 1)) {
        jumpThreshold[currentSensor] = updateThreshold(baselineBuffer[currentSensor], baseline[currentSensor], jumpThreshold[currentSensor]);
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

int bufferAverage(int * a, unsigned long aSize) {
  unsigned long sum = 0;
  for (unsigned long i = 0; i < aSize; i++) {
    //makes sure we dont bust when filling up sum
    if (sum < (ULONG_MAX - a[i])) {
      sum = sum + a[i];
    }
    else {
      Serial.println("WARNING: Exceeded ULONG_MAX while running bufferAverage(). Check your parameters to ensure buffers aren't too large.");
      delay(3000);
      return INT_MAX;
    }
  }
  return (int) (sum / aSize);
}

int varianceFromTarget(int * a, unsigned long aSize, int target) {
  unsigned long sum = 0;
  for (unsigned long i = 0; i < aSize; i++) {
    //makes sure we dont bust when filling up sum
    if (sum < ULONG_MAX - a[i]) {
      sum += pow( (a[i] - target), 2);
    }
    else {
      Serial.println("WARNING: Exceeded ULONG_MAX while running varianceFromTarget(). Check your parameters to ensure buffers aren't too large.");
      delay(3000);
      return INT_MAX;
    }
  }
  return pow((sum / aSize), 1);
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
  }
  Serial.println();
  delayMicroseconds(PRINT_DELAY);
}

int sensorToMotor(int sensorPin) {
  return MOTOR_PINS[0];
}

