# rhythm-visuals
Detecting and rendering real time analog input peaks

## Input

### Arduino script

Read_resistance.ino is designed to be uploaded to an arduino type controller. The script sends data through the serial port to notify
of an analog value spike on specified pins when the polled value is above the baseline by a certain threshold. The baseline is averaged
over the previous readings while they remain below threshold. The threshold is adjusted based on signal stability to allow for more 
sensitive readings with more stable sensors.

### Hardware

Although any analog value could be read, the original intent of this project was to read voltage drop from a compressed
anti-static foam (often used to package integrated circuits) in series with a resistance to limit current. The diagram below shows an
example circuit using a single sensor, but any number of sensors can be plugged in parralel between the voltage rails and connected to 
a different analog pin. Using a teensy 3.6 (180 MHz), stable readings for 4 simultaneous sensors were comfortably achieved.

![circuit diagram](/diagram_podo.png?raw=true)

## Output

### Processing script

Draw_planck.pde is a processing script that takes input from the serial port sent by Read_resistance.ino and outputs animations.
This script is still in the workings and is not functionnal yet. 

### Arduino serial plotter

To facilitate parameter adjustments and debugging, the Read_resistance.ino script has a debug branch that can be used in conjunction with the arduino IDE serial plotter (ctrl + shift + L) to visualize the baselines, thresholds and current sensor readings for each sensor. The master branch serial output format can also be somewhat observed in the serial plotter, but with more limited information.

### MIDI

Teensy offers native MIDI output via the USB serial. Each sensor can be attributed a note. When an jump in value is detected, the teensy will send a NOTE_ON message (with reasonable latency, depending on parameters and hardware) and a corresponding NOTE_OFF message when the sensor is released. While the button is pressed, poly aftertouch messages are sent indicating the amplitude enveloppe for the note. Note that there is a tradeoff between latency and signal smoothing. As Midi prioritizes latency, you might expect more noise in the signal. I will need to look at ways to measure latency, but using 4 sensors and reducing smoothing to minimum, the latency felt manageable. I have currently tested using MIDI OX on windows with the default synthesizer, but perhaps better response times can be attained using linux low-latency kernel.
