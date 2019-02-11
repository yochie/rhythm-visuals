Circle mode
=======

Circles in center represent each assigned pad note. Whenever a note is recieved, the circle grows. If the same note is used twice, a "slave" circle is created for that note which will grow anytime its master note is used.

## Triggers
- Double tapping any pad

## Config
### Sensor circles
- ROTATION_SPEED
- SHRINK_FACTOR
- MAX_CIRCLE_WIDTH
- MIN_CIRCLE_WIDTH
- SENSOR_THICKNESS
- SENSOR_COLOR_RANGE_MIN
- SENSOR_COLOR_RANGE_MAX

### Slave circles
- MAX_SLAVE_CIRCLE_WIDTH
- MIN_SLAVE_CIRCLE_WIDTH
- SLAVE_THICKNESS
- PRESSES_FOR_SLAV
- MAX_SLAVES
- SLAVE_SHRINK_FACTOR

### Midi controller
- MAX_VELOCITY

## TODO
- Associate color to each sensor circle and pass it along (with some variations) to the slave