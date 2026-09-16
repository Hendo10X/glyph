# G.L.Y.P.H.

A shape-shifting physics platformer built in **Godot 4**.

You control a single object that morphs between three forms — each with its own
physics — to solve momentum-based puzzles and reach the goal before the timer runs out.

## Shapes

- **Circle** — rolls fast and bounces.
- **Cube** — stable and grippy; good for control and pushing.
- **Triangle** — glides; used to cover gaps.

Shifting shape resets the level timer, so pick your form deliberately.

## Getting started

1. Install [Godot 4](https://godotengine.org/download).
2. Clone this repo:
   ```bash
   git clone https://github.com/Hendo10X/glyph.git
   ```
3. Open `project.godot` in Godot and press **Play**.

## Project layout

- `scenes/` — player, menus, and the 10 levels plus a tutorial.
- `scenes/components/` — reusable pieces (coins, doors, platforms, hazards).
- `scripts/` — gameplay logic (player, game manager, HUD, level components).
- `resources/` — physics materials for each shape.
