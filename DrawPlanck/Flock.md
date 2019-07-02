Flock mode
======

Moves flock of boids across the screen based on midi inputs. Also generates scrolling walls that can collide with boids to destroy them.

## Triggers
- Tapping consecutively for a configured number of times on any pad to generate new boid and or move the flocks target.

## Config
### Flock
- MAX_FLOCK_SIZE : Maximum number of boids in flock.
- PRESSES_FOR_BOID : Number of consecutive presses on any one pad to generate new boid.
- MOVE_SPEED : Target moving speed.
- PRESSES_FOR_TARGET_MOVE : Number of consecutive presses to move the flocks target in configured direction.

### Directions
- TOP_RIGHT_NOTE : One of "UP", "DOWN", "LEFT" or "RIGHT" indicating direction to move flock.
- TOP_LEFT_NOTE : One of "UP", "DOWN", "LEFT" or "RIGHT" indicating direction to move flock.
- BOTTOM_LEFT_NOTE : One of "UP", "DOWN", "LEFT" or "RIGHT" indicating direction to move flock.
- BOTTOM_RIGHT_NOTE : One of "UP", "DOWN", "LEFT" or "RIGHT" indicating direction to move flock.

### Walls
- SCROLL_SPEED : Horizontal pixels per frame.
- NUM_WALLS : Splits screen width to create this amount of walls.
- MIN_WALL_HEIGHT : Minimum pixel height of walls.
- SAFE_ZONE : Minimum gap to preserve between top and bottom walls and minimum corridor betweeen two vertical wall sections.

### Life and death
- MAX_LIVES : Number of lives you start with.
- DEATH_IMMUNE_SECONDS : Number of seconds after death for which you are immune to death. Allows player to bring target back inside safe zone to avoid chaining deaths.
- GAME_OVER_ANIMATION_SECONDS : Duration of "GAME OVER" message display. While displayed, players can continue playing but do not acquire score or lose lives.

## TODO
