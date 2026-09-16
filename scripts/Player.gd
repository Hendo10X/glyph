extends RigidBody2D
## Project G.L.Y.P.H. — player controller.
## Phase 1A + 1C: one RigidBody2D, three shapes, live shape-shifting with
## momentum (velocity) preserved across swaps.
##
## Movement is force-based (the chosen input model) but the forces are sized to
## overcome each shape's friction at Godot's 980 gravity — otherwise heavy/grippy
## shapes can't move at all. Jump sets takeoff velocity directly so it's reliable
## regardless of mass and never needs a double-press.

enum Shape { CUBE, CIRCLE, TRIANGLE }

## Per-shape tuning. One dictionary so movement code never hardcodes numbers.
const SHAPE_DATA := {
	Shape.CUBE: {
		"mass": 5.0,
		"gravity_scale": 1.0,
		"linear_damp": 4.0,       # grinds to a stop fast when no input
		"angular_damp": 1.0,
		"lock_rotation": true,    # stays flat
		"move_force": 7500.0,     # big enough to beat its own friction
		"max_speed": 240.0,
		"jump_velocity": 360.0,   # heavy → lowest jump
	},
	Shape.CIRCLE: {
		"mass": 1.0,
		"gravity_scale": 1.0,
		"linear_damp": 0.2,       # keeps rolling / carries momentum
		"angular_damp": 0.2,
		"lock_rotation": false,   # free to roll
		"move_force": 1600.0,
		"max_speed": 520.0,
		"jump_velocity": 560.0,   # light → highest jump
	},
	Shape.TRIANGLE: {
		"mass": 2.0,
		"gravity_scale": 1.0,
		"linear_damp": 0.6,
		"angular_damp": 1.0,
		"lock_rotation": true,    # stays base-down; no tipping/spinning
		"move_force": 3500.0,
		"max_speed": 360.0,
		"jump_velocity": 470.0,
	},
}

## Triangle glide (aerial-control identity): while airborne and steering, cut
## gravity and add forward push so it floats across gaps no other shape can.
const TRIANGLE_GLIDE_GRAVITY := 0.45
const TRIANGLE_GLIDE_FORCE := 900.0

## Jump feel. Coyote = grace period after leaving ground; buffer = how long an
## early press is remembered. Together they kill the "had to press twice" feel,
## especially for the bouncy Circle whose grounded state flickers.
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12

## Forced Chaos timer. Counts down continuously; at zero a RANDOM shape is forced
## on the player. Crucially it resets on EVERY manual shift, so the pressure only
## bites players who hold/hesitate — never those who keep flowing between shapes.
## A full minute: long enough to actually read a puzzle and commit to a shape,
## instead of being reshuffled mid-thought.
const CHAOS_TIME := 60.0

const MATERIALS := {
	Shape.CUBE: preload("res://resources/mat_cube.tres"),
	Shape.CIRCLE: preload("res://resources/mat_circle.tres"),
	Shape.TRIANGLE: preload("res://resources/mat_triangle.tres"),
}

## Brand colors per shape (match the Visuals polygons). Used to tint the shift
## burst and the speed trail so feedback always reads as "this shape".
const SHAPE_COLOR := {
	Shape.CUBE: Color(0.2, 0.5, 1.0),
	Shape.CIRCLE: Color(1.0, 0.2, 0.7),
	Shape.TRIANGLE: Color(1.0, 0.85, 0.2),
}

@export var current_shape: Shape = Shape.CIRCLE
## When true, the controller auto-drives itself (used by the headless probe).
@export var debug_drive: bool = false

## Which shapes a level starts with available. Locked shapes can't be shifted to
## until a ShapeUnlock power-up grants them — this is what lets a level force the
## player to find and use a specific form. Set per level on the Player instance.
@export var allow_cube: bool = true
@export var allow_circle: bool = true
@export var allow_triangle: bool = true

## Upper bound a TimeBonus can stack the Chaos timer to (gives breathing room to
## hold an awkward shape through a puzzle).
const CHAOS_MAX := 90.0

signal shape_locked(shape: int)
signal shape_unlocked(shape: int)

@onready var _cols := {
	Shape.CUBE: $Col_Cube,
	Shape.CIRCLE: $Col_Circle,
	Shape.TRIANGLE: $Col_Triangle,
}
@onready var _vis := {
	Shape.CUBE: $Visuals/Vis_Cube,
	Shape.CIRCLE: $Visuals/Vis_Circle,
	Shape.TRIANGLE: $Visuals/Vis_Triangle,
}
@onready var _visuals: Node2D = $Visuals
@onready var _ground_check: RayCast2D = $GroundCheck
@onready var _trail: Line2D = $Trail
@onready var _shift_burst: CPUParticles2D = $ShiftBurst
@onready var _chaos_ring: Node2D = $ChaosRing

var _since_grounded := 999.0
var _jump_req := 0.0
var _chaos := CHAOS_TIME
var _rng := RandomNumberGenerator.new()
var _unlocked := {}
var _dbg_frame := 0


func _ready() -> void:
	add_to_group("player")
	_rng.randomize()
	_unlocked = {
		Shape.CUBE: allow_cube,
		Shape.CIRCLE: allow_circle,
		Shape.TRIANGLE: allow_triangle,
	}
	# Never start as a locked shape — fall back to the first available one.
	if not _unlocked.get(current_shape, false):
		for s in [Shape.CIRCLE, Shape.CUBE, Shape.TRIANGLE]:
			if _unlocked[s]:
				current_shape = s
				break
	_apply_shape(current_shape)
	# Register with the singleton so hazards/goals/respawns can reach us.
	# (The headless probe drives itself and has no level, so it skips this.)
	if not debug_drive:
		GameManager.register_player(self)


## How full the Forced Chaos timer is, 0..1. The ChaosRing reads this to draw.
func chaos_fraction() -> float:
	return clampf(_chaos / CHAOS_TIME, 0.0, 1.0)


## Snap to a spawn/respawn point with all momentum cleared and the timer refilled.
## Called by GameManager on level load and on death. Frictionless and instant.
func reset_to(pos: Vector2) -> void:
	global_position = pos
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	rotation = 0.0
	_jump_req = 0.0
	_since_grounded = 999.0
	_chaos = CHAOS_TIME
	if is_instance_valid(_trail):
		_trail.clear_points()


func _unhandled_input(event: InputEvent) -> void:
	if debug_drive:
		return
	if event.is_action_pressed("shift_cube"):
		_shift_to(Shape.CUBE)
	elif event.is_action_pressed("shift_circle"):
		_shift_to(Shape.CIRCLE)
	elif event.is_action_pressed("shift_triangle"):
		_shift_to(Shape.TRIANGLE)

	if event.is_action_pressed("jump"):
		request_jump()


func _physics_process(delta: float) -> void:
	# The GroundCheck ray is a child of the body, so the free-rolling Circle would
	# otherwise spin it away from straight-down and make grounding read false while
	# clearly on the floor. Pin it upright every frame.
	_ground_check.global_rotation = 0.0
	if debug_drive:
		_debug_step(delta)
		return
	move(Input.get_axis("move_left", "move_right"))
	_process_jump(delta)
	_process_chaos(delta)
	_update_trail()
	_update_invuln_flash()
	_check_out_of_bounds()


## Blink the body through the post-hit grace window so it reads as "I took a hit
## and I'm briefly safe" rather than "nothing happened".
func _update_invuln_flash() -> void:
	if not is_instance_valid(_visuals):
		return
	if GameManager.is_invulnerable():
		var on := fmod(float(Time.get_ticks_msec()) / 90.0, 2.0) < 1.0
		_visuals.modulate.a = 1.0 if on else 0.3
	elif _visuals.modulate.a < 1.0:
		_visuals.modulate.a = 1.0


## Safety net so a body that clears every Hazard and sails off the level still
## restarts instead of falling forever. Bounds are generous around the 1280x720
## play field; any level's own DeathZones catch the player sooner.
func _check_out_of_bounds() -> void:
	# Vertical falls are the real "off the edge" case; keep the horizontal bounds
	# loose so big multi-screen levels don't false-trigger. Each level also has its
	# own DeathZone band that catches falls sooner.
	var p := global_position
	if p.y > 1900.0 or p.x < -1200.0 or p.x > 9500.0:
		GameManager.respawn()


## Forced Chaos countdown. Reaching zero forces a random DIFFERENT shape on the
## player (chaotic physics interaction) and the timer restarts. Any manual shift
## refills it, so flow-state players never get randomized.
func _process_chaos(delta: float) -> void:
	_chaos -= delta
	if _chaos <= 0.0:
		_force_random_shift()
	if is_instance_valid(_chaos_ring):
		_chaos_ring.queue_redraw()


func _force_random_shift() -> void:
	# Only randomize among shapes the player actually has unlocked. With one shape
	# available there's nothing to force, so just refill and move on.
	var others: Array = []
	for s in [Shape.CUBE, Shape.CIRCLE, Shape.TRIANGLE]:
		if s != current_shape and _unlocked.get(s, false):
			others.append(s)
	if others.is_empty():
		_chaos = CHAOS_TIME
		return
	_shift_to(others[_rng.randi_range(0, others.size() - 1)])  # refills _chaos
	if not debug_drive:
		GameManager.notify_randomized()


## Feed the glowing trail. Builds up while moving fast, fades by dropping old
## points. Length scales loosely with speed for a "go faster, glow more" feel.
func _update_trail() -> void:
	if not is_instance_valid(_trail):
		return
	var speed := linear_velocity.length()
	if speed > 90.0:
		_trail.add_point(global_position)
	var max_points := 14
	while _trail.get_point_count() > max_points:
		_trail.remove_point(0)
	# Even when stopped, bleed the tail off so it doesn't hang frozen.
	if speed <= 90.0 and _trail.get_point_count() > 0:
		_trail.remove_point(0)


## Horizontal movement. Force-based, but the per-shape move_force is tuned to
## clear that shape's friction so even the Cube actually accelerates.
func move(dir: float) -> void:
	var data: Dictionary = SHAPE_DATA[current_shape]

	if dir != 0.0 and absf(linear_velocity.x) < data.max_speed:
		apply_central_force(Vector2(dir * data.move_force, 0.0))

	# Triangle aerial glide.
	if current_shape == Shape.TRIANGLE:
		if not is_grounded() and dir != 0.0:
			gravity_scale = TRIANGLE_GLIDE_GRAVITY
			apply_central_force(Vector2(dir * TRIANGLE_GLIDE_FORCE, 0.0))
		else:
			gravity_scale = data.gravity_scale


## Register a jump intent; it's held in a buffer and fires as soon as the player
## is grounded (within coyote grace). Call from input.
func request_jump() -> void:
	_jump_req = JUMP_BUFFER


## Resolve buffered jump each physics frame. Sets takeoff velocity directly —
## reliable for every mass, no double-tap.
func _process_jump(delta: float) -> void:
	if is_grounded():
		_since_grounded = 0.0
	else:
		_since_grounded += delta

	if _jump_req > 0.0:
		_jump_req -= delta
		if _since_grounded <= COYOTE_TIME:
			linear_velocity.y = -SHAPE_DATA[current_shape].jump_velocity
			_jump_req = 0.0
			_since_grounded = 999.0  # consume coyote so we can't double-jump


func is_grounded() -> bool:
	return _ground_check.is_colliding()


## The shift. Velocity is NOT touched, so the player keeps their speed across the
## swap (build momentum as Circle, carry it into Cube/Triangle). Every shift —
## manual or forced — refills the Chaos timer and fires the juice burst.
func _shift_to(new_shape: Shape) -> void:
	if new_shape == current_shape:
		return
	# Locked shapes are off-limits until a ShapeUnlock grants them.
	if not _unlocked.get(new_shape, true):
		shape_locked.emit(new_shape)
		return
	current_shape = new_shape
	_apply_shape(new_shape)
	_chaos = CHAOS_TIME
	_emit_shift_burst(SHAPE_COLOR[new_shape])


## True if this shape is currently available (used by HUD / power-ups).
func is_unlocked(shape: int) -> bool:
	return _unlocked.get(shape, false)


## Grant a previously-locked shape (ShapeUnlock power-up). Refills the timer and
## pops a burst in that shape's color as feedback.
func unlock_shape(shape: int) -> void:
	if _unlocked.get(shape, false):
		return
	_unlocked[shape] = true
	_chaos = CHAOS_TIME
	_emit_shift_burst(SHAPE_COLOR[shape])
	shape_unlocked.emit(shape)


## Add time to the Chaos timer (TimeBonus power-up), capped so it can't bank forever.
func extend_chaos(seconds: float) -> void:
	_chaos = minf(_chaos + seconds, CHAOS_MAX)


## Vector particle pop in the new shape's color, plus recolor the trail to match.
func _emit_shift_burst(col: Color) -> void:
	if is_instance_valid(_shift_burst):
		_shift_burst.color = col
		_shift_burst.global_position = global_position
		_shift_burst.restart()
		_shift_burst.emitting = true
	if is_instance_valid(_trail) and _trail.gradient:
		var g := _trail.gradient as Gradient
		g.set_color(0, Color(col.r, col.g, col.b, 0.0))
		g.set_color(1, Color(col.r, col.g, col.b, 0.6))


func _apply_shape(shape: Shape) -> void:
	var data: Dictionary = SHAPE_DATA[shape]

	mass = data.mass
	gravity_scale = data.gravity_scale
	linear_damp = data.linear_damp
	angular_damp = data.angular_damp
	lock_rotation = data.lock_rotation
	physics_material_override = MATERIALS[shape]

	# Cube and Triangle must sit flat on their base. The Circle rolls freely, so
	# when we shift FROM a rolled circle INTO a locked shape the body would
	# otherwise keep (and freeze at) the circle's tilt. Snap upright on the way in.
	if data.lock_rotation:
		rotation = 0.0
		angular_velocity = 0.0

	# Collision shapes are toggled deferred — never mutate physics state inside a
	# physics callback. All three live on the body permanently.
	for s in _cols:
		_cols[s].set_deferred("disabled", s != shape)

	# Visuals swap immediately.
	for s in _vis:
		_vis[s].visible = (s == shape)


## --- Headless verification only (debug_drive) ---------------------------------
func _debug_step(delta: float) -> void:
	_dbg_frame += 1
	var cycle := 90
	var order := [Shape.CUBE, Shape.TRIANGLE, Shape.CIRCLE]
	var want: int = order[int(_dbg_frame / cycle) % 3]

	var local := _dbg_frame % cycle
	if local == 0:
		# Pre-tilt the body to simulate a rolled Circle BEFORE shifting, so the
		# next cycle's shift into a locked shape must snap it upright to pass.
		rotation = 1.0
		angular_velocity = 6.0
	if local == 1:
		# Reset onto the floor and switch shape at the start of each cycle.
		_shift_to(want)
		position = Vector2(-200, 360)
		linear_velocity = Vector2.ZERO
		_jump_req = 0.0
		_since_grounded = 999.0
		print("[probe] shape=%s start  rot_after_shift=%.3f" % [
			Shape.keys()[current_shape], rotation])
	move(1.0)
	if local == 45:  # well after settling, so the Circle has stopped bouncing
		request_jump()
	_process_jump(delta)
	if local == 30 or local == 50 or local == 80:
		print("[probe] shape=%s f=%d  vx=%.1f  vy=%.1f  x=%.1f  y=%.1f  rot=%.3f  grounded=%s" % [
			Shape.keys()[current_shape], local,
			linear_velocity.x, linear_velocity.y, position.x, position.y,
			rotation, is_grounded()])
