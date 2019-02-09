Global config
======

Handles mode switching by triggering whenever TOP_LEFT_NOTE pad is triggered. Also handles the following general tasks:

- MIDI connection and message parsing (calls handleMidi on the appropriate mode object for each recieve message)
- Pad configuration (select notes for "named" pad and auxiliary/unnamed pads)
- Background drawing (at every frame)
- Maintaining the global padWasPressed list that stores booleans ordered by pad index indicating if each pad was pressed since last draw() execution
- Maintaining the global pressCounter list that stores ints ordered by pad index indicating consecutive presses of a single pad (pressing any pad resets count on all others)

## Triggers
- Tapping consecutively for a configured number of times on the TOP_LEFT_NOTE pad.

## Config
### Midi
MIDI_DEVICE : Index of midi device to use. See console for list.

### Background
LOGO_SCALING : Multiplier for logo size.

### Mode switching
PRESSES_FOR_MODE_SWITCH : Number of consecutive presses on TOP_LEFT_NOTE pad to trigger mode switch

### Pads
BOTTOM_RIGHT_NOTE : MIDI note number associated to this named pad.
BOTTOM_LEFT_NOTE : MIDI note number associated to this named pad.
TOP_LEFT_NOTE : MIDI note number associated to this named pad.
TOP_RIGHT_NOTE : MIDI note number associated to this named pad.
AUX_PAD_NOTES : Comma seperated list of MIDI note numbers that will be created as unnamed auxiliary pads.

## TODO
- Lots of stuff, see comments in file...