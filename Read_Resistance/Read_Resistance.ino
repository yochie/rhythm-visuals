//CONFIGURATION

//Sensor pins
//At least one plz...
unsigned const short NUM_SENSORS = 4;
unsigned const short PINS[NUM_SENSORS] = {0, 1, 2, 3};

//Serial communication Hz
unsigned const long BAUD_RATE = 115200;

//Controller clock rate in MHz
//to be used in cycle dependent settings
unsigned const short CLOCK_RATE = 180;

//Maximum value returned by AnalogRead()
//Always 1024 for arduino, so this shouldn't change...
unsigned const short MAX_READING = 1024;

//amount of sensorReadings that we average baseline over
unsigned const short BASELINE_BUFFER_SIZE = 256;

//Amount of jump vals used to buffer press velocity. If a button is kept pressed,
//a jump message will be printed every time the buffer is full.
//Avoid making too large as then short signals will be ignored
unsigned const short JUMP_BUFFER_SIZE = 64;

//Difference in value from baseline that qualifies as a press
//MAX_THRESHOLD is used when signal moves around
//MIN_THRESHOLD is used when signal is flat
unsigned const short MAX_THRESHOLD = 75;
unsigned const short MIN_THRESHOLD = 40;

//After this amount of consecutive (and non-varying) jumps is reached,
//the baseline is reset to that jump sequences avg velocity
unsigned const long MAX_CONSECUTIVE_JUMPS = CLOCK_RATE * 10;

//How many consecutive jumps we average over when resetting
unsigned const short CJUMP_BUFFER_SIZE = 512;

//How often we should store consecutive jump values to the cJumpBuffer
//This is computed automatically and should not be modified manually
unsigned const long CYCLES_PER_CJUMP = MAX_CONSECUTIVE_JUMPS / CJUMP_BUFFER_SIZE;

//How much a jump can differ from the last to qualify as "consecutive"
//make sure its in the range [0, MAX_READING]
unsigned const short CJUMP_VARIATION_TOLERANCE = 128;

//Minimum number of consecutive jumps recorded for jump to need blowback compensation
//Note we are refering to *recorded* consecutive jumps, not cycles.
//ie the condition is based on cJumpIndex value
unsigned const short MIN_JUMPS_FOR_BLOWBACK = 5;

//number of loop() cycles after jump during which input is ignored
unsigned const short JUMP_BLOWBACK_DURATION = 8;

//GLOBAL VARIABLES

//array used to compute baseline while not jumping
unsigned short baselineBuffer[NUM_SENSORS][BASELINE_BUFFER_SIZE];

//baseline iterator: counts the number of loop() executions while not jumping
unsigned long baselineCount[NUM_SENSORS];

//this is a buffer containing previous consecutive jumps for each sensor
//it is used to reset baseline when MAX_CONSECUTIVE_JUMPS consecutive jumps occur
//ie when we get stuck in a jump
unsigned short cJumpBuffer[NUM_SENSORS][CJUMP_BUFFER_SIZE];

//number of consecutive jumps in cycles (not all are stored)
unsigned long cJumpCount[NUM_SENSORS];

//number of stored jumps in the cJumpBuffer
unsigned short cJumpIndex[NUM_SENSORS];

//flag indicating that a sensor had just jumped
//used to initiate blowback waiting phase
bool jumped[NUM_SENSORS];

//number of cycles left to recuperate from blowback
//(erratic/low values after pressing sensor)
unsigned short toWait[NUM_SENSORS];

//holds current baseline for each pin
unsigned short baseline[NUM_SENSORS];

//last read value for each pin
unsigned short lastSensorReading[NUM_SENSORS];

//current threshold
unsigned short jump_threshold[NUM_SENSORS];

void setup() {
  Serial.begin(BAUD_RATE);      // open the serial port at x bps:

  //initialize global arrays to default values
  memset(baselineBuffer, 0, sizeof(baselineBuffer));
  memset(baselineCount, 0, sizeof(baselineCount));
  memset(cJumpBuffer, 0, sizeof(cJumpBuffer));
  memset(cJumpCount, 0, sizeof(cJumpCount));
  memset(cJumpIndex, 0, sizeof(cJumpIndex));
  memset(jumped, false, sizeof(jumped));
  memset(toWait, 0, sizeof(toWait));
  memset(baseline, MAX_READING, sizeof(baseline));
  memset(lastSensorReading, 2048, sizeof(lastSensorReading));
  memset(jump_threshold, (MIN_THRESHOLD + MAX_THRESHOLD / 2), sizeof(jump_threshold));
}

void loop() {
  //small buffer used to signal jumps
  //the average of this array for each sensor is printed at every iteration of loop()
  unsigned short jumpBuffer[NUM_SENSORS][JUMP_BUFFER_SIZE];
  memset(jumpBuffer, 0, sizeof(jumpBuffer));

  //fill buffer
  for (unsigned short jumpIndex = 0; jumpIndex < JUMP_BUFFER_SIZE; jumpIndex++) {
    for (unsigned short currentSensor = 0; currentSensor < NUM_SENSORS; currentSensor++) {
      unsigned short sensorReading = (unsigned short) analogRead(PINS[currentSensor]);
      jumpBuffer[currentSensor][jumpIndex] = sensorReading;
    }
  }

  short toPrint[NUM_SENSORS];
  memset(toPrint, 0, sizeof(toPrint));

  //compute buffer content
  for (unsigned short currentSensor = 0; currentSensor < NUM_SENSORS; currentSensor++) {

    //compute buffer averages
    unsigned short sensorReadingAvg = (unsigned short) computeAverage(jumpBuffer[currentSensor], JUMP_BUFFER_SIZE);
    unsigned short distanceFromBaseline = max(0, sensorReadingAvg - baseline[currentSensor]);

    //JUMPING
    //If jump is large enough, add it to toPrint
    //Also makes sure that we don't get stuck in jump by restablishing baseline after some stagnation (MAX_CONSECUTIVE_JUMPS)
    if (distanceFromBaseline >= jump_threshold[currentSensor]) {

      //CONSECUTIVE
      //2048 is default value for lastSensorReading, so it will never match on this condition
      //since sensorReading is between [0, MAX_READING] and variability should be no larger than MAX_READING
      //Setting CJUMP_VARIATION_TOLERANCE to MAX_READING effectively ignores any variability in consecutive jumps
      if (abs(lastSensorReading[currentSensor] - sensorReadingAvg) < min(CJUMP_VARIATION_TOLERANCE, MAX_READING)) {

        //RESET BASELINE
        //If we get many consecutive jumps without enough variability, reset baseline.
        if (cJumpIndex[currentSensor] >= CJUMP_BUFFER_SIZE) {

          unsigned short avg = computeAverage(cJumpBuffer[currentSensor], CJUMP_BUFFER_SIZE);

          //raise average a little before resetting baseline to it: early jump vals tend to make
          //the average too low for the pressure by the time it resets, causing constant jumps
          //TODO: add delay to consecutive jump buffer filling so that it ignores first part of any jump
          //That might be enough to remove this "hack"
          baseline[currentSensor] = min(MAX_READING, avg * 1.25);
          //          Serial.println("Consecutive RESET");
          //          Serial.println(baseline[currentSensor]);

          cJumpCount[currentSensor] = 0;
          cJumpIndex[currentSensor] = 0;
          lastSensorReading[currentSensor] = 2048;
          baselineCount[currentSensor] = 0;
        }

        //saves a jump every CYCLES_PER_CJUMP to compute the average in case we need to reset baseline
        if (cJumpCount[currentSensor] % CYCLES_PER_CJUMP == 0) {
          cJumpBuffer[currentSensor][cJumpIndex[currentSensor]] = sensorReadingAvg;
          cJumpIndex[currentSensor]++;
        }
        cJumpCount[currentSensor]++;

        //mark as jump requiring blowback compensation if long enough
        if (!jumped[currentSensor] && cJumpIndex[currentSensor] > MIN_JUMPS_FOR_BLOWBACK ) {
          jumped[currentSensor] = true;
        }
      }
      //VARYING
      else {
        cJumpCount[currentSensor] = 0;
        cJumpIndex[currentSensor] = 0;
      }

      //store current sensorReading for stagnation check
      lastSensorReading[currentSensor] = sensorReadingAvg;

      //add jump value to the serial printout
      toPrint[currentSensor] = constrain(distanceFromBaseline, 0, MAX_READING);
    }

    //NOT JUMPING
    else {
      //if we just came out of a jump, wait a little before sampling baseline
      if (jumped[currentSensor]) {
        jumped[currentSensor] = false;
        //Stop computing baseline for a while
        //because sensor values tend to be lower than baseline after releasing the button
        toWait[currentSensor] = JUMP_BLOWBACK_DURATION;
      }
      //If baseline buffer is full, compute its average and reset its counter
      else if (baselineCount[currentSensor] > (BASELINE_BUFFER_SIZE - 1)) {
        //adjust threshold to dynamic range of signal
        unsigned short mx = getMax(baselineBuffer);
        unsigned short mn = getMin(baselineBuffer);
        jump_threshold[currentSensor] = min(max(2 * (mx - mn), MIN_THRESHOLD), MAX_THRESHOLD);

        baseline[currentSensor] = computeAverage(baselineBuffer[currentSensor], BASELINE_BUFFER_SIZE);

        baselineCount[currentSensor] = 0;
      }
      //If we're still waiting for blowback, skip this sample
      else if (toWait[currentSensor] > 0) {
        toWait[currentSensor]--;
      }
      //Otherwise we can add average reading to baseline buffer
      else {
        //add value to baseline buffer for updating baseline
        baselineBuffer[currentSensor][baselineCount[currentSensor]] = sensorReadingAvg;
        baselineCount[currentSensor]++;

      }

      //resets to default
      //Using 2048 as default value that will never match the current sensorReading when testing for consecutive jumps
      lastSensorReading[currentSensor] = 2048;

      //Reset consecutive jump counters
      cJumpCount[currentSensor] = 0;
      cJumpIndex[currentSensor] = 0;
    }
  }

  //print results for all sensors in Arduino Plotter format
  for (int i = 0; i < sizeof(toPrint) / sizeof(short); i++) {
    Serial.print(toPrint[i]);
    Serial.print(" ");
  }
  Serial.println();
  //delay(1);
}

unsigned short computeAverage(unsigned short a[], unsigned long aSize) {
  unsigned long sum = 0;
  for (int i = 0; i < aSize; i++) {
    sum = sum + a[i];
  }
  unsigned short toreturn = (unsigned short) (sum / aSize);

  return toreturn;
}

unsigned short getMax(unsigned short numarray[NUM_SENSORS][BASELINE_BUFFER_SIZE]) {
  unsigned short mx = numarray[0][0];
  for (int i = 0; i < NUM_SENSORS; i++) {
    for (int j = 0; j < BASELINE_BUFFER_SIZE; j++) {
      if (mx < numarray[i][j]) {
        mx = numarray[i][j];
      }
    }
  }
  return mx;
}


unsigned short getMin(unsigned short numarray[NUM_SENSORS][BASELINE_BUFFER_SIZE]) {
  unsigned short mn = numarray[0][0];
  for (int i = 0; i < NUM_SENSORS; i++) {
    for (int j = 0; j < BASELINE_BUFFER_SIZE; j++) {
      if (mn > numarray[i][j]) {
        mn = numarray[i][j];
      }
    }
  }
  return mn;
}

