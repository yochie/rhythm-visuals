SuperLuminal mode
=======
Creates stars of different types depending on pressed pad, with an optional flow of stars in background. Star types have different speeds and sizes (based on grow factors), and their quantity vary depending on configuration and MIDI velocity.

## Triggers
- Stars backgroud flow: bottom-left-note ((see [main config](DrawPlanck/config.properties))) if pressed a configurable number of times consecutively

## Config
- Stars stroke thickness
#### Background stars flow
- Set ON/OFF
- Number of presses to trigger ON/OFF
- Number and speed of stars
#### Pad stars
- Number (multiplied by pad velocity)
- Pad velocity factor (velocity is multiplied by this factor)
- Speed
- Grow factor (actually, steps by which stars radius grow)

## TODO
- Use configurable colors
- Use trigger to use or not velocity factor?
- Fix biggest stars removing rare bug
- Cleaning
