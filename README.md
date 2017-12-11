# rhythm-visuals
Podorythmy visual rendered using serial input

## Read resistance

Read_resistance.ino is designed to be uploaded to an arduino type controller.
The script sends data through the serial port to notify of analog value change on specified pins when the read value is above a dynamically calculated baseline by an also dynamic threshold.

Although any analog value could be read, the original intent of this project was to read voltage drop from a compressed
anti-static foam (often used to package integrated circuits) in series with a resistance to limit current. The diagram below shows an
example circuit using a single sensor, but any number of sensors can be plugged in parralel between the voltage rails. 

![circuit diagram](/diagram_podo.png?raw=true)

## Draw planck

Draw_planck.pde is a processing script that takes input from the serial port sent by Read_resistance.ino and outputs animations.
This script is still in the workings and is not functionnal yet.
