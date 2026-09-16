extends Camera2D
## Dynamic zoom: pull OUT when the player is moving fast or flying through a big
## arc (so they can read where they're going), and ease back IN when slow so
## precise platforming and shape-puzzles feel close and deliberate.

## zoom > 1 magnifies (in); zoom < 1 shows more of the world (out).
const ZOOM_IN := 1.15      # calm / precise
const ZOOM_OUT := 0.72     # fast / airborne
const SPEED_IN := 80.0     # at/below this speed → fully zoomed in
const SPEED_OUT := 640.0   # at/above this speed → fully zoomed out
const LERP_SPEED := 3.0    # how fast the zoom eases toward its target

@onready var _body := get_parent()


func _process(delta: float) -> void:
	var vel: Vector2 = _body.linear_velocity if _body is RigidBody2D else Vector2.ZERO
	# Vertical motion frames a little wider than horizontal (jumps/falls reveal more).
	var framing := maxf(absf(vel.x), absf(vel.y) * 1.25)
	var t := clampf((framing - SPEED_IN) / (SPEED_OUT - SPEED_IN), 0.0, 1.0)
	var target := lerpf(ZOOM_IN, ZOOM_OUT, t)
	var z := lerpf(zoom.x, target, clampf(delta * LERP_SPEED, 0.0, 1.0))
	zoom = Vector2(z, z)
