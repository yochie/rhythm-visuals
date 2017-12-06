const short BUFFER_SIZE = 128; //amount of vals that we average baseline over

//Max amount of jump vals used to average press velocity. If a button is kept pressed,
//a jump message will be printed every time the buffer is full.
//Avoid making too large as then jump messages would'nt be printed often enough
const short JUMP_BUFFER_SIZE = 40;

//Difference in value that qualifies as a press
const short JUMP_THRESHOLD = 50;

//How much a jump can differ from the last to qualify as "consecutive"
//make sure its in the range [0, 1024]
const short JUMP_VARIABILITY = 1024;

//Controller clock rate in MHz
const int CLOCK_RATE = 180;

//After this amount of consecutive (and similar) jumps is reached,
//the baseline is reset to that jump sequences avg velocity
const int MAX_CONSECUTIVE_JUMPS = ((CLOCK_RATE * 1000000) / 200) * 4;

//How frequently do we add an element to the baseline buffer. Used so that we dont compute baseline so often.
const short CYCLES_PER_BASELINE = 1;

const int BAUD_RATE = 115200;

//number of cycles after jump during which input is ignored
const int JUMP_BLOWBACK = 25;

const int NUM_SENSORS = 4;

const int PINS[NUM_SENSORS] = {0, 1, 2, 3};

int val = 0;
int cnt[NUM_SENSORS];
short baselineBuffer[NUM_SENSORS][BUFFER_SIZE];
short jumpBuffer[NUM_SENSORS][JUMP_BUFFER_SIZE];
int baseline[NUM_SENSORS];
int lastVal[NUM_SENSORS];    //Using 2048 as default value that will never match the current val when testing for consecutive jumps
int jumpCount[NUM_SENSORS];
int consecutiveJumpCount[NUM_SENSORS];
int toWait[NUM_SENSORS];
int currentSensor;


void setup() {
  Serial.begin(BAUD_RATE);      // open the serial port at x bps:

  memset(cnt, 0, sizeof(cnt));
  memset(baseline, 0, sizeof(baseline));
  memset(lastVal, 0, sizeof(lastVal));
  memset(jumpCount, 0, sizeof(jumpCount));
  memset(consecutiveJumpCount, 0, sizeof(consecutiveJumpCount));
  memset(toWait, 0, sizeof(toWait));

  //establish first baseline using 100 values
  //this baseline will be updated throughout the loop
  for (int i = 0; i < 100; i++) {
    for (int j = 0; j < NUM_SENSORS; j++) {
      baseline[j] += analogRead(PINS[j]);
    }
  }
  for (int j = 0; j < NUM_SENSORS; j++) {
    baseline[j] = baseline[j] / 100;
  }
}

void loop() {
  //If baseline buffer is full, compute its average and reset its counter
  if (cnt[currentSensor] > (BUFFER_SIZE - 1) * CYCLES_PER_BASELINE) {
    cnt[currentSensor] = 0;
    baseline[currentSensor] = computeAverage(baselineBuffer[currentSensor], BUFFER_SIZE);
    //        Serial.print("Computed new baseline : ");
    //        Serial.println(baseline[currentSensor]);
  }

  //New Val
  val = (short) analogRead(PINS[currentSensor]);
  //  Serial.println("val : " + (String) val[currentSensor]);
  //  Serial.println("base : " + (String) baseline[currentSensor]);


  short jumpVal = val - baseline[currentSensor];
  //  Serial.println("val : " + (String) val);
  //  Serial.println("base : " + (String) baseline[currentSensor]);
  //  Serial.println("jumpval : " + (String) jumpVal);



  //JUMPING
  //If jump is large enough, save val to buffer and print average jump if its full.
  //Also makes sure that we don't get stuck in jump by restablishing baseline after some stagnation
  if (jumpVal >= JUMP_THRESHOLD) {
    //        Serial.println("JUMP !!!!!!!!!!! val : " + (String) val);
    //        Serial.println("base : " + (String) baseline[currentSensor]);

    //CONSECUTIVE
    //If we get many consecutive jumps without much variability, reset baseline.
    //2048 is default value for lastVal, so it will never match on this condition
    //since val is between [0, 1024] and variability should be no larger than 1024
    if (abs(lastVal[currentSensor] - val) < JUMP_VARIABILITY) {
      consecutiveJumpCount[currentSensor]++;
      //   Serial.println("Consecutive");
      //      Serial.println(consecutiveJumpCount[currentSensor]);

      //RESET BASELINE
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
    else {
      consecutiveJumpCount[currentSensor] = 0;
    }

    //PLACE IN BUFFER
    //If there is place in buffer, add jump there.
    if (jumpCount[currentSensor] < JUMP_BUFFER_SIZE) {
      //      Serial.println("Adding to buffer at position: ");
      //      Serial.println(jumpCount[currentSensor]);
      //put absolute val (not jumpVal) in buffer
      jumpBuffer[currentSensor][jumpCount[currentSensor]] = val;
      jumpCount[currentSensor]++;

      //store current val for stagnation check
      lastVal[currentSensor] = val;
    }
    //BUFFER FULL
    //If buffer is full, print buffer average to serial and reset counter
    //This means we send one value every JUMP_BUFFER_SIZE iterations of the
    //main loop if the button is held down. Making JUMP_BUFFER_SIZE too large would
    //thus cause timing issues here.
    else {
      short avgVal = computeAverage(jumpBuffer[currentSensor], jumpCount[currentSensor]);
      Serial.print("J: ");
      Serial.println(constrain(avgVal - baseline[currentSensor], 0, 1024));
      jumpCount[currentSensor] = 0;
      lastVal[currentSensor] = val;
    }
    //Serial.print("jumps : ");
    //Serial.println(jumpCount[currentSensor]);

  }
  //NOT JUMPING
  //Add value to buffer for baseline update and reset jump counting variables
  else {
    //if last cycle was jump, we should send the remaining jump data to the serial
    //Only printing previous jump if it laster more than x cycles to avoid noise
    //This means we're assuming a reasonable clock speed (for  0.01 ms duration signal to be detected, assuming 100 ticks per loop() (ie sample), 20 MHz clock is required)
    if (lastVal[currentSensor] != 2048 && jumpCount[currentSensor] > 1) {
      //      short avgVal = computeAverage(jumpBuffer[currentSensor], jumpCount[currentSensor]);
      //      Serial.print("J: ");
      //      Serial.println(constrain(avgVal - baseline[currentSensor], 0, 512));
      Serial.println("J: 0");

      //reset baseline after waiting a litlle
      toWait[currentSensor] = JUMP_BLOWBACK;
      cnt[currentSensor] = 0;
    }

    if (toWait[currentSensor] == 0) {
      //every x loops, add value to baseline buffer for updating baseline
      if (cnt[currentSensor] % CYCLES_PER_BASELINE == 0) {
        baselineBuffer[currentSensor][(int) cnt[currentSensor] / CYCLES_PER_BASELINE] = val;
      }
      //every 200 cyles, print baseline
      if (cnt[currentSensor] % 20000 == 0) {
        //Signals baseline, usedful for graphing in arduino serial grapher
        Serial.println("J: 0");
      }
      cnt[currentSensor]++;
    } else {
      toWait[currentSensor]--;
    }
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

