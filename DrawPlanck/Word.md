Word mode
=======

Random word is presented at random position near center of screen. Double tapping configured pad chooses a new word and position.

## Triggers
- Double tapping configured pad

## Config
### Word bank
- WORDS : Comma seperated list of words to present on screen.
- WORDS_ALT : Alternative word bank.


### Triggers
- PRESSES_FOR_WORD_SWITCH : Number of consecutive presses on configured pad to reroll display word
- PRESSES_FOR_WORD_SWITCH_ALT :  Same as above but for alternative word bank.
- SWITCH_PAD_NAME : Name of the named Pad object (ie non auxiliary pad) that will trigger the word change. See namedPads in main script (DrawPlanck).
- SWITCH_PAD_NAME_ALT : Same as above but for alternative word bank.


### Font
- FONT_SIZE : Pixel size of font. See Processing doc for createFont().
- FONT_NAME : Name of the font to be used. See console at startup to see available fonts on your OS.
- FONT_HUE : HSB hue value between 0 and 255
- ALPHA_REDUCTION : Muliplier for alpha value at each frame. Used to time the disappearing of word.

## TODO
- String encoding to allow special characters is currently bugged.
- Swirl on word appearance...