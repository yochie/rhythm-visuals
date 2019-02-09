Global config
======

Handles mode switching by triggering whenever TOP_LEFT_NOTE pad is triggered. Also handles the following general tasks:

- MIDI connection and message parsing (calls handleMidi on the appropriate mode object for each recieve message)
- Pad configuration (select notes for "named" pad and auxiliary/unnamed pads)
- Background drawing (at every frame)
- Maintaining the padWasPressed list that stores booleans ordered by pad index indicating if each pad was pressed since last draw() execution

## Triggers
- Tapping consecutively for a configured number of times on the TOP_LEFT_NOTE pad

## Config
### Midi
MIDI_DEVICE=0

### Background
LOGO_SCALING=0.05

### Modes
PRESSES_FOR_MODE_SWITCH=3


### Pads
BOTTOM_RIGHT_NOTE=80
BOTTOM_LEFT_NOTE=84
TOP_LEFT_NOTE=82
TOP_RIGHT_NOTE=85
AUX_PAD_NOTES=70,75

## TODO
- Lots of stuff, see comments in file...