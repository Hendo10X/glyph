extends Area2D
## A weight-gated switch. Only a body at least `min_mass` heavy engages it — the
## Cube (mass 5) does; the Circle (1) and Triangle (2) are far too light. While
## engaged it opens the linked Door. With `latch` on (default) it stays open once
## triggered, so the player can press it as Cube then shift and slip through.

@export var min_mass := 3.5
@export var door_path: NodePath
@export var latch := true

@onready var _plate: Node2D = $Vis
var _door: Node = null
var _engaged := false
var _rest_y := 0.0


func _ready() -> void:
	if not door_path.is_empty():
		_door = get_node_or_null(door_path)
	_rest_y = _plate.position.y


func _physics_process(_delta: float) -> void:
	var pressed := false
	for b in get_overlapping_bodies():
		if b.is_in_group("player") and b.mass >= min_mass:
			pressed = true
			break

	if pressed and not _engaged:
		_engaged = true
		_set_door(true)
		_press(true)
	elif not pressed and _engaged and not latch:
		_engaged = false
		_set_door(false)
		_press(false)


func _set_door(o: bool) -> void:
	if _door and _door.has_method("set_open"):
		_door.set_open(o)


func _press(down: bool) -> void:
	var ty := _rest_y + (6.0 if down else 0.0)
	create_tween().tween_property(_plate, "position:y", ty, 0.1)
	modulate = Color(0.6, 1.0, 0.7) if down else Color.WHITE
