extends AnimatableBody2D
## A platform that ping-pongs along `travel` with smooth ease-in/out. Being an
## AnimatableBody2D with sync_to_physics, it carries riders through contact — so
## the high-friction Cube rides cleanly while the slippery Circle slides off
## (a deliberate "pick the right shape" wrinkle).

## Relative offset from the start position to the far end of the path (pixels).
@export var travel := Vector2(200, 0)
## Seconds for one full there-and-back cycle.
@export var period := 3.0
## Start partway through the cycle so paired platforms can be desynced.
@export var phase_offset := 0.0

var _start := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	_start = position
	_t = phase_offset * period


func _physics_process(delta: float) -> void:
	_t += delta
	# Triangle wave → CONSTANT speed out and back. Constant velocity (no eased
	# acceleration) is what lets surface friction actually carry a RigidBody rider;
	# easing spikes the acceleration past friction and the rider slides off.
	var saw := fmod(_t / period, 1.0)
	var phase := 1.0 - absf(2.0 * saw - 1.0)
	position = _start + travel * phase
