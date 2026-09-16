extends StaticBody2D
## A gate that retracts (slides away + drops collision) when its linked
## PressurePlate is engaged. Controlled via set_open().

@export var open_offset := Vector2(0, -184)
@export var slide_time := 0.35

@onready var _col: CollisionShape2D = $Col
var _closed_pos := Vector2.ZERO
var _is_open := false


func _ready() -> void:
	_closed_pos = position


func set_open(o: bool) -> void:
	if o == _is_open:
		return
	_is_open = o
	# Drop collision immediately (deferred) so the player can pass even mid-slide.
	_col.set_deferred("disabled", o)
	var target := _closed_pos + (open_offset if o else Vector2.ZERO)
	create_tween().tween_property(self, "position", target, slide_time)
