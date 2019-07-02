Global script
======

Handles mode switching by triggering whenever TOP_LEFT_NOTE pad is triggered. Also handles the following general tasks:

- MIDI connection and message parsing (calls handleMidi on the appropriate mode object for each recieve message)
- Pad configuration (select notes for "named" pad and auxiliary/unnamed pads)
- Background drawing (at every frame)
- Maintaining the global padWasPressed list that stores booleans ordered by pad index indicating if each pad was pressed since last time resetPressed (padIndex) was called. Make sure you reset just after checking flags to properly consume the flag and avoid missing presses. If your mode doesn't use padWasPressed, you need to call noModePressChecking() at draw() beginning.
- Maintaining the global pressCounter list that stores ints ordered by pad index indicating consecutive presses of a single pad (pressing any pad resets count on all others). The list is incremented synchronously (on draw() calls), so don't check its state asynchronously (in handleMidi()). 

## Triggers
- Holding pressed for a configured number of time the TOP_LEFT_NOTE pad.

## Config
### Midi
- MIDI_DEVICE : Index of midi device to use. See console for list.

### Background
- LOGO_SCALING : Decimal multiplier for logo size.
- WITH_BACKGROUND : 0 or 1 to activate background.

### Mode switching
- MILLISECONDS_FOR_MODE_SWITCH : Number of milliseconds to hold TOP_LEFT_NOTE to trigger mode switch.

### Pads
- BOTTOM_RIGHT_NOTE : MIDI note number associated to this named pad.
- BOTTOM_LEFT_NOTE : MIDI note number associated to this named pad.
- TOP_LEFT_NOTE : MIDI note number associated to this named pad.
- TOP_RIGHT_NOTE : MIDI note number associated to this named pad.
- AUX_PAD_NOTES : Comma seperated list of MIDI note numbers that will be created as unnamed auxiliary pads.

## TODO
- Lots of stuff, see comments in file...