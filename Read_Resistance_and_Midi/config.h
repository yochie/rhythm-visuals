//Gives number of microseconds for corresponding duration
//Used to improve readability of configuration
const unsigned long MICROSECOND = 1;
const unsigned long MILLISECOND = 1000;
const unsigned long SECOND = 1000000;

const int NUM_SENSORS = 4;

//analog pin numbers for each sensor
const int SENSOR_PINS[NUM_SENSORS] = {0, 1, 2, 3};

/*SERIAL CONFIG*/

//print readings to arduino plotter
const boolean DEBUG = true;

//Serial communication Hz
const int BAUD_RATE = 115200;

//Delay in microseconds adter each line of debug messages
//Blocking (uses delay() function)
//Prevents overloading serial communications
const int PRINT_DELAY = 100 * MICROSECOND;

/*MIDI CONFIG*/

const boolean WITH_MIDI_OUTPUT = true;
//Pad order: BOTTOM-LEFT // TOP-LEFT // TOP-RIGHT // BOTTOM-RIGHT
const int NOTES[NUM_SENSORS] = {82, 84, 80, 85};
//const int IS_CLOCKING_PAD[NUM_SENSORS] = {true, false, false, false};
const int MIDI_CHANNEL = 1;
const int BANK = 127;
const int PROGRAM = 0;

/*MOTOR CONFIG*/

const boolean WITH_MOTORS = true;
const int NUM_MOTORS = 2;

//digital pin numbers for each sensor
const int MOTOR_PINS[NUM_MOTORS] = {11, 12};

//Used as substitute for motors
const int LED_PIN = 13;

//index of MOTO_PIN to map for each sensor
//Needs to be in the range [-1, NUM_MOTORS - 1].
//Uses LED_PIN instead of motor when -1
const int SENSOR_TO_MOTOR[NUM_SENSORS] = {0, -1, -1, 1};

//To limit duty cycle
unsigned const long MAX_MOTOR_PULSE_DURATION = 200 * MILLISECOND;

//To limit puppet movement
int TAPS_PER_PULSE = 1;

/*SENSOR CONFIG*/

//Maximum value returned by AnalogRead()
//Normally 1023 with arduino, but the operational amplifiers
//used in the sensor circuitry have a  maximum output voltage
//of 2V when powered at 3.3V
const int MAX_READING = 700;

//MIN_THRESHOLD is used when the baseline is very stable
const int MIN_THRESHOLD = 150;

//MAX_THRESHOLD is used when the baseline is very unstable
const int MAX_THRESHOLD = 150;

//Used to cap baseline to ensure there is place to jump below MAX_READING
const int MIN_JUMPING_RANGE = 80;

//Time between threshold traversal and rising() signal
//Allows for velocity measurment and ignoring very short jumps
unsigned const long NOTE_VELOCITY_DELAY = 2 * MILLISECOND;

//Delay in microseconds after sending rising() signal
//for which no more signals are sent for that sensor
unsigned const long NOTE_ON_DELAY = 50 * MILLISECOND;

//Delay in microseconds after sending falling() signal
//for which no more signals are sent for that sensor
unsigned const long NOTE_OFF_DELAY = 50 * MILLISECOND;

//Delay in microseconds between sustained() signals
//Also the delay between rising() and sustained()
unsigned const long SUSTAIN_DELAY = 100 * MILLISECOND;

//Delay in micro seconds between baseline samples
unsigned const long BASELINE_SAMPLE_DELAY = 0.5 * MILLISECOND;

//number of microseconds after jump during which baseline update is paused
unsigned const long BASELINE_BLOWBACK_DELAY = 40 * MILLISECOND;

//TODO: change constant to timing notation
//amount of baseline samples that we average baseline over
//Multiply with BASELINE_SAMPLE_DELAY to get baseline update duration.
const int BASELINE_BUFFER_SIZE = 1000;

//TODO: move division to the code
//number of samples removed from baseline buffer when jump is over
//This is used to prevent rising edge portion of signal
//that is below threshold from weighing in on baseline.
//Making too large would prevent baseline update while fast-tapping.
//Multiply with BASELINE_SAMPLE_DELAY  to get the rise time to reach the threshold.
const int RETRO_JUMP_BLOWBACK_SAMPLES = (0.5 * MILLISECOND) / BASELINE_SAMPLE_DELAY;

//TODO: move division to the code
//After this amount of sustains
//the baseline is reset to the last sensor reading
const int MAX_CONSECUTIVE_SUSTAINS = (10 * SECOND) / SUSTAIN_DELAY;
