# G.L.Y.P.H.

A shape-shifting physics platformer built in **Godot 4**.

You control a single object that morphs between three forms — each with its own
physics — to solve momentum-based puzzles and reach the goal before the timer runs out.

## Shapes

- **Circle** — rolls fast and bounces.
- **Cube** — stable and grippy; good for control and pushing.
- **Triangle** — glides; used to cover gaps.

Every shape change resets the shift timer. Let it run out for a full minute and
the game picks a shape for you — so commit to a form, but don't stall in it.

## Lives

You get **three lives per level**, shown top-left. Hitting a hazard costs one and
sends you back to the level's spawn point with a brief moment of invulnerability.
Lose all three and the run restarts from Level 1. Reaching a new level refills them.

## Getting started

1. Install [Godot 4](https://godotengine.org/download).
2. Clone this repo:
   ```bash
   git clone https://github.com/Hendo10X/glyph.git
   ```
3. Open `project.godot` in Godot and press **Play**.

## Project layout

- `scenes/` — player, menus, and the 20 levels plus a tutorial.
- `scenes/components/` — reusable pieces (coins, doors, platforms, hazards).
- `scripts/` — gameplay logic (player, game manager, HUD, level components).
- `resources/` — physics materials for each shape.
