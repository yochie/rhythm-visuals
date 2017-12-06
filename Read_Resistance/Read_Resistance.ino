const short BUFFER_SIZE = 512; //amount of vals that we average baseline over

//Max amount of jump vals used to average press velocity. If a button is kept pressed,
//a jump message will be printed every time the buffer is full.
//Avoid making too large as then short signals will be ignored
const short JUMP_BUFFER_SIZE = 32;

//Difference in value from threshold that qualifies as a press
short jump_threshold = 40;
short MAX_THRESHOLD = 50;
short MIN_THRESHOLD = 30;

//How much a jump can differ from the last to qualify as "consecutive"
//make sure its in the range [0, 1024]
const short JUMP_VARIABILITY = 1024;
//Minimum number of cycles that a jump must be recorded for it to need blowback compensation
const short MIN_JUMPS = 3;

//Controller clock rate in MHz
const int CLOCK_RATE = 180;

//After this amount of consecutive (and non-varying) jumps is reached,
//the baseline is reset to that jump sequences avg velocity
const int MAX_CONSECUTIVE_JUMPS = 2000;

//How frequently do we add an element to the baseline buffer. Used so that we dont compute baseline so often.
const short CYCLES_PER_BASELINE = 16;

const int BAUD_RATE = 115200;

//number of cycles after jump during which input is ignored
const int JUMP_BLOWBACK = 128;

const int NUM_SENSORS = 1;
const int PINS[NUM_SENSORS] = {0};

int val = 0;
int cnt[NUM_SENSORS];
short baselineBuffer[NUM_SENSORS][BUFFER_SIZE];
short jumpBuffer[NUM_SENSORS][JUMP_BUFFER_SIZE];
int baseline[NUM_SENSORS];
int lastVal[NUM_SENSORS];
int jumpCount[NUM_SENSORS];
int consecutiveJumpCount[NUM_SENSORS];
bool jumped[NUM_SENSORS];
int toWait[NUM_SENSORS];
int currentSensor;

void setup() {
  Serial.begin(BAUD_RATE);      // open the serial port at x bps:

  //initialize global arrays to default values
  memset(cnt, 0, sizeof(cnt));
  memset(baseline, 0, sizeof(baseline));
  memset(lastVal, 2048, sizeof(lastVal));
  memset(jumpCount, 0, sizeof(jumpCount));
  memset(consecutiveJumpCount, 0, sizeof(consecutiveJumpCount));
  memset(jumped, false, sizeof(jumped));
  memset(toWait, 0, sizeof(toWait));

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
  if (cnt[currentSensor] > (BUFFER_SIZE - 1) * CYCLES_PER_BASELINE) {

    short mx = getMax(baselineBuffer);
    short mn = getMin(baselineBuffer);

    jump_threshold = min(max(2*(mx - mn), MIN_THRESHOLD), MAX_THRESHOLD);

    cnt[currentSensor] = 0;
    baseline[currentSensor] = computeAverage(baselineBuffer[currentSensor], BUFFER_SIZE);

    //        Serial.print("Computed new baseline : ");
    //        Serial.println(baseline[currentSensor]);
  }

  //New Val
  val = (short) analogRead(PINS[currentSensor]);
  //Unsure why, but without this line, script will ofter ignore rest of serial prints
  //Serial.println("base : ")
  //Serial.println((String) baseline[currentSensor]);

  short jumpVal = val - baseline[currentSensor];

  //JUMPING
  //If jump is large enough, save val to buffer and print average jump if its full.
  //Also makes sure that we don't get stuck in jump by restablishing baseline after some stagnation (MAX_CONSECUTIVE_JUMPS)
  if (jumpVal >= jump_threshold) {

    //CONSECUTIVE
    //2048 is default value for lastVal, so it will never match on this condition
    //since val is between [0, 1024] and variability should be no larger than 1024
    if (abs(lastVal[currentSensor] - val) < JUMP_VARIABILITY) {
      consecutiveJumpCount[currentSensor]++;

      //Serial.println("Consecutive");
      //Serial.println(consecutiveJumpCount[currentSensor]);

      //RESET BASELINE
      //If we get many consecutive jumps without enough variability, reset baseline.
      if (consecutiveJumpCount[currentSensor] >= MAX_CONSECUTIVE_JUMPS) {
        Serial.println("Consecutive RESET");
        baseline[currentSensor] = computeAverage(jumpBuffer[currentSensor], jumpCount[currentSensor]);
        Serial.println(baseline[currentSensor]);
        consecutiveJumpCount[currentSensor] = 0;
        jumpCount[currentSensor] = 0;
        lastVal[currentSensor] = 2048;
        cnt[currentSensor] = 0;
        return;
      }
    }
    //VARYING
    else {
      consecutiveJumpCount[currentSensor] = 0;
    }

    //PLACE JUMP IN BUFFER
    //If there is place in buffer, add jump there.
    if (jumpCount[currentSensor] < JUMP_BUFFER_SIZE) {

      //put absolute val (not jumpVal) in buffer
      jumpBuffer[currentSensor][jumpCount[currentSensor]] = val;
      jumpCount[currentSensor]++;

      //mark as jump requiring blowback compensation
      if (!jumped[currentSensor] && jumpCount[currentSensor] > MIN_JUMPS ) {
        jumped[currentSensor] = true;
      }

      //store current val for stagnation check
      lastVal[currentSensor] = val;

      //BUFFER FULL
      //If buffer is full, print buffer average to serial and reset counter
      //This means we send one value every JUMP_BUFFER_SIZE iterations of the
      //main loop if the button is held down. Careful: making JUMP_BUFFER_SIZE too large
      //would cause short presses to be ignored.
      if ( jumpCount[currentSensor] == JUMP_BUFFER_SIZE) {
        short avgVal = computeAverage(jumpBuffer[currentSensor], jumpCount[currentSensor]);
        //Serial.print("average from buffer ");
        Serial.print("J");
        Serial.print(currentSensor);
        Serial.print(": ");
        Serial.println(constrain(avgVal - baseline[currentSensor], 0, 1024));

        jumpCount[currentSensor] = 0;
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

      //Reset baseline counter because baseline tends to change after button pressed
      //so we don't want pre-jump values weighing in on new baseline.
      //This resetting might cause problems if controller doesn't have time to
      //recuperate from jump (JUMP_BLOWBACK) and compute a new baseline between
      //two jumps on a single sensor. This means you need at least (JUMP_BLOWBACK + BUFFER_SIZE)*NUM_SENSORS
      //main loop executions (cycles) to occur between two jump signals on a same sensor
      //e.g. with JUMP_BLOWBACK set to 32, BUFFER_SIZE to 64 and NUM_SENSORs to 4, we need
      //(32 + 64) * 4 = 640 main loops between two button presses on ay single sensor
      //cnt[currentSensor] = 0;
    }

    if (toWait[currentSensor] == 0) {
      //every x loops, add value to baseline buffer for updating baseline
      if (cnt[currentSensor] % CYCLES_PER_BASELINE == 0) {
        baselineBuffer[currentSensor][(int) cnt[currentSensor] / CYCLES_PER_BASELINE] = val;
      }
      cnt[currentSensor]++;

    } else {
      toWait[currentSensor]--;
    }

    // If using graphing, you might want to use these lines
    //        Serial.print("J");
    //        Serial.print(currentSensor);
    //        Serial.println(": 0");

    //Using 2048 as default value that will never match the current val when testing for consecutive jumps
    lastVal[currentSensor] = 2048;

    //Reset jump counters
    jumpCount[currentSensor] = 0;
    consecutiveJumpCount[currentSensor] = 0;
  }
  //switch to next sensor
  if (currentSensor < NUM_SENSORS - 1) {
    currentSensor++;
  }
  else {
    currentSensor = 0;
  }
}

short computeAverage(short a[], int aSize) {
  long sum = 0;
  for (int i = 0; i < aSize; i++) {
    sum = sum + a[i];
  }
  short toreturn = (short) (sum / aSize);

  return toreturn;
}

short getMax(short numarray[NUM_SENSORS][BUFFER_SIZE]) {
  short mx = numarray[0][0];
  for (int i = 0; i < NUM_SENSORS; i++) {
    for (int j = 0; j < BUFFER_SIZE; j++) {
      if (mx < numarray[i][j]) {
        mx = numarray[i][j];
      }
    }
  }
  return mx;
}


short getMin(short numarray[NUM_SENSORS][BUFFER_SIZE]) {
  short mn = numarray[0][0];
  for (int i = 0; i < NUM_SENSORS; i++) {
    for (int j = 0; j < BUFFER_SIZE; j++) {
      if (mn > numarray[i][j]) {
        mn = numarray[i][j];
      }
    }
  }
  return mn;
}

