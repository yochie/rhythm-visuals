const int potPin1 = 1;    // select the input pin for the potentiometer
//int potPin2 = 2;    // select the input pin for the potentiometer
//int potPin3 = 3;    // select the input pin for the potentiometer
//int potPin4 = 4;    // select the input pin for the potentiometer

const short BUFFER_SIZE = 256; //amount of vals that we average baseline over

//Max amount of jump vals used to average press velocity. If a button is kept pressed,
//a jump message will be printed every time the buffer is full.
//Avoid making too large as then jump messages would'nt be printed often enough
const short JUMP_BUFFER_SIZE = 8;

//Difference in value that qualifies as a press
const short JUMP_THRESHOLD = 35;

//How much a jump can differ from the last to qualify as consecutive
//make sure its no larger than 1024...
const short JUMP_VARIABILITY = 15;

//After this amount of consecutive (and similar) jumps is reached,
//the baseline is reset to that jump sequences avg velocity
const short MAX_CONSECUTIVE_JUMPS = 16384;

//How frequently do we add an element to the baseline buffer. Used so that we dont compute baseline so often.
const short CYCLES_PER_BASELINE = 5;

const int BAUD_RATE = 9600;

int val = 0;
int cnt = 0;
short baselineBuffer[BUFFER_SIZE];
short jumpBuffer[JUMP_BUFFER_SIZE];
int baseline = 0;
int lastVal = 2048;    //Using 2048 as default value that will never match the current val when testing for consecutive jumps
int jumpCount = 0;
int consecutiveJumpCount = 0;

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
    Serial.print("Computed new baseline : ");
    Serial.println(baseline);
  }

  //New Val
  val = (short) analogRead(potPin1);
  short jumpVal = val - baseline;

  //If jump is large enough, save val to buffer and print average jump if its full.
  //Also makes sure that we don't get stuck in jump by restablishing baseline after some stagnation
  if (jumpVal >= JUMP_THRESHOLD) {
    //If we get many consecutive jumps without much variability, reset baseline.
    //2048 is default value for lastVal, so it will never match on this condition
    //since val is between [0, 1024] and variability should be no larger than 1024
    if (abs(lastVal - val) < JUMP_VARIABILITY) {
      consecutiveJumpCount++;
      //   Serial.println("Consecutive");
      //      Serial.println(consecutiveJumpCount);
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
    //If buffer is full, print buffer average to serial and reset counter
    //This means we send one value every JUMP_BUFFER_SIZE iterations of the
    //main loop if the button is held down. Making JUMP_BUFFER_SIZE too large would
    //thus cause timing issues here.
    else {
      short avgVal = computeAverage(jumpBuffer, jumpCount);
      Serial.print("J: ");
      Serial.println(constrain(avgVal - baseline, 0, 512));
      jumpCount = 0;
      lastVal = val;
    }
    //Serial.print("jumps : ");
    //Serial.println(jumpCount);

  }
  //Add value to buffer for baseline update and reset jump counting variables
  else {
    //if last cycle was jump, we should send the remaining jump data to the serial
    if (lastVal != 2048 && jumpCount > 0) {
      short avgVal = computeAverage(jumpBuffer, jumpCount);
      Serial.print("J: ");
      Serial.println(constrain(avgVal - baseline, 0, 512));
    }
    //Signals baseline, useful for graphing in arduino serial grapher
    Serial.println("J: 0");

    //every x loops, add value to baseline buffer for updating baseline
    if (cnt % CYCLES_PER_BASELINE == 0) {
      baselineBuffer[(int) cnt / CYCLES_PER_BASELINE] = val;
    }
    cnt++;

    //Using 2048 as default value that will never match the current val when testing for consecutive jumps
    lastVal = 2048;

    //If you didn't know....
    jumpCount = 0;
    consecutiveJumpCount = 0;
  }
}

short computeAverage(short a[], int aSize) {
  //compute in two parts to avoid busting max int size
  long sum = 0;
  for (int i = 0; i < aSize; i++) {
    sum = sum + a[i];
  }

  short toreturn = (short) (sum / aSize);


  return toreturn;
}

