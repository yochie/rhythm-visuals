//CONFIGURATION

//Sensor pins
unsigned const short NUM_SENSORS = 1;
unsigned const short PINS[NUM_SENSORS] = {0};

//Serial communication Hz
unsigned const long BAUD_RATE = 115200;

//Controller clock rate in MHz
//to be used in cycle dependent settings
unsigned const short CLOCK_RATE = 180;

//amount of vals that we average baseline over
unsigned const short BUFFER_SIZE = 512;

//How frequently do we add an element to the baseline buffer.
//Used to average baseline over longer duration without having too many values to process
unsigned const short CYCLES_PER_BASELINE = 1;

//Amount of jump vals used to buffer press velocity. If a button is kept pressed,
//a jump message will be printed every time the buffer is full.
//Avoid making too large as then short signals will be ignored
unsigned const short JUMP_BUFFER_SIZE = 48;

//Difference in value from baseline that qualifies as a press
//MAX_THRESHOLD is used when signal moves around
//MIN_THRESHOLD is used when signal is flat
unsigned const short MAX_THRESHOLD = 50;
unsigned const short MIN_THRESHOLD = 30;

//After this amount of consecutive (and non-varying) jumps is reached,
//the baseline is reset to that jump sequences avg velocity
unsigned const long MAX_CONSECUTIVE_JUMPS = CLOCK_RATE * 500;
unsigned const short CJUMP_BUFFER_SIZE = 1024;
unsigned const long CYCLES_PER_CJUMP = MAX_CONSECUTIVE_JUMPS / CJUMP_BUFFER_SIZE;

//How much a jump can differ from the last to qualify as "consecutive"
//make sure its in the range [0, 1024]
unsigned const short JUMP_VARIABILITY = 128;

//Minimum number of cycles that a jump must last for it to need blowback compensation
//Setting as multiple of JUMP_BUFFER_SIZE so that we know how many values were printed
unsigned const long MIN_JUMPS = 10 * JUMP_BUFFER_SIZE;

//number of cycles after jump during which input is ignored
unsigned const short JUMP_BLOWBACK = 32;

//GLOBAL VARIABLES

//array used to compute baseline while not jumping
unsigned short baselineBuffer[NUM_SENSORS][BUFFER_SIZE];

//baseline iterator: counts the number of loop() executions while not jumping
//this count needs to be divided by CYCLES_PER_BASELINE to get index in buffer
unsigned long baselineCount[NUM_SENSORS];

//small buffer used to signal jumps
//the average of this array is printed every time it becomes full
unsigned short jumpBuffer[NUM_SENSORS][JUMP_BUFFER_SIZE];
unsigned short jumpIndex[NUM_SENSORS];

//this is a larger scale version of the jumpBuffer index
//it is used to reset baseline when MAX_CONSECUTIVE_JUMPS consecutive jumps occur
unsigned short cjumpBuffer[NUM_SENSORS][CJUMP_BUFFER_SIZE];

//number of consecutive jumps in cycles (not all are stored)
unsigned long cJumpCount[NUM_SENSORS];

//number of stored jumps in the cjumpBuffer
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
unsigned short lastVal[NUM_SENSORS];

//current threshold
unsigned short jump_threshold[NUM_SENSORS];

//current pin index
unsigned short currentSensor;

void setup() {
  Serial.begin(BAUD_RATE);      // open the serial port at x bps:

  //initialize global arrays to default values
  memset(baselineBuffer, 0, sizeof(baselineBuffer));
  memset(baselineCount, 0, sizeof(baselineCount));
  memset(jumpBuffer, 0, sizeof(jumpBuffer));
  memset(jumpIndex, 0, sizeof(jumpIndex));
  memset(cjumpBuffer, 0, sizeof(cjumpBuffer));
  memset(cJumpCount, 0, sizeof(cJumpCount));
  memset(cJumpIndex, 0, sizeof(cJumpIndex));
  memset(jumped, false, sizeof(jumped));
  memset(toWait, 0, sizeof(toWait));
  memset(baseline, 0, sizeof(baseline));
  memset(lastVal, 2048, sizeof(lastVal));

  //initialize jump threshold in middle of specified range
  jump_threshold[currentSensor] = (MIN_THRESHOLD + MAX_THRESHOLD) / 2;

  //start polling at first sensor
  currentSensor = 0;

  //establish first baseline using 100 values
  //this baseline will be updated throughout the loop
  for (int i = 0; i < 100; i++) {
    for (int j = 0; j < NUM_SENSORS; j++) {
      baseline[j] += analogRead(PINS[j]);
    }
  }

  for (int j = 0; j < NUM_SENSORS; j++) {
    //set baseline by dividing computed sum
    baseline[j] = baseline[j] / 100;
  }
}

void loop() {
  //If baseline buffer is full, compute its average and reset its counter
  if (baselineCount[currentSensor] > (BUFFER_SIZE - 1) * CYCLES_PER_BASELINE) {

    //adjust threshold to dynamic range of signal
    unsigned short mx = getMax(baselineBuffer);
    unsigned short mn = getMin(baselineBuffer);
    jump_threshold[currentSensor] = min(max(2 * (mx - mn), MIN_THRESHOLD), MAX_THRESHOLD);

    baseline[currentSensor] = computeAverage(baselineBuffer[currentSensor], BUFFER_SIZE);

    baselineCount[currentSensor] = 0;
  }

  //New Val
  unsigned short val = (short) analogRead(PINS[currentSensor]);
  unsigned short jumpVal = val - baseline[currentSensor];

  //JUMPING
  //If jump is large enough, save val to buffer and print average jump if its full.
  //Also makes sure that we don't get stuck in jump by restablishing baseline after some stagnation (MAX_CONSECUTIVE_JUMPS)
  if (jumpVal >= jump_threshold[currentSensor]) {

    //CONSECUTIVE
    //2048 is default value for lastVal, so it will never match on this condition
    //since val is between [0, 1024] and variability should be no larger than 1024
    //ignores first jump signal, but shouldn't really matter as we're calculating average...
    if (abs(lastVal[currentSensor] - val) < min(JUMP_VARIABILITY, 1024)) {
      //RESET BASELINE
      //If we get many consecutive jumps without enough variability, reset baseline.
      if (cJumpIndex[currentSensor] >= CJUMP_BUFFER_SIZE) {

        unsigned short avg = computeAverage(cjumpBuffer[currentSensor], CJUMP_BUFFER_SIZE);

        //raise average a little before resetting baseline to it: early jump vals tend to make
        //the average too low for the pressure by the time it resets, causing constant jumps
        //TODO: add delay to consecutive jump filling so that it ignores first part of any jump
        //That might be enough to remove this "hack"
        baseline[currentSensor] = min(1024, avg * 1.25);

        Serial.println("Consecutive RESET");
        Serial.println(baseline[currentSensor]);

        cJumpCount[currentSensor] = 0;
        cJumpIndex[currentSensor] = 0;
        jumpIndex[currentSensor] = 0;
        lastVal[currentSensor] = 2048;
        jumped[currentSensor] = false;
        baselineCount[currentSensor] = 0;
        return;
      }

      if (cJumpCount[currentSensor] % CYCLES_PER_CJUMP == 0) {
        cjumpBuffer[currentSensor][cJumpIndex[currentSensor]] = val;
        cJumpIndex[currentSensor]++;
      }
      cJumpCount[currentSensor]++;
    }
    //VARYING
    else {
      cJumpCount[currentSensor] = 0;
      cJumpIndex[currentSensor] = 0;
    }

    //PLACE JUMP IN BUFFER
    //If there is place in buffer, add jump there.
    if (jumpIndex[currentSensor] < JUMP_BUFFER_SIZE) {

      //put absolute val (not jumpVal) in buffer
      jumpBuffer[currentSensor][jumpIndex[currentSensor]] = val;
      jumpIndex[currentSensor]++;

      //mark as jump requiring blowback compensation
      if (!jumped[currentSensor] && cJumpCount[currentSensor] > MIN_JUMPS ) {
        jumped[currentSensor] = true;
      }

      //store current val for stagnation check
      lastVal[currentSensor] = val;

      //BUFFER FULL
      //If buffer is full, print buffer average to serial and reset counter
      //This means we send one value every JUMP_BUFFER_SIZE iterations of the
      //main loop if the button is held down. Careful: making JUMP_BUFFER_SIZE too large
      //would cause short presses to be ignored.
      if ( jumpIndex[currentSensor] == JUMP_BUFFER_SIZE) {
        short avgVal = computeAverage(jumpBuffer[currentSensor], jumpIndex[currentSensor]);
        //Serial.print("average from buffer ");
        Serial.print("J");
        Serial.print(currentSensor);
        Serial.print(": ");
        Serial.println(constrain(avgVal - baseline[currentSensor], 0, 1024));

        jumpIndex[currentSensor] = 0;
        lastVal[currentSensor] = val;
      }
    }

  }
  //NOT JUMPING
  //Add value to buffer for baseline update and reset jump counting variables
  else {
    //if last cycle was jump, send 0 val to signify jump is over
    if (jumped[currentSensor]) {
      jumped[currentSensor] = false;
      //Stop computing baseline for a while
      //because sensor values tend to be lower than baseline after releasing the button
      toWait[currentSensor] = JUMP_BLOWBACK;
    }

    if (toWait[currentSensor] == 0) {
      //every x loops, add value to baseline buffer for updating baseline
      if (baselineCount[currentSensor] % CYCLES_PER_BASELINE == 0) {
        baselineBuffer[currentSensor][(unsigned short) (baselineCount[currentSensor] / CYCLES_PER_BASELINE)] = val;
      }
      baselineCount[currentSensor]++;

    } else {
      toWait[currentSensor]--;
    }

    // If using graphing, you might want to use these lines
    Serial.print("J");
    Serial.print(currentSensor);
    Serial.println(": 0");
    delay(1);

    //Using 2048 as default value that will never match the current val when testing for consecutive jumps
    lastVal[currentSensor] = 2048;

    //Reset jump counters
    jumpIndex[currentSensor] = 0;
    cJumpCount[currentSensor] = 0;
    cJumpIndex[currentSensor] = 0;
  }
  //switch to next sensor
  if (currentSensor < NUM_SENSORS - 1) {
    currentSensor++;
  }
  else {
    currentSensor = 0;
  }
}

unsigned short computeAverage(unsigned short a[], long aSize) {
  unsigned long sum = 0;
  for (int i = 0; i < aSize; i++) {
    sum = sum + a[i];
  }
  unsigned short toreturn = (unsigned short) (sum / aSize);

  return toreturn;
}

unsigned short getMax(unsigned short numarray[NUM_SENSORS][BUFFER_SIZE]) {
  unsigned short mx = numarray[0][0];
  for (int i = 0; i < NUM_SENSORS; i++) {
    for (int j = 0; j < BUFFER_SIZE; j++) {
      if (mx < numarray[i][j]) {
        mx = numarray[i][j];
      }
    }
  }
  return mx;
}


unsigned short getMin(unsigned short numarray[NUM_SENSORS][BUFFER_SIZE]) {
  unsigned short mn = numarray[0][0];
  for (int i = 0; i < NUM_SENSORS; i++) {
    for (int j = 0; j < BUFFER_SIZE; j++) {
      if (mn > numarray[i][j]) {
        mn = numarray[i][j];
      }
    }
  }
  return mn;
}

