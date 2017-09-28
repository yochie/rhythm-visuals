const int potPin1 = 1;    // select the input pin for the potentiometer
//int potPin2 = 2;    // select the input pin for the potentiometer
//int potPin3 = 2;    // select the input pin for the potentiometer
//int potPin4 = 2;    // select the input pin for the potentiometer

const short BUFFER_SIZE = 256; //amount of vals that we average baseline over
const short JUMP_BUFFER_SIZE = 64; //max amount of jump vals used to average press velocity

const short JUMP_THRESHOLD = 50; //Difference in value that qualifies as a press
const short JUMP_VARIABILITY = 30; //How much a jump can differ from the last to qualify as consecutive
const short MAX_CONSECUTIVE_JUMPS = JUMP_BUFFER_SIZE * 4; //After this amount of consecutive (and similar) jumps is reached
//, the baseline is reset to that jump sequences avg velocity

const int BAUD_RATE = 19200;

int val = 0;
int cnt = 0;
short baselineBuffer[BUFFER_SIZE];
short jumpBuffer[JUMP_BUFFER_SIZE];
int baseline = 0;
int lastJumpVal = 2048;
int waitCycles = 0;
int jumpCount = 0;
int consecutiveJumpCount = 0;

void setup() {
  Serial.begin(BAUD_RATE);      // open the serial port at x bps:

  //establish first baseline using 100 (arbitrary) values
  for (int i = 0; i < 100; i++) {
    baseline += analogRead(potPin1);
  }

  baseline = baseline / 100;
}

// read the value from the sensor
void loop() {
  //New Val
  val = (short) analogRead(potPin1);

  //If buffer is full, compute its baseline and reset counter
  if (cnt == BUFFER_SIZE) {
    cnt = 0;
    baseline = computeAverage(baselineBuffer, BUFFER_SIZE);
    //    Serial.print("Computed new baseline : ");
    //    Serial.println(baseline);
  }
  short jumpVal = val - baseline;
  //If moved up by JUMP_THRESHOLD or more from baseline, save jump to buffer.
  if (jumpVal > JUMP_THRESHOLD) {
    //If there is place in buffer, add jump there.
    if (jumpCount < JUMP_BUFFER_SIZE) {
      jumpBuffer[jumpCount] = jumpVal;
      jumpCount++;
    }
    //print buffer to serial and reset counter
    else {
      short avgVelocity = computeAverage(jumpBuffer, jumpCount);
      Serial.print("J: ");
      Serial.println(avgVelocity);
      jumpCount = 0;
    }
    lastJumpVal = val;
    //Serial.print("jumps : ");
    //Serial.println(jumpCount);
    //If we get many consecutive jumps without much variability, reset baseline.
//        if (lastJumpVal - JUMP_VARIABILITY < val  && val < lastJumpVal + JUMP_VARIABILITY) {
//          consecutiveJumpCount++;
//          if (consecutiveJumpCount >= MAX_CONSECUTIVE_JUMPS) {
//            baseline = computeAverage(jumpBuffer, JUMP_BUFFER_SIZE);
//            consecutiveJumpCount = 0;
//          }
//        }

  }
  //Add value to buffer for baseline update and reset jump counting variables
  else {
    //if last cycle was jump, we should send the jump data to the serial
    if (lastJumpVal != 2048 && jumpCount > 0) {
      short avgVelocity = computeAverage(jumpBuffer, jumpCount);
      Serial.print("J: ");
      Serial.println(avgVelocity);
    }
    baselineBuffer[cnt] = val;
    cnt++;
    //Using 2048 as default value that will never match the current val when testing for consecutive jumps
    lastJumpVal = 2048;
    jumpCount = 0;
    Serial.println("J: 0");
  }

}

short computeAverage(short a[], int aSize) {
  //compute in two parts to avoid busting max int size
  long sum = 0;
  for (int i = 0; i < aSize; i++) {
    sum = sum + a[i];
  }

  short toreturn = (short) (sum / aSize);

  if (toreturn < 0)
  {
    Serial.print("sum : ");
    Serial.println(sum);
    Serial.print("size : ");
    Serial.println(aSize);
    Serial.print("(short) Average : ");
    Serial.println(toreturn);
    int sum2 = 0;
    for (int i = 0; i < aSize; i++) {
      sum2 += a[i];
      Serial.print(i);
      Serial.print(" : ");
      Serial.println(a[i]);
    }
    Serial.println("ERROR: PROBABLY BUSTED MAX LONG SIZE. YOANN, ARRANGE TON CODE.");
  }

  return toreturn;
}

