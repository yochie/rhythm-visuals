# rhythm-visuals
Detecting and rendering real time analog input peaks

## Input

### Arduino script

Read_resistance.ino is designed to be uploaded to a Teensy (3.6) controller via the arduino ide (see [Teensyduino documentation](https://www.pjrc.com/teensy/teensyduino.html)). The script sends data through the serial port to notify of an analog value spike on specified pins when the polled value is above the baseline by a certain threshold. The baseline is averaged over the previous readings while they remain below threshold. The threshold is adjusted based on signal stability to allow for more sensitive readings with more stable sensors. The script also produces and/or receives MIDI signals across USB using Teensy built-in support (see [Teensy USB MIDI documentation](https://www.pjrc.com/teensy/td_midi.html))

### Hardware

Although any analog value could be read, the original intent of this project was to read voltage drop from a compressed
anti-static foam (often used to package integrated circuits) in series with a resistance to limit current. The diagram below shows an
example circuit using a single sensor, but any number of sensors can be plugged in parralel between the voltage rails and connected to 
a different analog pin. Using a teensy 3.6 (180 MHz), stable readings for 4 simultaneous sensors were comfortably achieved.

In our specific implementation, we used these [FSR sensors](https://www.digikey.ca/product-detail/en/interlink-electronics/30-73258/1027-1002-ND/2476470) along with LM358 OP amps in the voltage divider configuration suggested by [Interlink's FSR Integration Guide](http://www.generationrobots.com/media/FSR400-Series-Integration-Guide.pdf) (p.18).

![circuit diagram](/diagram_podo.png?raw=true)

## Output

### Processing script

Draw_planck.pde is a processing script that takes input from the midi port and generates animations.
This script is still in the workings, but it is currently functionnal. To use it, install 
processing (http://processing.org/). Then, using the library importer from the processing IDE, install
the java MidiBus library. You can then run the the script from processing. You might need to change the
midiDevice variable at the top of the file to the index of the port your device uses. A list of available
devices will be printed to console on startup (need to make this into a GUI).

#### Developpers

If developping in a Windows environment without a physical midi controller, you might want to use the following:

- VMPK (http://vmpk.sourceforge.net/) to simulate the planck along with the included keyboard map (drawplank.xml) which can be imported to VMPK from "Edit" -> "Keyboard Map" -> "Open...". The keyboard map assigns the Q,W,A and S keys on your keyboard to the default planck notes.
- loopMIDI (https://www.tobias-erichsen.de/software/loopmidi.html) to generate a virtual MIDI port to allow communication between VMPK and DrawPlanck.

#### Modes

The script is divided into separate modes, each with their own config and .pde file. The main (global) script and the modes currently implemented are documented in the following locations:

* [Main](DrawPlanck/DrawPlanck.md)
* [Circle](DrawPlanck/Circle.md)
* [Word](DrawPlanck/Word.md)
* [SuperLuminal](DrawPlanck/SuperLuminal.md)
* [Flock](DrawPlanck/Flock.md)

### Arduino serial plotter

To facilitate parameter adjustments and debugging, the Read_resistance.ino script has a debug config switch that can be used in conjunction with the arduino IDE serial plotter (ctrl + shift + L) to visualize the baselines, thresholds and current sensor readings for each sensor.

### MIDI

Teensy offers native MIDI output via the USB serial. Each sensor can be attributed a note. When a jump in value is detected, the teensy will send a NOTE_ON message (with reasonable latency, depending on parameters and hardware) and a corresponding NOTE_OFF message when the sensor is released. While the button is pressed, poly aftertouch messages can be sent indicating the amplitude enveloppe for the note. Note that there is a tradeoff between latency and signal smoothing inherent to the configuration settings (buffers sizes and such). Watch out if you're using Windows' default synth configuration, at least in some cases it adds considerable latency.
