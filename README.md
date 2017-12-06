# rhythm-visuals
Podorythmy visual rendered using serial input

Read_resistance.ino is designed to be uploaded to an arduino type controller.
The script sends data through the serial port to notify of analog value change on specified pins when the read value
is above a dynamically calculated baseline by jump_threshold units, where threshold units map [0V, 5V] or [0V to 3.3V] 
(depends on controller) onto [0, 1024]. When no significant change is detected it will print 0 every few microseconds
(1 microsecond + time to run loop).

Although any analog value could be read, the original intent of this project was to read voltage drop from a compressed
anti-static foam (often used to package integrated circuits) in series with a ~5KΩ resistance to limit current. 
