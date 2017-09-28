int potPin1 = 1;    // select the input pin for the potentiometer
//int potPin2 = 2;    // select the input pin for the potentiometer
//int potPin3 = 2;    // select the input pin for the potentiometer
//int potPin4 = 2;    // select the input pin for the potentiometer

const short BUFFER_SIZE = 512;
const short JUMP_BUFFER_SIZE = 64;

const short JUMP_THRESHOLD = 30;
const short JUMP_VARIABILITY = 30;

const short NUM_WAIT_CYCLES = 20;
const short MAX_CONSECUTIVE_JUMPS = 128;

int val = 0;
int cnt = 0;
short baselineBuffer[BUFFER_SIZE];
short jumpBuffer[JUMP_BUFFER_SIZE];
int baseline = 0;
int lastJumpVal = 1024;
int waitCycles = 0;
int jumpCount = 0;

void setup() {
  Serial.begin(115200);      // open the serial port at 9600 bps:

  //establish first baseline
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
    Serial.print("Computed new baseline : ");
    Serial.println(baseline);
  }

  //If moved up by JUMP_THRESHOLD or more from baseline, signal jump to serial.
  if (val - baseline >= JUMP_THRESHOLD) {
    Serial.print("Jump from baseline ");
    Serial.print(baseline);
    Serial.print(" to ");
    Serial.println(val);

    //If we get many consecutive jumps without much variability, reset baseline.
    if (lastJumpVal - JUMP_VARIABILITY < val  && val < lastJumpVal + JUMP_VARIABILITY) {
      jumpCount++;
      if (jumpCount >= MAX_CONSECUTIVE_JUMPS - JUMP_BUFFER_SIZE){
        jumpBuffer[jumpCount - (MAX_CONSECUTIVE_JUMPS - JUMP_BUFFER_SIZE)] = val;
      }
      if (jumpCount > MAX_CONSECUTIVE_JUMPS) {
        baseline = computeAverage(jumpBuffer, JUMP_BUFFER_SIZE);
      }
    }
    lastJumpVal = val;
  }
  //Add value to buffer for baseline update and reset jump counting variables
  else {
    baselineBuffer[cnt] = val;
    cnt++;
    //Using 2048 as default value that will never match the current val when testing for consecutive jumps
    lastJumpVal = 2048;
    jumpCount = 0;
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

