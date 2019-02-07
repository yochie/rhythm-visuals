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

Draw_planck.pde is a processing script that takes input from the midi port and generates animations.
This script is still in the workings, but it is currently functionnal. To use it, install 
processing (http://processing.org/). Then, using the library importer from the processing IDE, install
the java MidiBus library. You can then run the the script from processing. You might need to change the
midiDevice variable at the top of the file to the index of the port your device uses. A list of available
devices will be printed to console on startup (need to make this into a GUI).

#### Modes

The script is divided into seperate modes, each with their own config and .pde file. The modes currently implemented are:

* Circle (see [Circle.md](DrawPlanck/Circle.md))
* SuperLiminal (see [SuperLiminal.md](DrawPlanck/SuperLiminal.md))
* Word (see [Word.md](DrawPlanck/Word.md))

### Arduino serial plotter

To facilitate parameter adjustments and debugging, the Read_resistance.ino script has a debug config switch that can be used in conjunction with the arduino IDE serial plotter (ctrl + shift + L) to visualize the baselines, thresholds and current sensor readings for each sensor.

### MIDI

Teensy offers native MIDI output via the USB serial. Each sensor can be attributed a note. When a jump in value is detected, the teensy will send a NOTE_ON message (with reasonable latency, depending on parameters and hardware) and a corresponding NOTE_OFF message when the sensor is released. While the button is pressed, poly aftertouch messages can be sent indicating the amplitude enveloppe for the note. Note that there is a tradeoff between latency and signal smoothing inherent to the configuration settings (buffers sizes and such). Watch out if you're using Windows' default synth configuration, at least in some cases it adds considerable latency.
