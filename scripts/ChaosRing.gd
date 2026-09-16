extends Node2D
## The "Forced Chaos" timer baked into the player character: a thin ring that
## drains clockwise as the countdown runs and flushes toward red as it empties.
## Lives in global space (top_level) so it tracks the player's position but never
## inherits the Circle's spin — the gauge always reads upright.

const RADIUS := 22.0
const WIDTH := 3.0
const SEGMENTS := 48

@onready var _player := get_parent()


func _process(_delta: float) -> void:
	# Follow position only; ignore the body's rotation.
	global_position = _player.global_position
	global_rotation = 0.0


func _draw() -> void:
	if not _player.has_method("chaos_fraction"):
		return
	var frac: float = _player.chaos_fraction()

	# Faint full-circle track underneath.
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, SEGMENTS, Color(1, 1, 1, 0.08), WIDTH, true)

	if frac <= 0.0:
		return
	# Remaining time drawn from the top (-90°), sweeping clockwise.
	var start := -PI / 2.0
	var end := start + TAU * frac
	# Calm cyan when full → hot orange/red as it empties = rising pressure.
	var col := Color(1.0, 0.35, 0.2).lerp(Color(0.3, 0.9, 1.0), frac)
	col.a = 0.9
	draw_arc(Vector2.ZERO, RADIUS, start, end, SEGMENTS, col, WIDTH, true)
