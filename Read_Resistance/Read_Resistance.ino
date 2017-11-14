const int potPin1 = 0;    // select the input pin for the potentiometer
//int potPin2 = 2;    // select the input pin for the potentiometer
//int potPin3 = 3;    // select the input pin for the potentiometer
//int potPin4 = 4;    // select the input pin for the potentiometer

const short BUFFER_SIZE = 512; //amount of vals that we average baseline over

//Max amount of jump vals used to average press velocity. If a button is kept pressed,
//a jump message will be printed every time the buffer is full.
//Avoid making too large as then jump messages would'nt be printed often enough
const short JUMP_BUFFER_SIZE = 150;

//Difference in value that qualifies as a press
const short JUMP_THRESHOLD = 50;

//How much a jump can differ from the last to qualify as consecutive
//make sure its no larger than 1024...
const short JUMP_VARIABILITY = 100;

//Controller clock rate in MHz
const int CLOCK_RATE = 180;

//After this amount of consecutive (and similar) jumps is reached,
//the baseline is reset to that jump sequences avg velocity
const int MAX_CONSECUTIVE_JUMPS = ((CLOCK_RATE * 1000000) / 200) * 4;

//How frequently do we add an element to the baseline buffer. Used so that we dont compute baseline so often.
const short CYCLES_PER_BASELINE = 1;

const int BAUD_RATE = 115200;

const int JUMP_BLOWBACK = 100;


int val = 0;
int cnt = 0;
short baselineBuffer[BUFFER_SIZE];
short jumpBuffer[JUMP_BUFFER_SIZE];
int baseline = 0;
int lastVal = 2048;    //Using 2048 as default value that will never match the current val when testing for consecutive jumps
int jumpCount = 0;
int consecutiveJumpCount = 0;
int toWait = 0;


void setup() {
  Serial.begin(BAUD_RATE);      // open the serial port at x bps:

  //establish first baseline using 100 (arbitrary) values
  //this baseline will be updated throughout the loop
  for (int i = 0; i < 100; i++) {
    baseline += analogRead(potPin1);
  }
  baseline = baseline / 100;
}

void loop() {
  //If baseline buffer is full, compute its average and reset its counter
  if (cnt > (BUFFER_SIZE - 1) * CYCLES_PER_BASELINE) {
    cnt = 0;
    baseline = computeAverage(baselineBuffer, BUFFER_SIZE);
    //        Serial.print("Computed new baseline : ");
    //        Serial.println(baseline);
  }

  //New Val
  val = (short) analogRead(potPin1);
  //  Serial.println("val : " + (String) val);
  //  Serial.println("base : " + (String) baseline);


  short jumpVal = val - baseline;
  //  Serial.println("val : " + (String) val);
  //  Serial.println("base : " + (String) baseline);
  //  Serial.println("jumpval : " + (String) jumpVal);



  //JUMPING
  //If jump is large enough, save val to buffer and print average jump if its full.
  //Also makes sure that we don't get stuck in jump by restablishing baseline after some stagnation
  if (jumpVal >= JUMP_THRESHOLD) {
    //        Serial.println("JUMP !!!!!!!!!!! val : " + (String) val);
    //        Serial.println("base : " + (String) baseline);

    //CONSECUTIVE
    //If we get many consecutive jumps without much variability, reset baseline.
    //2048 is default value for lastVal, so it will never match on this condition
    //since val is between [0, 1024] and variability should be no larger than 1024
    if (abs(lastVal - val) < JUMP_VARIABILITY) {
      consecutiveJumpCount++;
      //   Serial.println("Consecutive");
      //      Serial.println(consecutiveJumpCount);

      //RESET BASELINE
      if (consecutiveJumpCount >= MAX_CONSECUTIVE_JUMPS) {
        Serial.println("Consecutive RESET");
        baseline = computeAverage(jumpBuffer, jumpCount);
        Serial.println(baseline);
        consecutiveJumpCount = 0;
        jumpCount = 0;
        lastVal = 2048;
        cnt = 0;
        return;
      }
    }
    else {
      consecutiveJumpCount = 0;
    }

    //PLACE IN BUFFER
    //If there is place in buffer, add jump there.
    if (jumpCount < JUMP_BUFFER_SIZE) {
      //      Serial.println("Adding to buffer at position: ");
      //      Serial.println(jumpCount);
      //put absolute val (not jumpVal) in buffer
      jumpBuffer[jumpCount] = val;
      jumpCount++;

      //store current val for stagnation check
      lastVal = val;
    }
    //BUFFER FULL
    //If buffer is full, print buffer average to serial and reset counter
    //This means we send one value every JUMP_BUFFER_SIZE iterations of the
    //main loop if the button is held down. Making JUMP_BUFFER_SIZE too large would
    //thus cause timing issues here.
    else {
      short avgVal = computeAverage(jumpBuffer, jumpCount);
      Serial.print("J: ");
      Serial.println(constrain(avgVal - baseline, 0, 1024));
      jumpCount = 0;
      lastVal = val;
    }
    //Serial.print("jumps : ");
    //Serial.println(jumpCount);

  }
  //NOT JUMPING
  //Add value to buffer for baseline update and reset jump counting variables
  else {
    //if last cycle was jump, we should send the remaining jump data to the serial
    //Only printing previous jump if it laster more than x cycles to avoid noise
    //This means we're assuming a reasonable clock speed (for  0.01 ms duration signal to be detected, assuming 100 ticks per loop() (ie sample), 20 MHz clock is required)
    if (lastVal != 2048 && jumpCount > 1) {
      //      short avgVal = computeAverage(jumpBuffer, jumpCount);
      //      Serial.print("J: ");
      //      Serial.println(constrain(avgVal - baseline, 0, 512));
      Serial.println("J: 0");

      //reset baseline after waiting a litlle
      toWait = JUMP_BLOWBACK;
      cnt = 0;
    }

    if (toWait == 0) {
      //every x loops, add value to baseline buffer for updating baseline
      if (cnt % CYCLES_PER_BASELINE == 0) {
        baselineBuffer[(int) cnt / CYCLES_PER_BASELINE] = val;
      }
      //every 200 cyles, print baseline
      if (cnt % 20000 == 0) {
        //Signals baseline, usedful for graphing in arduino serial grapher
        Serial.println("J: 0");
      }
      cnt++;
    } else {
      toWait--;
    }
    //Using 2048 as default value that will never match the current val when testing for consecutive jumps
    lastVal = 2048;

    //Reset jump counters
    jumpCount = 0;
    consecutiveJumpCount = 0;
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

