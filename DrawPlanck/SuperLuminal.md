SuperLuminal mode
=======
Creates stars of different types depending on pressed pad, with an optional flow of stars in background. Star types have different speeds and sizes (based on grow factors), and their quantity vary depending on configuration and MIDI velocity.

## Triggers
- Stars background flow: bottom-left-note (see [main config](config.properties)) if pressed a configurable number of times consecutively

## Config
### Background stars
- BG_STARS : Set ON/OFF (show constant stars flow in background - 0 or 1).
- BG_STARS_NUMBER : Number stars created each frame.
- BG_STARS_SPEED : Bg star velocity.
- BG_STARS_TRIGGER_PRESSES : Number of presses to trigger ON/OFF.
- BG_STARS_START_COLOR : RGB value. Comma seperated integers.
- BG_STARS_END_COLOR : Idem.

### Main Stars
#### Color
- BOTTOM_LEFT_START_COLOR : RGB value for this pad. Comma seperated integers.
- BOTTOM_LEFT_END_COLOR : Idem.
- BOTTOM_RIGHT_START_COLOR : Idem.
- BOTTOM_RIGHT_END_COLOR : Idem.
- TOP_RIGHT_START_COLOR : Idem.
- TOP_RIGHT_END_COLOR : Idem.
- TOP_LEFT_START_COLOR : Idem.
- TOP_LEFT_END_COLOR : Idem.

#### Speed
- STARS1_SPEED : Main star speed for this pad.
- STARS2_SPEED : Idem.
- STARS3_SPEED : Idem.
- STARS4_SPEED : Idem.

#### Quantity
- VELOCITY_FACTOR : Number of stars is STARS1_NUMBER * hit velocity * VELOCITY_FACTOR.
- STARS1_NUMBER : Number (multiplied by pad velocity) of stars for this pad.
- STARS2_NUMBER : Idem.
- STARS3_NUMBER : Idem.
- STARS4_NUMBER : Idem.

#### Size
- STAR_THICKNESS : Stroke thickness
- STARS1_GROW_FACTOR : Grow factor (actually, steps by which stars radius grow) for stards of this pad.
- STARS2_GROW_FACTOR : Idem.
- STARS3_GROW_FACTOR : Idem.
- STARS4_GROW_FACTOR : Idem.

## TODO
- Use trigger to use or not velocity factor?
- Fix biggest stars removing rare bug
- Cleaning
