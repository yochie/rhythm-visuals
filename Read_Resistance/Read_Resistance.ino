int potPin1 = 1;    // select the input pin for the potentiometer
//int potPin2 = 2;    // select the input pin for the potentiometer
//int potPin3 = 2;    // select the input pin for the potentiometer
//int potPin4 = 2;    // select the input pin for the potentiometer

const int JUMP_THRESHOLD = 50;
const int BUFFER_SIZE = 100;
const int NUM_WAIT_CYCLES = 20;

int val = 0;
int cnt = 0;
int baselineBuffer[BUFFER_SIZE];
int baseline = 0;
int lastJumpVal = 1024;
int waitCycles = 0;


void setup() {
  Serial.begin(9600);      // open the serial port at 9600 bps:
  baseline = analogRead(potPin1);

}

// read the value from the sensor
void loop() {
  //New Val
  val = analogRead(potPin1);

  //If still coming down from last jump
  if (val >= lastJumpVal - 50 && waitCycles > 0){
    waitCycles--;
    return;
  }
  else if (cnt == BUFFER_SIZE){
    cnt = 0;
    baseline = computeAverage(baselineBuffer);
    Serial.println("Computing new baseline :");
    Serial.println(baseline);

  }
  //If Jumped up JUMP_THRESHOLD or more from baseline
  else if (val - baseline >= JUMP_THRESHOLD && baseline != 0){
     Serial.println(val);
     Serial.println("jump");
     lastJumpVal = val;
     waitCycles = NUM_WAIT_CYCLES;
  }
  else{
    Serial.println(val);
    baselineBuffer[cnt] = val;
  }
  cnt++;
}

int computeAverage(int a[]){
  int sum = 0;
  for(int i =0; i < BUFFER_SIZE; i++){
    sum += a[i];
  }
  return sum/BUFFER_SIZE;
}

